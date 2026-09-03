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
///
/// Faz 3'ten beri panel **seçili kat** üstünde çalışır; kasa ortaktır.
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

    /// Kat açıldığı an. Yeni sektörün kimliğini taşır.
    var newFloorCelebration: String?

    /// Son başarısız eylemin sebebi. Kullanıcı bir şey yapınca temizlenir.
    private(set) var lastActionError: GameEngine.ActionError?

    /// Kayıt ana dosyadan değil yedekten mi açıldı?
    private(set) var didRecoverFromBackup = false

    /// Diske yazma başarısız oldu mu?
    private(set) var didFailToSave = false

    // MARK: - Kat

    var floors: [FloorState] { state.floors }
    var selectedFloor: Int { state.safeSelectedFloor }

    /// Panelin üstünde çalıştığı kat.
    var currentFloor: FloorState? { state.currentFloor }

    /// Seçili katın sektör tanımı.
    var currentSpec: BalanceConfig.SectorSpec? {
        currentFloor.flatMap { GameEngine.spec(for: $0, config: config) }
    }

    /// Kat başına hücre (şube) sayısı — bina çizimi bunu ister.
    var unitCounts: [Int] {
        floors.map { floor in
            guard let spec = GameEngine.spec(for: floor, config: config) else { return 1 }
            return GameEngine.branchCount(for: floor, spec: spec)
        }
    }

    /// Bir katın sektör kimliği — tabela ve şerit başlığı için.
    func sectorID(of index: Int) -> String? {
        floors.indices.contains(index) ? floors[index].sectorID : nil
    }

    // MARK: - Türetilmiş oranlar

    /// Kasaya giren net. Maaş düşülmüş hâli.
    var productionRate: Double { GameEngine.productionRate(for: state, config: config) }
    /// Maaş kesilmeden önceki üretim.
    var grossRate: Double { GameEngine.grossRate(for: state, config: config) }
    /// Saniyelik maaş gideri.
    var wageRate: Double { GameEngine.wageRate(for: state, config: config) }
    var offlineCapacitySeconds: TimeInterval { GameEngine.offlineCapacitySeconds(for: state, config: config) }
    var warehouseUpgradeCost: Double? { GameEngine.warehouseUpgradeCost(for: state, config: config) }

    /// Bir katın kendi neti — şerit üstünde gösterilir.
    func netRate(of index: Int) -> Double {
        guard floors.indices.contains(index),
              let spec = GameEngine.spec(for: floors[index], config: config) else { return 0 }
        return GameEngine.floorNet(floors[index], spec: spec)
    }

    // MARK: - Seçili kata bağlı

    /// Elle bir satışın getirisi — ekipmanla birlikte büyür.
    var manualRevenue: Double {
        guard let floor = currentFloor, let spec = currentSpec else { return 0 }
        return GameEngine.manualRevenue(for: floor, spec: spec)
    }

    var hireCost: Double? {
        guard let floor = currentFloor, let spec = currentSpec else { return nil }
        return GameEngine.hireCost(for: floor, spec: spec)
    }

    /// Sıradaki elemanın şablonu — "kimi tutuyorum" bilgisini satırda gösterebilmek için.
    var nextStaffTemplate: BalanceConfig.StaffTemplate? {
        guard let floor = currentFloor, let spec = currentSpec else { return nil }
        let index = floor.staff.count
        guard index < GameEngine.staffCapacity(spec: spec) else { return nil }
        return spec.staffPool.indices.contains(index) ? spec.staffPool[index] : nil
    }

    /// Sonraki eleman için kaç satış daha gerekiyor?
    /// Çağ 0'da hedefi somutlaştırır: "38 kahve daha".
    var manualSalesUntilHire: Int? {
        guard let floor = currentFloor, let cost = hireCost, !floor.isAutomated else { return nil }
        let revenue = manualRevenue
        guard revenue > 0 else { return nil }
        let remaining = cost - state.money
        guard remaining > 0 else { return nil }
        return Int((remaining / revenue).rounded(.up))
    }

    var branchCount: Int {
        guard let floor = currentFloor, let spec = currentSpec else { return 1 }
        return GameEngine.branchCount(for: floor, spec: spec)
    }

    var branchCost: Double? {
        guard let floor = currentFloor, let spec = currentSpec else { return nil }
        return GameEngine.branchCost(for: floor, spec: spec)
    }

    var maxBranches: Int { max(1, currentSpec?.branches.maxCount ?? 1) }

    /// Ekipman şeridinin satırları. Sıra `balance.json`'daki sıradır.
    var equipmentRows: [EquipmentRow] {
        guard let floor = currentFloor, let spec = currentSpec else { return [] }
        return spec.equipment.map { item in
            let level = min(floor.equipmentLevel(item.id), max(0, item.levels.count - 1))
            return EquipmentRow(
                id: item.id,
                level: level,
                maxLevel: max(0, item.levels.count - 1),
                multiplier: item.levels.indices.contains(level) ? item.levels[level].multiplier : 1,
                upgradeCost: GameEngine.equipmentUpgradeCost(item.id, for: floor, spec: spec)
            )
        }
    }

    // MARK: - Kat açma

    var nextFloorCost: Double? { GameEngine.nextFloorCost(for: state, config: config) }
    var nextSector: BalanceConfig.SectorSpec? { GameEngine.nextSector(for: state, config: config) }

    /// Bina kaç kata kadar yükselecek — palet geçişi bunun üstünden hesaplanır.
    var plannedFloors: Int { max(1, config.building.paletteFloors) }

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

        let groundSector = config.sectors.first?.id ?? GameState.groundSectorID
        switch saves.load() {
        case .loaded(let loaded):
            self.state = loaded
        case .recovered(let loaded):
            self.state = loaded
            self.didRecoverFromBackup = true
        case .empty:
            self.state = GameState.newGame(characterID: "kahveci", sectorID: groundSector, now: now())
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
        state = GameEngine.sellManually(onFloor: selectedFloor, state, config: config)
        Haptics.play(.light)
    }

    func hireStaff() {
        let wasFirstEver = !state.hasCelebratedFirstHire
        switch GameEngine.hireStaff(onFloor: selectedFloor, state, config: config) {
        case .success(var next):
            lastActionError = nil
            if wasFirstEver, let hired = next.floors[safe: selectedFloor]?.staff.last {
                // Oyunun ilk büyük ödül anı: iş artık sensiz de yürüyor.
                next.hasCelebratedFirstHire = true
                state = next
                firstHireCelebration = hired
                Haptics.play(.success)
            } else {
                state = next
                Haptics.play(.medium)
            }
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    func upgradeEquipment(_ id: String) {
        apply(GameEngine.upgradeEquipment(id, onFloor: selectedFloor, state, config: config))
    }

    func openBranch() {
        apply(GameEngine.openBranch(onFloor: selectedFloor, state, config: config), success: .success)
    }

    func upgradeWarehouse() {
        apply(GameEngine.upgradeWarehouse(state, config: config))
    }

    /// Faz 3: bir üst katı aç — yeni bir sektöre gir.
    func unlockNextFloor() {
        let opening = nextSector?.id
        switch GameEngine.unlockNextFloor(state, config: config) {
        case .success(let next):
            state = next
            lastActionError = nil
            newFloorCelebration = opening
            Haptics.play(.success)
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    func selectFloor(_ index: Int) {
        guard index != state.selectedFloor else { return }
        state = GameEngine.selectFloor(index, state)
        lastActionError = nil
        Haptics.play(.light)
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

    func dismissOfflineReport() {
        offlineReport = nil
    }

    func dismissFirstHireCelebration() {
        firstHireCelebration = nil
    }

    func dismissNewFloorCelebration() {
        newFloorCelebration = nil
    }

    /// Sıfırdan başla. Geliştirme kolaylığı; ilerideki "yeni oyun" da bunu kullanacak.
    func startOver() {
        stopTicking()
        saves.deleteAll()
        state = GameState.newGame(
            characterID: "kahveci",
            sectorID: config.sectors.first?.id ?? GameState.groundSectorID,
            now: now()
        )
        offlineReport = nil
        firstHireCelebration = nil
        newFloorCelebration = nil
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

private extension Array {
    /// Sınır dışı indeks çökme değil `nil` versin.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
