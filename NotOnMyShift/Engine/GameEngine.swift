import Foundation

/// Oyunun ekonomisi. Tamamen saf: `Date()`, `Timer`, `UserDefaults`, dosya —
/// hiçbiri yok. Her fonksiyon girdi alır, yeni bir `GameState` döndürür.
///
/// Bu kural sayesinde tüm ekonomi UI olmadan test edilebilir. Saate ihtiyaç
/// duyan tek fonksiyon `resume(_:at:mode:config:)` ve o da saati parametre
/// olarak alır — içeride okumaz.
///
/// Faz 3'ten beri ekonomi kat kattır: her kat bir sektör, her katın kendi
/// kadrosu, ekipmanı ve şubeleri var. Kasa ortaktır.
enum GameEngine {

    // MARK: - Hatalar

    enum ActionError: Error, Sendable, Equatable {
        /// Para yetmiyor.
        case insufficientFunds
        /// Bu kata daha fazla eleman sığmıyor.
        case staffLimitReached
        /// Depo ya da ekipman son seviyede.
        case maxLevelReached
        /// Dengede böyle bir ekipman yok.
        case unknownEquipment
        /// Kata sığacak hücre kalmadı.
        case branchLimitReached
        /// Böyle bir kat yok.
        case unknownFloor
        /// Dengede bu katın sektörü tanımlı değil.
        case unknownSector
        /// Bütün katlar açıldı.
        case allFloorsOpen
        /// Dengede böyle bir olay ya da seçenek yok.
        case unknownEvent
        /// Pazar payı yeni bir hücreye yetmiyor. Rakipler payı kaptı.
        case marketShareTooLow
        /// Çatı katı zaten açık.
        case roofAlreadyOpen
        /// Süreç katmanı için önce çatı katı gerekiyor.
        case roofRequired
        /// Bu katta zaten müdür var.
        case managerAlreadyHired
        /// Dengede böyle bir kural yok.
        case unknownRule
        /// Kat henüz olgunlaşmadı: kadro, ekipman ya da hücreler eksik.
        case sectorNotMature
        /// Bu kat zaten satıldı; yatırım katı yeniden işletilemez.
        case sectorAlreadySold
        /// Halka arz için bina henüz hazır değil.
        case notReadyToGoPublic
    }

    // MARK: - Deterministik rastgelelik

    /// SplitMix64. Motor saf kalsın diye rastgelelik sistem RNG'sinden değil,
    /// kayıtta duran tohumdan türetilir — aynı kayıt aynı olayları verir.
    struct DeterministicRandom {
        var seed: UInt64

        mutating func next() -> UInt64 {
            seed &+= 0x9E37_79B9_7F4A_7C15
            var z = seed
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        /// 0..<1
        mutating func unit() -> Double {
            Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
        }
    }

    // MARK: - Kat başına türetilenler

    /// Katın sektör tanımı. Dengeden kalkmış bir sektör kalmışsa `nil`.
    static func spec(for floor: FloorState, config: BalanceConfig) -> BalanceConfig.SectorSpec? {
        config.sector(id: floor.sectorID)
    }

    /// Katın ekipman çarpanı. Her parçanın seviye çarpanı çarpılır.
    static func equipmentMultiplier(
        for floor: FloorState,
        spec: BalanceConfig.SectorSpec
    ) -> Double {
        spec.equipment.reduce(1.0) { product, item in
            let level = min(floor.equipmentLevel(item.id), item.levels.count - 1)
            guard item.levels.indices.contains(level) else { return product }
            return product * max(0, item.levels[level].multiplier)
        }
    }

    /// Katın açık şube sayısı — kayıttaki değer dengedeki sınıra kırpılır.
    static func branchCount(for floor: FloorState, spec: BalanceConfig.SectorSpec) -> Int {
        min(max(1, floor.branchCount), max(1, spec.branches.maxCount))
    }

    /// Maaş kesilmeden önceki saniyelik üretim. Kadro boşsa 0 — yani Çağ 0'da
    /// çevrimdışı kazanç da kendiliğinden yoktur, ayrı bir bayrağa gerek kalmaz.
    ///
    /// Her şube aynı kadro ve ekipmanla çalışır (tek tuş kopyalama), dolayısıyla
    /// üretim şube sayısıyla doğrusal çarpılır.
    static func floorGross(
        _ floor: FloorState,
        spec: BalanceConfig.SectorSpec,
        bonus: Double = 1
    ) -> Double {
        // Yatırım katı kira öder: kadrosu ve ekipmanı yok, oranı satışta dondu.
        guard !floor.isInvestment else { return max(0, floor.investmentRate) * max(0, bonus) }

        let multiplierSum = floor.staff.reduce(0.0) { $0 + $1.rateMultiplier }
        return spec.staff.ratePerSecond
            * multiplierSum
            * equipmentMultiplier(for: floor, spec: spec)
            * Double(branchCount(for: floor, spec: spec))
            * max(0, bonus)
    }

    /// Katın süreç verimi. Kural yoksa 1 — **süreç kurmayan oyuncu hiçbir şey
    /// kaybetmez.** Kural kuran üstüne bonus alır (rapor §4).
    static func processBonus(for floor: FloorState, state: GameState, config: BalanceConfig) -> Double {
        let active = state.rules(for: floor.sectorID)
            .filter { id in config.process.rules.contains { $0.id == id } }
        guard !active.isEmpty else { return 1 }
        let bonus = min(
            max(0, config.process.maxBonus),
            Double(active.count) * max(0, config.process.bonusPerRule)
        )
        return 1 + bonus
    }

    /// Katın saniyelik maaş gideri. Her şube kendi kadrosunu tutar.
    ///
    /// Ekipman maaş ödemez; tasarım raporundaki "eleman maaşı ile makine
    /// yatırımı arasında gerçek bir seçim" buradan doğuyor.
    static func floorWages(_ floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double {
        guard !floor.isInvestment else { return 0 }
        return max(0, spec.staff.wagePerSecond)
            * Double(floor.staff.count)
            * Double(branchCount(for: floor, spec: spec))
    }

    /// Katın kasaya kattığı net. Maaş brütü geçerse kat sıfır üretir ama borç
    /// birikmez ve diğer katları da aşağı çekmez.
    static func floorNet(
        _ floor: FloorState,
        spec: BalanceConfig.SectorSpec,
        bonus: Double = 1
    ) -> Double {
        max(0, floorGross(floor, spec: spec, bonus: bonus) - floorWages(floor, spec: spec))
    }

    // MARK: - Bina geneli

    private static func sum(
        _ state: GameState,
        _ config: BalanceConfig,
        _ value: (FloorState, BalanceConfig.SectorSpec) -> Double
    ) -> Double {
        state.floors.reduce(0.0) { total, floor in
            guard let spec = spec(for: floor, config: config) else { return total }
            return total + value(floor, spec)
        }
    }

    /// Satılan sektörlerden kalan kalıcı çarpan (rapor §5).
    ///
    /// Olay çarpanı gibi **brüte** uygulanır, maaşa değil. Puan asla azalmaz;
    /// halka arzda bile taşınır — oyuncu geriye gitmez.
    static func holdingMultiplier(for state: GameState, config: BalanceConfig) -> Double {
        1 + Double(max(0, state.holdingPoints)) * max(0, config.prestige.multiplierPerPoint)
    }

    static func grossRate(for state: GameState, config: BalanceConfig) -> Double {
        let holding = holdingMultiplier(for: state, config: config)
        return sum(state, config) { floor, spec in
            floorGross(floor, spec: spec, bonus: processBonus(for: floor, state: state, config: config)) * holding
        }
    }

    static func wageRate(for state: GameState, config: BalanceConfig) -> Double {
        sum(state, config) { floorWages($0, spec: $1) }
    }

    /// Süren olay etkilerinin çarpımı. Etki yoksa 1.
    static func eventMultiplier(for state: GameState) -> Double {
        state.modifiers.reduce(1.0) { $0 * max(0, $1.multiplier) }
    }

    /// Kasaya giren saniyelik net — katların netlerinin toplamı.
    /// Zarardaki bir kat kârdaki katı aşağı çekmez.
    ///
    /// Olay çarpanı brüte uygulanır, maaşa değil: yavaşlatan bir olayda maaş
    /// yine ödenir, hızlandıran bir olayda maaş artmaz.
    static func productionRate(for state: GameState, config: BalanceConfig) -> Double {
        let buff = eventMultiplier(for: state) * holdingMultiplier(for: state, config: config)
        return sum(state, config) { floor, spec in
            let bonus = processBonus(for: floor, state: state, config: config)
            return max(0, floorGross(floor, spec: spec, bonus: bonus) * buff - floorWages(floor, spec: spec))
        }
    }

    // MARK: - Pazar

    /// Oyuncunun pazar payı. Kayıt kurulmamışsa dengedeki başlangıç payı.
    static func marketShare(for state: GameState, config: BalanceConfig) -> Double {
        clampShare(state.marketShare < 0 ? config.market.startShare : state.marketShare, config: config)
    }

    private static func clampShare(_ value: Double, config: BalanceConfig) -> Double {
        min(max(value, max(0, config.market.minimumShare)), 1)
    }

    struct CompetitorShare: Sendable, Equatable, Identifiable {
        let id: String
        var share: Double
    }

    /// Kalan payın rakipler arasındaki dağılımı.
    static func competitorShares(for state: GameState, config: BalanceConfig) -> [CompetitorShare] {
        let remaining = max(0, 1 - marketShare(for: state, config: config))
        let total = config.market.competitors.reduce(0.0) { $0 + max(0, $1.weight) }
        guard total > 0 else { return [] }
        return config.market.competitors.map {
            CompetitorShare(id: $0.id, share: remaining * max(0, $0.weight) / total)
        }
    }

    /// Pazar payının açtığı hücre sayısı.
    ///
    /// Tasarım raporunun cezalandırmama kuralı: rakip **mevcut geliri asla
    /// düşürmez**. Açılmış şube kapanmaz; pay düşünce yalnızca *yeni* hücre
    /// açma hakkı daralır. Kayıp gecikme olarak hissedilir, geri gitme olarak değil.
    static func branchSlots(for spec: BalanceConfig.SectorSpec, state: GameState, config: BalanceConfig) -> Int {
        let maxCount = max(1, spec.branches.maxCount)
        guard maxCount > 1 else { return 1 }
        let floorShare = max(0, config.market.minimumShare)
        let span = max(0.0001, 1 - floorShare)
        let progress = min(max((marketShare(for: state, config: config) - floorShare) / span, 0), 1)
        // En yakına yuvarlıyoruz: son hücre için tam pay şart olmasın.
        return min(maxCount, 1 + Int((progress * Double(maxCount - 1)).rounded()))
    }

    /// Yatırım payı geri kazandırır. Her satın alımda uygulanır.
    private static func rewardingShare(_ state: GameState, config: BalanceConfig) -> GameState {
        var next = state
        next.marketShare = clampShare(
            marketShare(for: state, config: config) + max(0, config.market.sharePerPurchase),
            config: config
        )
        return next
    }

    /// Kod çözücünün dengeye erişimi yok; `unset` alanları burada dolduruyoruz.
    static func normalised(_ state: GameState, config: BalanceConfig) -> GameState {
        var next = state
        if next.marketShare < 0 {
            next.marketShare = clampShare(config.market.startShare, config: config)
        }
        if next.nextEventAtGameSeconds < 0 {
            next.nextEventAtGameSeconds = next.elapsedGameSeconds + max(0, config.events.firstAfterSeconds)
        }
        return next
    }

    /// Deponun tuttuğu çevrimdışı süre. Bunun ötesindeki süre yanar.
    /// Depo oyuncunun kendi kapasitesidir, katlara bölünmez.
    static func offlineCapacitySeconds(for state: GameState, config: BalanceConfig) -> TimeInterval {
        let levels = config.warehouse.levels
        guard !levels.isEmpty else { return 0 }
        let index = min(max(state.warehouseLevel, 0), levels.count - 1)
        return max(0, levels[index].capacitySeconds)
    }

    // MARK: - Ücretler

    /// Bir sonraki elemanın ücreti. Kadro doluysa `nil`.
    /// `cost(n) = baseCost * costGrowth^n`
    static func hireCost(for floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double? {
        guard floor.staff.count < staffCapacity(spec: spec) else { return nil }
        return spec.staff.baseCost * pow(spec.staff.costGrowth, Double(floor.staff.count))
    }

    /// Kadro üst sınırı: dengedeki sınır ile havuzdaki şablon sayısının küçüğü.
    /// Havuz tükenirse isimsiz eleman üretmek yerine duruyoruz.
    static func staffCapacity(spec: BalanceConfig.SectorSpec) -> Int {
        min(max(0, spec.staff.maxCount), spec.staffPool.count)
    }

    /// Bir ekipmanın sonraki seviyesinin ücreti. Son seviyedeyse ya da kimlik
    /// tanınmıyorsa `nil`.
    static func equipmentUpgradeCost(
        _ id: String,
        for floor: FloorState,
        spec: BalanceConfig.SectorSpec
    ) -> Double? {
        guard let item = spec.equipment.first(where: { $0.id == id }) else { return nil }
        let next = floor.equipmentLevel(id) + 1
        guard item.levels.indices.contains(next) else { return nil }
        return max(0, item.levels[next].cost)
    }

    /// Bir sonraki şubenin ham ücreti. Kat doluysa `nil`.
    /// `cost(n) = baseCost * costGrowth^(n-1)` — n açılacak şubenin sırası.
    static func branchCost(for floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double? {
        let current = branchCount(for: floor, spec: spec)
        guard current < max(1, spec.branches.maxCount) else { return nil }
        return max(0, spec.branches.baseCost * pow(max(1, spec.branches.costGrowth), Double(current - 1)))
    }

    /// Şube açılabilir mi, açılabilirse kaça? Pazar payı yetmiyorsa `nil` döner
    /// ve `isBranchBlockedByMarket` bunun sebebini söyler.
    static func availableBranchCost(
        onFloor index: Int,
        _ state: GameState,
        config: BalanceConfig
    ) -> Double? {
        guard state.floors.indices.contains(index),
              let spec = spec(for: state.floors[index], config: config),
              let cost = branchCost(for: state.floors[index], spec: spec) else { return nil }
        guard branchCount(for: state.floors[index], spec: spec)
            < branchSlots(for: spec, state: state, config: config) else { return nil }
        return cost
    }

    /// Kat dolmadığı hâlde şube açılamıyorsa sebep rakiplerdir.
    static func isBranchBlockedByMarket(
        onFloor index: Int,
        _ state: GameState,
        config: BalanceConfig
    ) -> Bool {
        guard state.floors.indices.contains(index),
              let spec = spec(for: state.floors[index], config: config),
              branchCost(for: state.floors[index], spec: spec) != nil else { return false }
        return branchCount(for: state.floors[index], spec: spec)
            >= branchSlots(for: spec, state: state, config: config)
    }

    /// Bir sonraki depo seviyesinin ücreti. Son seviyedeyse `nil`.
    static func warehouseUpgradeCost(for state: GameState, config: BalanceConfig) -> Double? {
        let next = state.warehouseLevel + 1
        guard config.warehouse.levels.indices.contains(next) else { return nil }
        return max(0, config.warehouse.levels[next].cost)
    }

    /// Açılacak bir üst katın ücreti. Bütün sektörler açıldıysa `nil`.
    static func nextFloorCost(for state: GameState, config: BalanceConfig) -> Double? {
        guard let next = config.sector(at: state.floors.count) else { return nil }
        return max(0, next.unlockCost)
    }

    /// Açılacak bir üst katın sektörü. Bütün sektörler açıldıysa `nil`.
    static func nextSector(for state: GameState, config: BalanceConfig) -> BalanceConfig.SectorSpec? {
        config.sector(at: state.floors.count)
    }

    /// Elle bir satışın getirisi. Ekipman Çağ 0'da da işe yarar.
    static func manualRevenue(for floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double {
        max(0, spec.manual.revenuePerSale) * equipmentMultiplier(for: floor, spec: spec)
    }

    /// Elle satışın olay çarpanı dahil getirisi — ekranda gösterilen değer.
    static func manualRevenue(
        onFloor index: Int,
        _ state: GameState,
        config: BalanceConfig
    ) -> Double {
        guard state.floors.indices.contains(index),
              !state.floors[index].isInvestment,
              let spec = spec(for: state.floors[index], config: config) else { return 0 }
        return manualRevenue(for: state.floors[index], spec: spec)
            * eventMultiplier(for: state)
            * holdingMultiplier(for: state, config: config)
    }

    // MARK: - Zamanı ilerlet

    /// Ekonomiyi `seconds` kadar ilerletir.
    ///
    /// **Segment segment kapalı form** — tick döngüsü değil. Süren olay
    /// etkilerinin bitiş anları oranı kırar; her kırılım noktası arasında oran
    /// sabit olduğu için tek çarpma yeter. Etki yoksa tek segment kalır, yani
    /// 8 saatlik fark da 1 saniyelik fark da tek çarpma.
    ///
    /// Döngü sınırlıdır: her adımda en az bir etki sona erer, dolayısıyla
    /// adım sayısı etki sayısı + 1'i geçmez.
    ///
    /// Saat okumaz, tavan uygulamaz. Tavan `resume(_:at:mode:config:)` işidir.
    static func advance(_ state: GameState, by seconds: TimeInterval, config: BalanceConfig) -> GameState {
        let start = normalised(state, config: config)
        guard seconds.isFinite, seconds > 0 else { return start }

        var current = start
        var remaining = seconds
        var steps = current.modifiers.count + 1

        while remaining > 0, steps > 0 {
            steps -= 1
            let step = min(remaining, nextBreakpoint(in: current) ?? remaining)
            guard step > 0 else { break }
            current = advanceSegment(current, by: step, config: config)
            remaining -= step
        }
        if remaining > 0 {
            current = advanceSegment(current, by: remaining, config: config)
        }
        return current
    }

    /// Bir sonraki oran kırılımına kalan süre. Süren etki yoksa `nil`.
    private static func nextBreakpoint(in state: GameState) -> TimeInterval? {
        state.modifiers
            .map { $0.endsAtGameSeconds - state.elapsedGameSeconds }
            .filter { $0 > 0 }
            .min()
    }

    /// Oranın sabit olduğu tek segment: bir çarpma.
    private static func advanceSegment(
        _ state: GameState,
        by seconds: TimeInterval,
        config: BalanceConfig
    ) -> GameState {
        let earned = productionRate(for: state, config: config) * seconds
        let share = marketShare(for: state, config: config)

        var next = state
        next.elapsedGameSeconds += seconds
        if earned > 0 {
            next.money += earned
            next.lifetimeEarnings += earned
        }
        // Pazar payı zamanla rakiplere kayar. Gelir düşmez, sadece yeni hücre
        // açma hakkı daralır.
        next.marketShare = clampShare(share - max(0, config.market.driftPerSecond) * seconds, config: config)
        // Süresi dolan etkiler burada düşer; döngünün ilerlemesini bu sağlar.
        next.modifiers.removeAll { $0.endsAtGameSeconds <= next.elapsedGameSeconds }
        return next
    }

    // MARK: - Saatle buluşma

    enum ResumeMode: Sendable, Equatable {
        /// Uygulama açıkken atılan küçük adım. Tavan uygulanmaz.
        case live
        /// Uygulama kapalıyken geçen süre. Depo tavanı uygulanır.
        case awayFromApp
    }

    struct ResumeOutcome: Sendable, Equatable {
        var state: GameState
        /// Saatten okunan ham fark (negatifse 0'a çekilmiş hâli).
        var elapsedSeconds: TimeInterval
        /// Tavandan sonra gerçekten krediye yazılan süre.
        var creditedSeconds: TimeInterval
        /// Tavanı aşıp yanan süre.
        var wastedSeconds: TimeInterval
        /// Bu adımda kazanılan para.
        var earned: Double
        /// Depo tavana dayandı mı? ("Depo doldu, ürünler bekliyor")
        var didFillWarehouse: Bool
        /// Saat geriye alınmış mı? (kasti ya da kazara)
        var clockWentBackwards: Bool
        /// Oyuncuya dönüş özeti gösterilmeli mi?
        var shouldShowReport: Bool
    }

    /// `state.lastSeenAt` ile `now` arasındaki farkı ekonomiye işler.
    ///
    /// - Saat geriye alınmışsa fark 0 sayılır ama `lastSeenAt` yine de güncellenir;
    ///   böylece geri alınan saat ileri kaydırılarak çifte kazanç elde edilemez.
    /// - `awayFromApp` modunda fark depo kapasitesiyle sınırlanır.
    /// - Kesilen süre de tüketilmiş sayılır: `lastSeenAt` her hâlükârda `now` olur.
    static func resume(
        _ state: GameState,
        at now: Date,
        mode: ResumeMode,
        config: BalanceConfig
    ) -> ResumeOutcome {
        let raw = now.timeIntervalSince(state.lastSeenAt)
        let clockWentBackwards = raw < 0
        let elapsed = (raw.isFinite && raw > 0) ? raw : 0

        let capacity = offlineCapacitySeconds(for: state, config: config)
        let credited: TimeInterval
        switch mode {
        case .live:
            credited = elapsed
        case .awayFromApp:
            credited = min(elapsed, capacity)
        }
        let wasted = max(0, elapsed - credited)

        var next = advance(state, by: credited, config: config)
        next.lastSeenAt = now

        let earned = next.money - state.money
        let isReportable = mode == .awayFromApp
            && elapsed >= config.offline.minimumReportSeconds
            && earned > 0

        if mode == .awayFromApp {
            next.stats.wastedOfflineSeconds += wasted
            if isReportable {
                next.stats.offlineReturns += 1
                next.stats.lastOfflineEarnings = earned
            }
        }

        return ResumeOutcome(
            state: next,
            elapsedSeconds: elapsed,
            creditedSeconds: credited,
            wastedSeconds: wasted,
            earned: earned,
            didFillWarehouse: mode == .awayFromApp && wasted > 0,
            clockWentBackwards: clockWentBackwards,
            shouldShowReport: isReportable
        )
    }

    // MARK: - Kat eylemleri

    /// Bir kat üstünde çalışan eylemlerin ortak kabuğu: katı ve sektörünü bulur,
    /// eylemi çalıştırır, değişen katı ve ödenen ücreti tek yerde duruma yazar.
    private struct Purchase {
        var floor: FloorState
        var cost: Double
    }

    private static func onFloor(
        _ index: Int,
        _ state: GameState,
        _ config: BalanceConfig,
        _ change: (FloorState, BalanceConfig.SectorSpec) -> Result<Purchase, ActionError>
    ) -> Result<GameState, ActionError> {
        guard state.floors.indices.contains(index) else { return .failure(.unknownFloor) }
        let floor = state.floors[index]
        guard let spec = spec(for: floor, config: config) else { return .failure(.unknownSector) }
        // Yatırım katı artık senin işletmen değil: kadro, ekipman, hücre alınmaz.
        guard !floor.isInvestment else { return .failure(.sectorAlreadySold) }

        switch change(floor, spec) {
        case .success(let purchase):
            var next = normalised(state, config: config)
            next.floors[index] = purchase.floor
            next.money -= purchase.cost
            // Yatırım pazar payı kazandırır: rakiplere kayan pay geri gelir.
            return .success(rewardingShare(next, config: config))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Çağ 0: elle bir ürün sat.
    static func sellManually(onFloor index: Int, _ state: GameState, config: BalanceConfig) -> GameState {
        guard state.floors.indices.contains(index),
              !state.floors[index].isInvestment,
              let spec = spec(for: state.floors[index], config: config) else { return state }

        let revenue = manualRevenue(for: state.floors[index], spec: spec)
            * eventMultiplier(for: state)
            * holdingMultiplier(for: state, config: config)
        var next = state
        next.money += revenue
        next.lifetimeEarnings += revenue
        next.stats.manualSales += 1
        return next
    }

    /// Çağ 1: sıradaki elemanı işe al. Havuz sırası deterministiktir.
    static func hireStaff(
        onFloor index: Int,
        _ state: GameState,
        config: BalanceConfig
    ) -> Result<GameState, ActionError> {
        onFloor(index, state, config) { floor, spec in
            guard let cost = hireCost(for: floor, spec: spec) else { return .failure(.staffLimitReached) }
            guard state.money >= cost else { return .failure(.insufficientFunds) }

            let template = spec.staffPool[floor.staff.count]
            var updated = floor
            updated.staff.append(
                StaffMember(
                    id: template.id,
                    rateMultiplier: template.rateMultiplier,
                    hiredAtGameSeconds: state.elapsedGameSeconds
                )
            )
            return .success(Purchase(floor: updated, cost: cost))
        }
    }

    /// Çağ 2: bir ekipmanı bir seviye yükselt.
    static func upgradeEquipment(
        _ id: String,
        onFloor index: Int,
        _ state: GameState,
        config: BalanceConfig
    ) -> Result<GameState, ActionError> {
        onFloor(index, state, config) { floor, spec in
            guard spec.equipment.contains(where: { $0.id == id }) else { return .failure(.unknownEquipment) }
            guard let cost = equipmentUpgradeCost(id, for: floor, spec: spec) else { return .failure(.maxLevelReached) }
            guard state.money >= cost else { return .failure(.insufficientFunds) }

            var updated = floor
            updated.equipmentLevels[id] = floor.equipmentLevel(id) + 1
            return .success(Purchase(floor: updated, cost: cost))
        }
    }

    /// Yeni bir şube aç. Şube mevcut kadro ve ekipmanı devralır; ayrı ayarı yok.
    static func openBranch(
        onFloor index: Int,
        _ state: GameState,
        config: BalanceConfig
    ) -> Result<GameState, ActionError> {
        onFloor(index, state, config) { floor, spec in
            guard let cost = branchCost(for: floor, spec: spec) else { return .failure(.branchLimitReached) }
            guard branchCount(for: floor, spec: spec) < branchSlots(for: spec, state: state, config: config) else {
                return .failure(.marketShareTooLow)
            }
            guard state.money >= cost else { return .failure(.insufficientFunds) }

            var updated = floor
            updated.branchCount = branchCount(for: floor, spec: spec) + 1
            return .success(Purchase(floor: updated, cost: cost))
        }
    }

    // MARK: - Bina eylemleri

    /// Depoyu bir seviye büyüt — yani çevrimdışı kazanç tavanını yükselt.
    static func upgradeWarehouse(_ state: GameState, config: BalanceConfig) -> Result<GameState, ActionError> {
        guard let cost = warehouseUpgradeCost(for: state, config: config) else {
            return .failure(.maxLevelReached)
        }
        guard state.money >= cost else { return .failure(.insufficientFunds) }
        var next = normalised(state, config: config)
        next.money -= cost
        next.warehouseLevel += 1
        return .success(rewardingShare(next, config: config))
    }

    /// Faz 3: bir üst katı aç. Kat açmak yeni bir sektöre girmektir.
    /// Yeni kat boş gelir — kendi kadrosunu ve ekipmanını sıfırdan kurarsın.
    static func unlockNextFloor(_ state: GameState, config: BalanceConfig) -> Result<GameState, ActionError> {
        guard let sector = nextSector(for: state, config: config) else {
            return .failure(.allFloorsOpen)
        }
        let cost = max(0, sector.unlockCost)
        guard state.money >= cost else { return .failure(.insufficientFunds) }

        var next = normalised(state, config: config)
        next.money -= cost
        next.floors.append(FloorState(sectorID: sector.id))
        // Yeni kat hemen seçilsin: oyuncu açtığı şeyin başında olsun.
        next.selectedFloor = next.floors.count - 1
        return .success(rewardingShare(next, config: config))
    }

    // MARK: - Olaylar

    /// Şu an karar bekleyen olay. Yoksa `nil`.
    ///
    /// Aynı durum için hep aynı olayı verir: seçim kayıttaki tohumdan
    /// türetilir, sistem rastgeleliğinden değil.
    static func pendingEvent(for state: GameState, config: BalanceConfig) -> BalanceConfig.EventSpec? {
        let ready = normalised(state, config: config)
        guard ready.elapsedGameSeconds >= ready.nextEventAtGameSeconds else { return nil }
        guard !config.events.specs.isEmpty else { return nil }

        var random = DeterministicRandom(seed: ready.eventSeed &+ 1)
        return weightedPick(config.events.specs, weight: { max(0, $0.weight) }, using: &random)
    }

    /// Bir olayın seçeneğini uygula.
    ///
    /// Anında etki **mevcut saniyelik netin katı** olarak hesaplanır; böylece
    /// aynı olay Çağ 0'da da, dört şubeli fırında da anlamlı kalır.
    /// Kasa asla eksiye düşmez — oyuncu geri gitmez.
    static func resolveEvent(
        _ eventID: String,
        choice choiceID: String,
        _ state: GameState,
        config: BalanceConfig
    ) -> Result<GameState, ActionError> {
        guard let spec = config.events.spec(id: eventID),
              let choice = spec.choices.first(where: { $0.id == choiceID }) else {
            return .failure(.unknownEvent)
        }

        var next = normalised(state, config: config)

        if choice.instantSeconds != 0 {
            let amount = productionRate(for: next, config: config) * choice.instantSeconds
            if amount >= 0 {
                next.money += amount
                next.lifetimeEarnings += amount
            } else {
                next.money = max(0, next.money + amount)
            }
        }

        if choice.durationSeconds > 0, choice.multiplier != 1 {
            next.modifiers.append(
                ActiveModifier(
                    eventID: spec.id,
                    choiceID: choice.id,
                    multiplier: max(0, choice.multiplier),
                    endsAtGameSeconds: next.elapsedGameSeconds + choice.durationSeconds
                )
            )
        }

        next.stats.eventsResolved += 1
        return .success(schedulingNextEvent(next, config: config))
    }

    /// Olayı karara bağlamadan kapat. Etki yok, sadece sıradakine geçilir.
    static func dismissEvent(_ state: GameState, config: BalanceConfig) -> GameState {
        schedulingNextEvent(normalised(state, config: config), config: config)
    }

    /// Sıradaki olayı planlar ve tohumu ilerletir.
    private static func schedulingNextEvent(_ state: GameState, config: BalanceConfig) -> GameState {
        var random = DeterministicRandom(seed: state.eventSeed)
        let spread = min(max(config.events.gapJitter, 0), 0.9)
        let jitter = 1 + (random.unit() * 2 - 1) * spread

        var next = state
        next.eventSeed = random.seed
        next.nextEventAtGameSeconds = state.elapsedGameSeconds
            + max(60, max(60, config.events.gapSeconds) * jitter)
        return next
    }

    /// Ağırlıklı seçim. Ağırlık toplamı sıfırsa ilk öge.
    private static func weightedPick<Item>(
        _ items: [Item],
        weight: (Item) -> Double,
        using random: inout DeterministicRandom
    ) -> Item? {
        guard let first = items.first else { return nil }
        let total = items.reduce(0.0) { $0 + weight($1) }
        guard total > 0 else { return first }

        var roll = random.unit() * total
        for item in items {
            roll -= weight(item)
            if roll <= 0 { return item }
        }
        return items.last
    }

    // MARK: - Süreç katmanı (Çağ 3)

    /// Çatı katını açmanın ücreti. Zaten açıksa `nil`.
    static func roofCost(for state: GameState, config: BalanceConfig) -> Double? {
        state.hasRoof ? nil : max(0, config.process.roofCost)
    }

    /// Bir sonraki müdürün ücreti. Çatı yoksa `nil`.
    static func managerCost(for state: GameState, config: BalanceConfig) -> Double? {
        guard state.hasRoof else { return nil }
        return max(0, config.process.managerBaseCost)
            * pow(max(1, config.process.managerCostGrowth), Double(state.managedSectors.count))
    }

    /// Çatı katını aç — yönetim ofisi. Kendi başına üretmez, süreç katmanını açar.
    static func unlockRoof(_ state: GameState, config: BalanceConfig) -> Result<GameState, ActionError> {
        guard let cost = roofCost(for: state, config: config) else { return .failure(.roofAlreadyOpen) }
        guard state.money >= cost else { return .failure(.insufficientFunds) }

        var next = normalised(state, config: config)
        next.money -= cost
        next.hasRoof = true
        return .success(rewardingShare(next, config: config))
    }

    /// Bir kata müdür ata. Müdürsüz katta kural çalışmaz.
    static func hireManager(
        forSector sectorID: String,
        _ state: GameState,
        config: BalanceConfig
    ) -> Result<GameState, ActionError> {
        guard state.hasRoof else { return .failure(.roofRequired) }
        guard state.floors.contains(where: { $0.sectorID == sectorID }) else { return .failure(.unknownFloor) }
        guard !state.hasManager(sectorID) else { return .failure(.managerAlreadyHired) }
        guard let cost = managerCost(for: state, config: config) else { return .failure(.roofRequired) }
        guard state.money >= cost else { return .failure(.insufficientFunds) }

        var next = normalised(state, config: config)
        next.money -= cost
        next.managedSectors.append(sectorID)
        return .success(rewardingShare(next, config: config))
    }

    /// Bir kuralı aç ya da kapat. Ücretsiz — kural yazmak yatırım değil, tercih.
    static func setRule(
        _ ruleID: String,
        enabled: Bool,
        forSector sectorID: String,
        _ state: GameState,
        config: BalanceConfig
    ) -> Result<GameState, ActionError> {
        guard config.process.rule(id: ruleID) != nil else { return .failure(.unknownRule) }
        guard state.hasManager(sectorID) else { return .failure(.roofRequired) }

        var next = state
        var rules = next.activeRules[sectorID] ?? []
        rules.removeAll { $0 == ruleID }
        if enabled { rules.append(ruleID) }
        next.activeRules[sectorID] = rules
        return .success(next)
    }

    /// Müdür olayları kendi karara bağlasın mı? Saf kolaylık, verim bonusu yok.
    static func setAutoResolvesEvents(_ enabled: Bool, _ state: GameState) -> GameState {
        var next = state
        next.autoResolvesEvents = enabled
        return next
    }

    // MARK: - Müdürün işlettiği kurallar

    /// Müdürün yaptığı tek bir iş — dönüş raporunda satır satır gösterilir.
    struct AutomatedAction: Sendable, Equatable {
        /// Hangi katta.
        var sectorID: String
        /// `hire` · `equip` · `branch` · `event`
        var rule: String
        /// Eleman kimliği, ekipman kimliği, şube sırası ya da olay seçimi.
        var detail: String
    }

    struct RuleOutcome: Sendable, Equatable {
        var state: GameState
        var actions: [AutomatedAction]
    }

    /// Müdürlerin kurallarını işlet.
    ///
    /// `advance` içinde değil, ondan sonra çalışır: satın alma oranı değiştirir
    /// ve bunu kapalı forma katmak `advance`'i döngüye çevirirdi. Müdür sen
    /// dönünce raporunu verir.
    ///
    /// Alımlar kasada bir yedek bırakır — müdür oyuncunun biriktirdiği parayı
    /// süpürmesin.
    static func applyRules(_ state: GameState, config: BalanceConfig) -> RuleOutcome {
        var current = normalised(state, config: config)
        guard current.hasRoof else { return RuleOutcome(state: current, actions: []) }

        var actions: [AutomatedAction] = []
        var budget = max(0, config.process.maxActionsPerVisit)

        while budget > 0, let step = nextAutomatedStep(current, config: config) {
            budget -= 1
            current = step.state
            actions.append(step.action)
        }

        current.stats.automatedActions += actions.count
        return RuleOutcome(state: current, actions: actions)
    }

    private struct AutomatedStep {
        var state: GameState
        var action: AutomatedAction
    }

    /// Sıradaki otomatik iş. Önce olay, sonra katlar sırayla.
    private static func nextAutomatedStep(
        _ state: GameState,
        config: BalanceConfig
    ) -> AutomatedStep? {
        if state.autoResolvesEvents,
           let event = pendingEvent(for: state, config: config),
           let choice = bestChoice(for: event, state, config: config),
           case .success(let resolved) = resolveEvent(event.id, choice: choice.id, state, config: config) {
            return AutomatedStep(
                state: resolved,
                action: AutomatedAction(sectorID: "", rule: "event", detail: "\(event.id).\(choice.id)")
            )
        }

        let reserve = productionRate(for: state, config: config) * max(0, config.process.reserveSeconds)

        for (index, floor) in state.floors.enumerated() {
            guard let spec = spec(for: floor, config: config), !floor.isInvestment else { continue }
            let rules = state.rules(for: floor.sectorID)

            for rule in config.process.rules where rules.contains(rule.id) {
                switch rule.id {
                case "hire":
                    if let cost = hireCost(for: floor, spec: spec),
                       state.money - cost >= reserve,
                       spec.staffPool.indices.contains(floor.staff.count),
                       case .success(let next) = hireStaff(onFloor: index, state, config: config) {
                        return AutomatedStep(
                            state: next,
                            action: AutomatedAction(
                                sectorID: floor.sectorID,
                                rule: rule.id,
                                detail: spec.staffPool[floor.staff.count].id
                            )
                        )
                    }
                case "equip":
                    let cheapest = spec.equipment
                        .compactMap { item -> (String, Double)? in
                            guard let cost = equipmentUpgradeCost(item.id, for: floor, spec: spec) else { return nil }
                            return (item.id, cost)
                        }
                        .min { $0.1 < $1.1 }
                    if let cheapest, state.money - cheapest.1 >= reserve,
                       case .success(let next) = upgradeEquipment(cheapest.0, onFloor: index, state, config: config) {
                        return AutomatedStep(
                            state: next,
                            action: AutomatedAction(sectorID: floor.sectorID, rule: rule.id, detail: cheapest.0)
                        )
                    }
                case "branch":
                    if let cost = availableBranchCost(onFloor: index, state, config: config),
                       state.money - cost >= reserve,
                       case .success(let next) = openBranch(onFloor: index, state, config: config) {
                        return AutomatedStep(
                            state: next,
                            action: AutomatedAction(
                                sectorID: floor.sectorID,
                                rule: rule.id,
                                detail: "\(branchCount(for: next.floors[index], spec: spec))"
                            )
                        )
                    }
                default:
                    continue
                }
            }
        }
        return nil
    }

    /// Bir olayın en kârlı seçeneği. Müdür bunu seçer.
    ///
    /// Süreli etkinin değeri, taban orana göre fazladan kazandırdığı para;
    /// anlık etkinin değeri doğrudan tutarı. İkisi de aynı birimde ölçülür.
    static func bestChoice(
        for spec: BalanceConfig.EventSpec,
        _ state: GameState,
        config: BalanceConfig
    ) -> BalanceConfig.EventChoice? {
        let rate = productionRate(for: state, config: config)
        return spec.choices.max { left, right in
            expectedValue(of: left, rate: rate) < expectedValue(of: right, rate: rate)
        }
    }

    private static func expectedValue(of choice: BalanceConfig.EventChoice, rate: Double) -> Double {
        var value = rate * choice.instantSeconds
        if choice.durationSeconds > 0 {
            value += rate * (choice.multiplier - 1) * choice.durationSeconds
        }
        return value
    }

    // MARK: - Yumuşak prestij (rapor §5)

    /// Katın olgunluğu 0..1. Kadro, ekipman ve hücreler eşit ağırlıklı.
    ///
    /// Şerit bunu bir ilerleme çubuğu olarak gösterir: satış bir sürpriz değil,
    /// baştan görünen bir hedef olsun.
    static func maturityProgress(_ floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double {
        guard !floor.isInvestment else { return 1 }

        let staffTarget = max(1, staffCapacity(spec: spec))
        let staffPart = min(1, Double(floor.staff.count) / Double(staffTarget))

        let equipmentTarget = spec.equipment.reduce(0) { $0 + max(0, $1.levels.count - 1) }
        let equipmentOwned = spec.equipment.reduce(0) { total, item in
            total + min(floor.equipmentLevel(item.id), max(0, item.levels.count - 1))
        }
        let equipmentPart = equipmentTarget > 0 ? Double(equipmentOwned) / Double(equipmentTarget) : 1

        let branchTarget = max(1, spec.branches.maxCount)
        let branchPart = min(1, Double(branchCount(for: floor, spec: spec)) / Double(branchTarget))

        return min(1, max(0, (staffPart + equipmentPart + branchPart) / 3))
    }

    /// Kat olgunlaştı mı? Rapor §5: "tüm şubeler + tüm yükseltmeler".
    static func isMature(_ floor: FloorState, spec: BalanceConfig.SectorSpec) -> Bool {
        guard !floor.isInvestment else { return false }
        guard floor.staff.count >= staffCapacity(spec: spec) else { return false }
        guard branchCount(for: floor, spec: spec) >= max(1, spec.branches.maxCount) else { return false }
        return spec.equipment.allSatisfy { item in
            floor.equipmentLevel(item.id) >= max(0, item.levels.count - 1)
        }
    }

    /// Satılan katın koruyacağı saniyelik pasif gelir. Satış anında donar.
    ///
    /// Holding çarpanı **burada uygulanmaz**: çarpan çalışma anında bütün
    /// katların brütüne zaten uygulanıyor, buraya da yazmak iki kez sayardı.
    static func investmentRate(
        of floor: FloorState,
        spec: BalanceConfig.SectorSpec,
        config: BalanceConfig
    ) -> Double {
        max(0, floorNet(floor, spec: spec)) * max(0, config.prestige.investmentShare)
    }

    /// Katı satmanın getireceği nakit. Kat olgun değilse `nil`.
    static func saleValue(onFloor index: Int, _ state: GameState, config: BalanceConfig) -> Double? {
        guard state.floors.indices.contains(index) else { return nil }
        let floor = state.floors[index]
        guard let spec = spec(for: floor, config: config), isMature(floor, spec: spec) else { return nil }
        return max(0, floorNet(floor, spec: spec))
            * holdingMultiplier(for: state, config: config)
            * max(0, config.prestige.payoutSeconds)
    }

    /// Olgunlaşan sektörü sat: nakit, kalıcı puan ve binada kalıcı bir iz.
    ///
    /// Satılan kat yok olmaz — yatırım katına dönüşür ve küçük bir pasif gelir
    /// üretmeye devam eder. Rapor §5 bunu şart koşuyor: oyuncu sattığı şeyin
    /// kaybolmadığını görmezse satmaya direnir.
    static func sellSector(
        onFloor index: Int,
        _ state: GameState,
        config: BalanceConfig
    ) -> Result<GameState, ActionError> {
        guard state.floors.indices.contains(index) else { return .failure(.unknownFloor) }
        let floor = state.floors[index]
        guard !floor.isInvestment else { return .failure(.sectorAlreadySold) }
        guard let spec = spec(for: floor, config: config) else { return .failure(.unknownSector) }
        guard isMature(floor, spec: spec) else { return .failure(.sectorNotMature) }
        guard let payout = saleValue(onFloor: index, state, config: config) else { return .failure(.sectorNotMature) }

        var next = normalised(state, config: config)
        next.money += payout
        next.lifetimeEarnings += payout
        next.holdingPoints += max(0, config.prestige.pointsPerSale)
        next.stats.sectorsSold += 1

        var sold = floor
        sold.investmentRate = investmentRate(of: floor, spec: spec, config: config)
        sold.staff = []
        sold.equipmentLevels = [:]
        sold.branchCount = 1
        next.floors[index] = sold

        // Müdür ve kurallar satılan katla birlikte gider; yatırım katı yönetilmez.
        next.managedSectors.removeAll { $0 == floor.sectorID }
        next.activeRules[floor.sectorID] = nil

        return .success(next)
    }

    // MARK: - Final: halka arz

    /// Bina halka arza hazır mı? Her sektöre girilmiş ve her kat ya satılmış
    /// ya da olgunlaşmış olmalı (rapor §5: "son sektör tamamlandığında").
    static func canGoPublic(_ state: GameState, config: BalanceConfig) -> Bool {
        guard !config.sectors.isEmpty else { return false }
        let opened = Set(state.floors.map(\.sectorID))
        guard config.sectors.allSatisfy({ opened.contains($0.id) }) else { return false }

        return state.floors.allSatisfy { floor in
            guard let spec = spec(for: floor, config: config) else { return true }
            return floor.isInvestment || isMature(floor, spec: spec)
        }
    }

    /// Holdingi halka arz et ve yeni şehre geç.
    ///
    /// Binaya ait olan her şey sıfırlanır; **sana ait olan kalır** — holding
    /// puanı, depo ve istatistikler. Böylece yeni şehir baştan başlamak değil,
    /// daha hızlı başlamak olur (rapor §5: "hızlandırılmış eğri").
    ///
    /// Motor saf: yeni oyunun zamanı `Date()` değil, kaydın kendi damgasıdır.
    static func goPublic(_ state: GameState, config: BalanceConfig) -> Result<GameState, ActionError> {
        guard canGoPublic(state, config: config) else { return .failure(.notReadyToGoPublic) }

        var next = GameState.newGame(
            characterID: state.characterID,
            sectorID: config.sectors.first?.id ?? GameState.groundSectorID,
            now: state.lastSeenAt
        )
        next.holdingPoints = state.holdingPoints + max(0, config.prestige.pointsPerCity)
        next.cityNumber = state.cityNumber + 1
        next.warehouseLevel = state.warehouseLevel
        next.lifetimeEarnings = state.lifetimeEarnings
        next.hasCelebratedFirstHire = state.hasCelebratedFirstHire
        // Yeni şehir yeni olay dizisi ister ama deterministik kalmalı.
        let advanced = state.eventSeed &+ 0x9E37_79B9_7F4A_7C15
        next.eventSeed = advanced == 0 ? 0x2545_F491_4F6C_DD1D : advanced
        next.stats = state.stats
        next.stats.citiesCompleted += 1
        return .success(next)
    }

    /// Panelin çalışacağı katı değiştir.
    static func selectFloor(_ index: Int, _ state: GameState) -> GameState {
        guard state.floors.indices.contains(index) else { return state }
        var next = state
        next.selectedFloor = index
        return next
    }
}
