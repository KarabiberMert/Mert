import Foundation
import Observation

/// Motor ile ekran arasındaki tek köprü.
///
/// Sorumlulukları: durumu tutmak, saati okumak, sahne fazını dinlemek, diske
/// yazmak. Ekonomi hesabı yapmaz — onu `GameEngine`'e sorar.
///
/// Zamanlayıcı **görsel tazeleme** içindir. Ekonomi her zaman `lastSeenAt` ile
/// `Date()` farkından türetilir; zamanlayıcı sadece "şimdi yeniden hesapla" der.
/// Bu yüzden zamanlayıcı gecikse, atlansa, arka planda dursa bile para doğru olur.
@MainActor
@Observable
final class GameStore {

    // MARK: - Dışarıya açık durum

    private(set) var state: GameState
    let config: BalanceConfig

    /// Çevrimdışı dönüş özeti. Doluysa ekranda gösterilir.
    var offlineReport: OfflineReport?

    /// Çağ 0 → Çağ 1 anı. İlk eleman tutulduğunda bir kez dolar.
    var firstHireCelebration: StaffMember?

    /// Son başarısız eylemin sebebi. Kullanıcı bir şey yapınca temizlenir.
    private(set) var lastActionError: GameEngine.ActionError?

    /// Kayıt ana dosyadan değil yedekten açıldı mı?
    private(set) var didRecoverFromBackup = false

    /// Diske yazma başarısız oldu mu?
    private(set) var didFailToSave = false

    // MARK: - Türetilmiş

    /// Kasaya giren net. Maaş düşülmüş hâli.
    var productionRate: Double { GameEngine.productionRate(for: state, config: config) }
    /// Maaş kesilmeden önceki üretim.
    var grossRate: Double { GameEngine.grossRate(for: state, config: config) }
    /// Saniyelik maaş gideri.
    var wageRate: Double { GameEngine.wageRate(for: state, config: config) }
    /// Elle bir satışın getirisi — ekipmanla birlikte büyür.
    var manualRevenue: Double { GameEngine.manualRevenue(for: state, config: config) }
    var equipmentMultiplier: Double { GameEngine.equipmentMultiplier(for: state, config: config) }
    var branchCount: Int { GameEngine.branchCount(for: state, config: config) }
    var branchCost: Double? { GameEngine.branchCost(for: state, config: config) }
    var maxBranches: Int { max(1, config.branches.maxCount) }

    /// Ekipman şeridinin satırları. Sıra `balance.json`'daki sıradır.
    var equipmentRows: [EquipmentRow] {
        config.equipment.map { spec in
            let level = min(state.equipmentLevel(spec.id), max(0, spec.levels.count - 1))
            return EquipmentRow(
                id: spec.id,
                level: level,
                maxLevel: max(0, spec.levels.count - 1),
                multiplier: spec.levels.indices.contains(level) ? spec.levels[level].multiplier : 1,
                upgradeCost: GameEngine.equipmentUpgradeCost(spec.id, for: state, config: config)
            )
        }
    }
    var hireCost: Double? { GameEngine.hireCost(for: state, config: config) }
    var warehouseUpgradeCost: Double? { GameEngine.warehouseUpgradeCost(for: state, config: config) }
    var offlineCapacitySeconds: TimeInterval { GameEngine.offlineCapacitySeconds(for: state, config: config) }

    /// Sonraki eleman için kaç kahve daha satmak gerekiyor?
    /// Çağ 0'da hedefi somutlaştırır: "38 kahve daha".
    var manualSalesUntilHire: Int? {
        guard let cost = hireCost, !state.isAutomated else { return nil }
        let revenue = manualRevenue
        guard revenue > 0 else { return nil }
        let remaining = cost - state.money
        guard remaining > 0 else { return nil }
        return Int((remaining / revenue).rounded(.up))
    }

    /// Sıradaki elemanın şablonu — "kimi tutuyorum" bilgisini butonda gösterebilmek için.
    var nextStaffTemplate: BalanceConfig.StaffTemplate? {
        let index = state.staff.count
        guard index < GameEngine.staffCapacity(config: config) else { return nil }
        return config.staffPool.indices.contains(index) ? config.staffPool[index] : nil
    }

    // MARK: - İç durum

    private let saves: SaveStore
    private let now: @Sendable () -> Date
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var secondsSinceSave: TimeInterval = 0

    /// Otomatik kaydetme aralığı. Arka plana geçişte ayrıca kaydediliyor;
    /// bu, uygulama öldürülürse kaybı sınırlamak için.
    private let autosaveInterval: TimeInterval = 20

    // MARK: - Kurulum

    /// - Parameter now: Saat kaynağı. Testlerde sahte saat verilebilsin diye enjekte edilir.
    init(config: BalanceConfig, saves: SaveStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.saves = saves
        self.now = now

        switch saves.load() {
        case .loaded(let loaded):
            self.state = loaded
        case .recovered(let loaded):
            self.state = loaded
            self.didRecoverFromBackup = true
        case .empty:
            self.state = GameState.newGame(characterID: "kahveci", now: now())
        }
    }

    // MARK: - Sahne fazı

    /// Uygulama öne geldi: uzakta geçen süreyi depo tavanıyla birlikte işle.
    func handleBecameActive() {
        let outcome = GameEngine.resume(state, at: now(), mode: .awayFromApp, config: config)
        state = outcome.state

        if outcome.shouldShowReport {
            offlineReport = OfflineReport(
                awaySeconds: outcome.elapsedSeconds,
                creditedSeconds: outcome.creditedSeconds,
                earned: outcome.earned,
                didFillWarehouse: outcome.didFillWarehouse
            )
        }

        persist()
        startTicking()
    }

    /// Uygulama arka plana gidiyor: saati damgala, kaydet, zamanlayıcıyı durdur.
    func handleWillResignActive() {
        stopTicking()
        // Ekranda görünen son saniyeleri de yazalım ki `lastSeenAt` tam olsun.
        let outcome = GameEngine.resume(state, at: now(), mode: .live, config: config)
        state = outcome.state
        persist()
    }

    // MARK: - Zamanlayıcı

    private func startTicking() {
        stopTicking()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    /// Görsel tazeleme adımı. Süreyi saatten okur, motora sorar.
    private func tick() {
        let outcome = GameEngine.resume(state, at: now(), mode: .live, config: config)
        state = outcome.state

        secondsSinceSave += outcome.creditedSeconds
        if secondsSinceSave >= autosaveInterval {
            persist()
            secondsSinceSave = 0
        }
    }

    // MARK: - Eylemler

    func sellManually() {
        lastActionError = nil
        state = GameEngine.sellManually(state, config: config)
        Haptics.play(.light)
    }

    func hireStaff() {
        switch GameEngine.hireStaff(state, config: config) {
        case .success(let next):
            let isFirstEver = !state.hasCelebratedFirstHire
            state = next
            lastActionError = nil

            if isFirstEver, let hired = next.staff.last {
                // Oyunun ilk büyük ödül anı: iş artık sensiz de yürüyor.
                state.hasCelebratedFirstHire = true
                firstHireCelebration = hired
                Haptics.play(.success)
            } else {
                Haptics.play(.medium)
            }
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    func upgradeWarehouse() {
        apply(GameEngine.upgradeWarehouse(state, config: config))
    }

    /// Satın alma sonuçlarının ortak yolu: durumu yaz, dokunsal geri bildirimi
    /// ver, kaydet. Başarısızlıkta sebebi ekrana taşı.
    private func apply(
        _ result: Result<GameState, GameEngine.ActionError>,
        success feedback: Haptics.Kind = .medium
    ) {
        switch result {
        case .success(let next):
            state = next
            lastActionError = nil
            Haptics.play(feedback)
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    func upgradeEquipment(_ id: String) {
        apply(GameEngine.upgradeEquipment(id, state, config: config))
    }

    func openBranch() {
        apply(GameEngine.openBranch(state, config: config), success: .success)
    }

    func dismissOfflineReport() {
        offlineReport = nil
    }

    func dismissFirstHireCelebration() {
        firstHireCelebration = nil
    }

    /// Sıfırdan başla. Faz 0'da geliştirme kolaylığı; ilerideki "yeni oyun" da bunu kullanacak.
    func startOver() {
        stopTicking()
        saves.deleteAll()
        state = GameState.newGame(characterID: "kahveci", now: now())
        offlineReport = nil
        firstHireCelebration = nil
        lastActionError = nil
        didRecoverFromBackup = false
        didFailToSave = false
        secondsSinceSave = 0
        persist()
        startTicking()
    }

    // MARK: - Kayıt

    private func persist() {
        do {
            try saves.save(state)
            didFailToSave = false
        } catch {
            didFailToSave = true
        }
    }
}

/// Ekipman şeridinin bir satırı.
struct EquipmentRow: Identifiable, Equatable, Sendable {
    let id: String
    var level: Int
    var maxLevel: Int
    /// Bu seviyenin üretim çarpanı.
    var multiplier: Double
    /// Sonraki seviyenin ücreti; son seviyedeyse `nil`.
    var upgradeCost: Double?

    var isMaxed: Bool { upgradeCost == nil }
}

/// Çevrimdışı dönüş özeti — ekranda gösterilen hâli.
struct OfflineReport: Identifiable, Equatable {
    let id = UUID()
    var awaySeconds: TimeInterval
    var creditedSeconds: TimeInterval
    var earned: Double
    var didFillWarehouse: Bool
}
