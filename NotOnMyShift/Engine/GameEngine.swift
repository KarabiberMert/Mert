import Foundation

/// Oyunun ekonomisi. Tamamen saf: `Date()`, `Timer`, `UserDefaults`, dosya —
/// hiçbiri yok. Her fonksiyon girdi alır, yeni bir `GameState` döndürür.
///
/// Bu kural sayesinde tüm ekonomi UI olmadan test edilebilir. Saate ihtiyaç
/// duyan tek fonksiyon `resume(_:at:mode:config:)` ve o da saati parametre
/// olarak alır — içeride okumaz.
enum GameEngine {

    // MARK: - Hatalar

    enum ActionError: Error, Sendable, Equatable {
        /// Para yetmiyor.
        case insufficientFunds
        /// Kahve arabasına daha fazla eleman sığmıyor.
        case staffLimitReached
        /// Depo ya da ekipman son seviyede.
        case maxLevelReached
        /// Dengede böyle bir ekipman yok.
        case unknownEquipment
        /// Kata sığacak hücre kalmadı.
        case branchLimitReached
    }

    // MARK: - Türetilmiş değerler

    /// Ekipmanın toplam üretim çarpanı. Her parçanın seviye çarpanı çarpılır.
    static func equipmentMultiplier(for state: GameState, config: BalanceConfig) -> Double {
        config.equipment.reduce(1.0) { product, spec in
            let level = min(state.equipmentLevel(spec.id), spec.levels.count - 1)
            guard spec.levels.indices.contains(level) else { return product }
            return product * max(0, spec.levels[level].multiplier)
        }
    }

    /// Maaş kesilmeden önceki saniyelik üretim. Kadro boşsa 0 — yani Çağ 0'da
    /// çevrimdışı kazanç da kendiliğinden yoktur, ayrı bir bayrağa gerek kalmaz.
    ///
    /// Her şube aynı kadro ve ekipmanla çalışır (tek tuş kopyalama), dolayısıyla
    /// üretim şube sayısıyla doğrusal çarpılır.
    static func grossRate(for state: GameState, config: BalanceConfig) -> Double {
        let multiplierSum = state.staff.reduce(0.0) { $0 + $1.rateMultiplier }
        return config.staff.ratePerSecond
            * multiplierSum
            * equipmentMultiplier(for: state, config: config)
            * Double(branchCount(for: state, config: config))
    }

    /// Saniyelik maaş gideri. Her şube kendi kadrosunu tutar.
    ///
    /// Ekipman maaş ödemez; tasarım raporundaki "eleman maaşı ile makine
    /// yatırımı arasında gerçek bir seçim" buradan doğuyor.
    static func wageRate(for state: GameState, config: BalanceConfig) -> Double {
        max(0, config.staff.wagePerSecond)
            * Double(state.staff.count)
            * Double(branchCount(for: state, config: config))
    }

    /// Kasaya giren saniyelik net. Maaş brütü geçerse üretim durur ama borç
    /// birikmez — oyuncuyu geri götüren mekanik istemiyoruz.
    static func productionRate(for state: GameState, config: BalanceConfig) -> Double {
        max(0, grossRate(for: state, config: config) - wageRate(for: state, config: config))
    }

    /// Elle bir satışın getirisi. Ekipman Çağ 0'da da işe yarar.
    static func manualRevenue(for state: GameState, config: BalanceConfig) -> Double {
        max(0, config.manual.revenuePerSale) * equipmentMultiplier(for: state, config: config)
    }

    /// Açık şube sayısı — kayıttaki değer dengedeki sınıra kırpılır.
    static func branchCount(for state: GameState, config: BalanceConfig) -> Int {
        min(max(1, state.branchCount), max(1, config.branches.maxCount))
    }

    /// Deponun tuttuğu çevrimdışı süre. Bunun ötesindeki süre yanar.
    static func offlineCapacitySeconds(for state: GameState, config: BalanceConfig) -> TimeInterval {
        let levels = config.warehouse.levels
        guard !levels.isEmpty else { return 0 }
        let index = min(max(state.warehouseLevel, 0), levels.count - 1)
        return max(0, levels[index].capacitySeconds)
    }

    /// Bir sonraki elemanın ücreti. Kadro doluysa `nil`.
    /// `cost(n) = baseCost * costGrowth^n`
    static func hireCost(for state: GameState, config: BalanceConfig) -> Double? {
        guard state.staff.count < staffCapacity(config: config) else { return nil }
        return config.staff.baseCost * pow(config.staff.costGrowth, Double(state.staff.count))
    }

    /// Bir sonraki depo seviyesinin ücreti. Son seviyedeyse `nil`.
    static func warehouseUpgradeCost(for state: GameState, config: BalanceConfig) -> Double? {
        let next = state.warehouseLevel + 1
        guard config.warehouse.levels.indices.contains(next) else { return nil }
        return max(0, config.warehouse.levels[next].cost)
    }

    /// Bir ekipmanın sonraki seviyesinin ücreti. Son seviyedeyse ya da kimlik
    /// tanınmıyorsa `nil`.
    static func equipmentUpgradeCost(_ id: String, for state: GameState, config: BalanceConfig) -> Double? {
        guard let spec = config.equipment.first(where: { $0.id == id }) else { return nil }
        let next = state.equipmentLevel(id) + 1
        guard spec.levels.indices.contains(next) else { return nil }
        return max(0, spec.levels[next].cost)
    }

    /// Bir sonraki şubenin ücreti. Kat doluysa `nil`.
    /// `cost(n) = baseCost * costGrowth^(n-1)` — n açılacak şubenin sırası.
    static func branchCost(for state: GameState, config: BalanceConfig) -> Double? {
        let current = branchCount(for: state, config: config)
        guard current < max(1, config.branches.maxCount) else { return nil }
        return max(0, config.branches.baseCost * pow(max(1, config.branches.costGrowth), Double(current - 1)))
    }

    /// Kadro üst sınırı: dengedeki sınır ile havuzdaki şablon sayısının küçüğü.
    /// Havuz tükenirse isimsiz eleman üretmek yerine duruyoruz.
    static func staffCapacity(config: BalanceConfig) -> Int {
        min(max(0, config.staff.maxCount), config.staffPool.count)
    }

    // MARK: - Zamanı ilerlet

    /// Ekonomiyi `seconds` kadar ilerletir.
    ///
    /// **Kapalı form** — döngü yok. Üretim oranı bu faz için sabit olduğundan
    /// 8 saatlik fark da 1 saniyelik fark da tek çarpma. Faz 1+'de kırılım
    /// noktası (kapasite dolması, vardiya bitişi) geldiğinde burası segmentlere
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

    // MARK: - Eylemler

    /// Çağ 0: elle bir kahve sat.
    static func sellManually(_ state: GameState, config: BalanceConfig) -> GameState {
        let revenue = manualRevenue(for: state, config: config)
        var next = state
        next.money += revenue
        next.lifetimeEarnings += revenue
        next.stats.manualSales += 1
        return next
    }

    /// Çağ 1: sıradaki elemanı işe al. Havuz sırası deterministiktir.
    static func hireStaff(_ state: GameState, config: BalanceConfig) -> Result<GameState, ActionError> {
        guard let cost = hireCost(for: state, config: config) else {
            return .failure(.staffLimitReached)
        }
        guard state.money >= cost else {
            return .failure(.insufficientFunds)
        }
        let template = config.staffPool[state.staff.count]

        var next = state
        next.money -= cost
        next.staff.append(
            StaffMember(
                id: template.id,
                rateMultiplier: template.rateMultiplier,
                hiredAtGameSeconds: state.elapsedGameSeconds
            )
        )
        return .success(next)
    }

    /// Çağ 2: bir ekipmanı bir seviye yükselt.
    static func upgradeEquipment(
        _ id: String,
        _ state: GameState,
        config: BalanceConfig
    ) -> Result<GameState, ActionError> {
        guard config.equipment.contains(where: { $0.id == id }) else {
            return .failure(.unknownEquipment)
        }
        guard let cost = equipmentUpgradeCost(id, for: state, config: config) else {
            return .failure(.maxLevelReached)
        }
        guard state.money >= cost else {
            return .failure(.insufficientFunds)
        }
        var next = state
        next.money -= cost
        next.equipmentLevels[id] = state.equipmentLevel(id) + 1
        return .success(next)
    }

    /// Yeni bir şube aç. Şube mevcut kadro ve ekipmanı devralır; ayrı ayarı yok.
    static func openBranch(_ state: GameState, config: BalanceConfig) -> Result<GameState, ActionError> {
        guard let cost = branchCost(for: state, config: config) else {
            return .failure(.branchLimitReached)
        }
        guard state.money >= cost else {
            return .failure(.insufficientFunds)
        }
        var next = state
        next.money -= cost
        next.branchCount = branchCount(for: state, config: config) + 1
        return .success(next)
    }

    /// Depoyu bir seviye büyüt — yani çevrimdışı kazanç tavanını yükselt.
    static func upgradeWarehouse(_ state: GameState, config: BalanceConfig) -> Result<GameState, ActionError> {
        guard let cost = warehouseUpgradeCost(for: state, config: config) else {
            return .failure(.maxLevelReached)
        }
        guard state.money >= cost else {
            return .failure(.insufficientFunds)
        }
        var next = state
        next.money -= cost
        next.warehouseLevel += 1
        return .success(next)
    }
}
