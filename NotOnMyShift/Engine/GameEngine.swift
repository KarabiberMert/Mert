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
    static func floorGross(_ floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double {
        let multiplierSum = floor.staff.reduce(0.0) { $0 + $1.rateMultiplier }
        return spec.staff.ratePerSecond
            * multiplierSum
            * equipmentMultiplier(for: floor, spec: spec)
            * Double(branchCount(for: floor, spec: spec))
    }

    /// Katın saniyelik maaş gideri. Her şube kendi kadrosunu tutar.
    ///
    /// Ekipman maaş ödemez; tasarım raporundaki "eleman maaşı ile makine
    /// yatırımı arasında gerçek bir seçim" buradan doğuyor.
    static func floorWages(_ floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double {
        max(0, spec.staff.wagePerSecond)
            * Double(floor.staff.count)
            * Double(branchCount(for: floor, spec: spec))
    }

    /// Katın kasaya kattığı net. Maaş brütü geçerse kat sıfır üretir ama borç
    /// birikmez ve diğer katları da aşağı çekmez.
    static func floorNet(_ floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double {
        max(0, floorGross(floor, spec: spec) - floorWages(floor, spec: spec))
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

    static func grossRate(for state: GameState, config: BalanceConfig) -> Double {
        sum(state, config) { floorGross($0, spec: $1) }
    }

    static func wageRate(for state: GameState, config: BalanceConfig) -> Double {
        sum(state, config) { floorWages($0, spec: $1) }
    }

    /// Kasaya giren saniyelik net — katların netlerinin toplamı.
    /// Zarardaki bir kat kârdaki katı aşağı çekmez.
    static func productionRate(for state: GameState, config: BalanceConfig) -> Double {
        sum(state, config) { floorNet($0, spec: $1) }
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

    /// Bir sonraki şubenin ücreti. Kat doluysa `nil`.
    /// `cost(n) = baseCost * costGrowth^(n-1)` — n açılacak şubenin sırası.
    static func branchCost(for floor: FloorState, spec: BalanceConfig.SectorSpec) -> Double? {
        let current = branchCount(for: floor, spec: spec)
        guard current < max(1, spec.branches.maxCount) else { return nil }
        return max(0, spec.branches.baseCost * pow(max(1, spec.branches.costGrowth), Double(current - 1)))
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

    // MARK: - Zamanı ilerlet

    /// Ekonomiyi `seconds` kadar ilerletir.
    ///
    /// **Kapalı form** — döngü yok. Üretim oranı bu faz için sabit olduğundan
    /// 8 saatlik fark da 1 saniyelik fark da tek çarpma. Faz 4+'ta kırılım
    /// noktası (olay süresi, vardiya bitişi) geldiğinde burası segmentlere
    /// bölünecek; asla tick döngüsüne dönmeyecek.
    ///
    /// Saat okumaz, tavan uygulamaz. Tavan `resume(_:at:mode:config:)` işidir.
    static func advance(_ state: GameState, by seconds: TimeInterval, config: BalanceConfig) -> GameState {
        guard seconds.isFinite, seconds > 0 else { return state }

        let earned = productionRate(for: state, config: config) * seconds

        var next = state
        next.elapsedGameSeconds += seconds
        if earned > 0 {
            next.money += earned
            next.lifetimeEarnings += earned
        }
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

        switch change(floor, spec) {
        case .success(let purchase):
            var next = state
            next.floors[index] = purchase.floor
            next.money -= purchase.cost
            return .success(next)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Çağ 0: elle bir ürün sat.
    static func sellManually(onFloor index: Int, _ state: GameState, config: BalanceConfig) -> GameState {
        guard state.floors.indices.contains(index),
              let spec = spec(for: state.floors[index], config: config) else { return state }

        let revenue = manualRevenue(for: state.floors[index], spec: spec)
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
        var next = state
        next.money -= cost
        next.warehouseLevel += 1
        return .success(next)
    }

    /// Faz 3: bir üst katı aç. Kat açmak yeni bir sektöre girmektir.
    /// Yeni kat boş gelir — kendi kadrosunu ve ekipmanını sıfırdan kurarsın.
    static func unlockNextFloor(_ state: GameState, config: BalanceConfig) -> Result<GameState, ActionError> {
        guard let sector = nextSector(for: state, config: config) else {
            return .failure(.allFloorsOpen)
        }
        let cost = max(0, sector.unlockCost)
        guard state.money >= cost else { return .failure(.insufficientFunds) }

        var next = state
        next.money -= cost
        next.floors.append(FloorState(sectorID: sector.id))
        // Yeni kat hemen seçilsin: oyuncu açtığı şeyin başında olsun.
        next.selectedFloor = next.floors.count - 1
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
