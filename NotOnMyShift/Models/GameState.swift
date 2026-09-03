import Foundation

/// Oyunun kaydedilebilir tüm durumu.
///
/// Bu tip UI bilmez, motor bilmez; sadece veridir. `GameEngine` bunu alır,
/// yeni bir kopya döndürür. Kaydetme/yükleme de bunun üstünden yürür.
///
/// Şema değişince `currentSchemaVersion` artırılır. Eski kayıtların
/// bozulmaması için tüm alanlar `decodeIfPresent` ile okunur — sonradan
/// eklenen bir alan, o alanı tanımayan eski kaydı çöpe atmaz.
struct GameState: Codable, Sendable, Equatable {

    /// 1 → Faz 0-1 · 2 → ilk eleman kutlaması · 3 → ekipman ve şubeler
    /// 4 → kat kat bina (tek dükkân yerine `floors`)
    static let currentSchemaVersion = 4

    /// Şema 4 öncesi kayıtlarda kat yoktu; eldeki dükkân zemin kattır.
    static let groundSectorID = "coffee"

    /// Kaydın hangi şema sürümüyle yazıldığı.
    var schemaVersion: Int

    /// Oyuncunun seçtiği karakter. Faz 0'da tek seçenek var.
    var characterID: String

    /// Kasadaki para. Bütün katlar aynı kasaya çalışır.
    var money: Double

    /// Oyun boyunca kazanılan toplam para. Harcamayla azalmaz.
    var lifetimeEarnings: Double

    /// Motorun işlediği toplam saniye. Çevrimdışı geçen ve krediye yazılan
    /// süre de buna dahildir; kesilen (tavanı aşan) süre dahil değildir.
    var elapsedGameSeconds: TimeInterval

    /// Ekonominin tek zaman çıpası. Her ilerlemede güncellenir.
    /// Çevrimdışı kazanç bunun ile `Date()` farkından hesaplanır — timer'dan değil.
    var lastSeenAt: Date

    /// Oyunun ilk açıldığı an. Sadece istatistik için.
    var startedAt: Date

    /// Depo (çevrimdışı kapasite) seviyesi. Oyuncunun kendi kapasitesi;
    /// katlara bölünmez.
    var warehouseLevel: Int

    /// Çağ 0 → Çağ 1 geçişi kutlandı mı? Bu an bir kez yaşanır. (şema 2)
    var hasCelebratedFirstHire: Bool

    /// Açılmış katlar, aşağıdan yukarı. Sıfırıncı kat zemin kattır. (şema 4)
    var floors: [FloorState]

    /// Panelin üstünde çalıştığı kat. Sınır dışına çıkarsa kırpılır.
    var selectedFloor: Int

    var stats: Stats

    // MARK: - Yeni oyun

    /// Sıfırdan bir oyun durumu. Saati dışarıdan alır ki motor tarafı saf kalsın.
    static func newGame(characterID: String, sectorID: String = groundSectorID, now: Date) -> GameState {
        GameState(
            schemaVersion: currentSchemaVersion,
            characterID: characterID,
            money: 0,
            lifetimeEarnings: 0,
            elapsedGameSeconds: 0,
            lastSeenAt: now,
            startedAt: now,
            warehouseLevel: 0,
            hasCelebratedFirstHire: false,
            floors: [FloorState(sectorID: sectorID)],
            selectedFloor: 0,
            stats: Stats()
        )
    }

    // MARK: - Türetilmiş

    /// İş kendi kendine yürüyor mu? (Çağ 0 → Çağ 1 geçişi)
    var isAutomated: Bool { floors.contains { !$0.staff.isEmpty } }

    /// Sınır içine kırpılmış seçili kat indeksi.
    var safeSelectedFloor: Int {
        guard !floors.isEmpty else { return 0 }
        return min(max(0, selectedFloor), floors.count - 1)
    }

    /// Panelin üstünde çalıştığı kat.
    var currentFloor: FloorState? {
        floors.indices.contains(safeSelectedFloor) ? floors[safeSelectedFloor] : nil
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, characterID, money, lifetimeEarnings
        case elapsedGameSeconds, lastSeenAt, startedAt, warehouseLevel, stats
        case hasCelebratedFirstHire, floors, selectedFloor
        // Şema 3 ve öncesinden kalan düz alanlar — sadece göç için okunur.
        case staff, equipmentLevels, branchCount
    }

    init(
        schemaVersion: Int,
        characterID: String,
        money: Double,
        lifetimeEarnings: Double,
        elapsedGameSeconds: TimeInterval,
        lastSeenAt: Date,
        startedAt: Date,
        warehouseLevel: Int,
        hasCelebratedFirstHire: Bool,
        floors: [FloorState],
        selectedFloor: Int,
        stats: Stats
    ) {
        self.schemaVersion = schemaVersion
        self.characterID = characterID
        self.money = money
        self.lifetimeEarnings = lifetimeEarnings
        self.elapsedGameSeconds = elapsedGameSeconds
        self.lastSeenAt = lastSeenAt
        self.startedAt = startedAt
        self.warehouseLevel = warehouseLevel
        self.hasCelebratedFirstHire = hasCelebratedFirstHire
        self.floors = floors
        self.selectedFloor = selectedFloor
        self.stats = stats
    }

    /// Eksik alan tolere edilir. Amaç: şema büyüdükçe eski kaydın hâlâ açılması.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        characterID = try container.decodeIfPresent(String.self, forKey: .characterID) ?? "kahveci"
        money = try container.decodeIfPresent(Double.self, forKey: .money) ?? 0
        lifetimeEarnings = try container.decodeIfPresent(Double.self, forKey: .lifetimeEarnings) ?? 0
        elapsedGameSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsedGameSeconds) ?? 0
        lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt) ?? now
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? now
        warehouseLevel = try container.decodeIfPresent(Int.self, forKey: .warehouseLevel) ?? 0

        let savedFloors = try container.decodeIfPresent([FloorState].self, forKey: .floors)
        if let savedFloors, !savedFloors.isEmpty {
            floors = savedFloors
        } else {
            // Şema 3 ve öncesi: tek dükkân düz alanlarda duruyordu.
            // Onu zemin kata taşıyoruz; oyuncu hiçbir şey kaybetmiyor.
            floors = [
                FloorState(
                    sectorID: Self.groundSectorID,
                    staff: try container.decodeIfPresent([StaffMember].self, forKey: .staff) ?? [],
                    equipmentLevels: try container.decodeIfPresent([String: Int].self, forKey: .equipmentLevels) ?? [:],
                    branchCount: max(1, try container.decodeIfPresent(Int.self, forKey: .branchCount) ?? 1)
                )
            ]
        }

        selectedFloor = try container.decodeIfPresent(Int.self, forKey: .selectedFloor) ?? 0

        // Şema 1 kayıtlarında bu alan yok. Zaten eleman tutmuşsa kutlamayı
        // tekrar göstermeyelim — o an bir kez yaşanır.
        hasCelebratedFirstHire = try container.decodeIfPresent(Bool.self, forKey: .hasCelebratedFirstHire)
            ?? floors.contains { !$0.staff.isEmpty }
        stats = try container.decodeIfPresent(Stats.self, forKey: .stats) ?? Stats()
    }

    /// Göç alanları yazılmaz: kayıt her zaman güncel şemayla çıkar.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(characterID, forKey: .characterID)
        try container.encode(money, forKey: .money)
        try container.encode(lifetimeEarnings, forKey: .lifetimeEarnings)
        try container.encode(elapsedGameSeconds, forKey: .elapsedGameSeconds)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(warehouseLevel, forKey: .warehouseLevel)
        try container.encode(hasCelebratedFirstHire, forKey: .hasCelebratedFirstHire)
        try container.encode(floors, forKey: .floors)
        try container.encode(selectedFloor, forKey: .selectedFloor)
        try container.encode(stats, forKey: .stats)
    }
}

// MARK: - Kat

/// Bir kat = bir sektör. Kat içindeki hücreler o sektörün şubeleridir.
struct FloorState: Codable, Sendable, Equatable, Identifiable {

    /// `BalanceConfig.SectorSpec` kimliği. Sektörün adı dil dosyalarında.
    var sectorID: String

    /// Bu katın kadrosu. Şubeler aynı kadroyla çalışır.
    var staff: [StaffMember]

    /// Ekipman kimliği → sahip olunan seviye. Eksik kimlik 0 sayılır,
    /// böylece dengeye yeni bir parça eklemek eski kaydı bozmaz.
    var equipmentLevels: [String: Int]

    /// Açık şube sayısı. En az 1 — ana dükkân da bir şubedir.
    var branchCount: Int

    var id: String { sectorID }

    private enum CodingKeys: String, CodingKey {
        case sectorID, staff, equipmentLevels, branchCount
    }

    init(
        sectorID: String,
        staff: [StaffMember] = [],
        equipmentLevels: [String: Int] = [:],
        branchCount: Int = 1
    ) {
        self.sectorID = sectorID
        self.staff = staff
        self.equipmentLevels = equipmentLevels
        self.branchCount = max(1, branchCount)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sectorID = try container.decodeIfPresent(String.self, forKey: .sectorID) ?? GameState.groundSectorID
        staff = try container.decodeIfPresent([StaffMember].self, forKey: .staff) ?? []
        equipmentLevels = try container.decodeIfPresent([String: Int].self, forKey: .equipmentLevels) ?? [:]
        branchCount = max(1, try container.decodeIfPresent(Int.self, forKey: .branchCount) ?? 1)
    }

    /// Bir ekipmanın sahip olunan seviyesi. Tanımadığımız kimlik 0'dır.
    func equipmentLevel(_ id: String) -> Int {
        max(0, equipmentLevels[id] ?? 0)
    }

    var isAutomated: Bool { !staff.isEmpty }
}

// MARK: - Kadro

/// Kadrodaki bir eleman.
struct StaffMember: Codable, Sendable, Equatable, Identifiable {

    /// Havuzdaki şablonun kimliği. İşe alım sırası deterministik olduğu için
    /// rastgele bir kimliğe gerek yok — motor saf kalır.
    ///
    /// İsim ve huy metni burada saklanmaz: dile göre değişirler ve kimlikten
    /// çözülürler (`L.staffName`, `L.staffTrait`). Böylece oyuncu dili
    /// değiştirdiğinde mevcut kadro da yeni dilde görünür.
    let id: String

    /// Bu elemanın taban üretim hızına uyguladığı çarpan.
    var rateMultiplier: Double

    /// İşe alındığı an — `elapsedGameSeconds` cinsinden. Takvim saati değil,
    /// çünkü motor içinde `Date()` çağırmıyoruz.
    var hiredAtGameSeconds: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case id, rateMultiplier, hiredAtGameSeconds
    }

    init(id: String, rateMultiplier: Double, hiredAtGameSeconds: TimeInterval) {
        self.id = id
        self.rateMultiplier = rateMultiplier
        self.hiredAtGameSeconds = hiredAtGameSeconds
    }

    /// Eski kayıtlarda `name` ve `trait` alanları da vardı; artık okunmuyorlar
    /// ve JSONDecoder fazladan anahtarları görmezden geliyor.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "unknown"
        rateMultiplier = try container.decodeIfPresent(Double.self, forKey: .rateMultiplier) ?? 1
        hiredAtGameSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .hiredAtGameSeconds) ?? 0
    }
}

// MARK: - İstatistik

struct Stats: Codable, Sendable, Equatable {

    /// Elle yapılan satış sayısı (Çağ 0 emeği).
    var manualSales: Int

    /// Kaç kez çevrimdışı kazançla dönüldü.
    var offlineReturns: Int

    /// En son çevrimdışı dönüşte yazılan para.
    var lastOfflineEarnings: Double

    /// Depo tavanına takılıp yanan toplam saniye. Yükseltme motivasyonu bu sayıdan gelir.
    var wastedOfflineSeconds: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case manualSales, offlineReturns, lastOfflineEarnings, wastedOfflineSeconds
    }

    init(
        manualSales: Int = 0,
        offlineReturns: Int = 0,
        lastOfflineEarnings: Double = 0,
        wastedOfflineSeconds: TimeInterval = 0
    ) {
        self.manualSales = manualSales
        self.offlineReturns = offlineReturns
        self.lastOfflineEarnings = lastOfflineEarnings
        self.wastedOfflineSeconds = wastedOfflineSeconds
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manualSales = try container.decodeIfPresent(Int.self, forKey: .manualSales) ?? 0
        offlineReturns = try container.decodeIfPresent(Int.self, forKey: .offlineReturns) ?? 0
        lastOfflineEarnings = try container.decodeIfPresent(Double.self, forKey: .lastOfflineEarnings) ?? 0
        wastedOfflineSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .wastedOfflineSeconds) ?? 0
    }
}
