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
    /// 4 → kat kat bina (tek dükkân yerine `floors`) · 5 → olaylar ve pazar
    /// 6 → çatı katı ve süreç katmanı · 7 → sektör satışı ve holding puanı
    static let currentSchemaVersion = 7

    /// `marketShare` ve `nextEventAtGameSeconds` için "henüz kurulmadı" işareti.
    /// Kod çözücünün dengeye erişimi yok; ilk değerleri motor koyuyor.
    static let unset: Double = -1

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

    /// Süren olay etkileri. Üretim oranını çarparlar ve bitiş anları
    /// `advance` için kırılım noktasıdır. (şema 5)
    var modifiers: [ActiveModifier]

    /// Sıradaki olayın çıkacağı oyun anı. `unset` ise motor planlar.
    var nextEventAtGameSeconds: TimeInterval

    /// Olay seçiminin deterministik tohumu. Motor saf kalsın diye rastgelelik
    /// buradan türetilir, `Date()` ya da sistem RNG'sinden değil.
    var eventSeed: UInt64

    /// Oyuncunun pazar payı (0..1). `unset` ise motor başlangıç payını koyar.
    var marketShare: Double

    /// Çatı katı (yönetim ofisi) açıldı mı? Süreç katmanı buradan yürür. (şema 6)
    var hasRoof: Bool

    /// Müdür atanmış katların sektör kimlikleri. Müdürsüz katta kural çalışmaz.
    var managedSectors: [String]

    /// Sektör kimliği → açık kural kimlikleri. Kurallar hem otomasyon yapar
    /// hem kata verim bonusu katar.
    var activeRules: [String: [String]]

    /// Müdür olayları kendi karara bağlasın mı? Saf kolaylık, bonusu yok.
    var autoResolvesEvents: Bool

    /// Satılan her sektörden kalan kalıcı puan. (şema 7)
    ///
    /// **Asla azalmaz** — halka arzda bile taşınır. Tüm katların brütünü
    /// çarpar; rapor §5'in "tüm gelecek işlere pasif çarpan"ı budur.
    var holdingPoints: Int

    /// Kaçıncı şehirdesin. İlk oyun 1; her halka arz bunu bir artırır.
    var cityNumber: Int

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
            modifiers: [],
            nextEventAtGameSeconds: unset,
            eventSeed: Self.seed(from: now),
            marketShare: unset,
            hasRoof: false,
            managedSectors: [],
            activeRules: [:],
            autoResolvesEvents: false,
            holdingPoints: 0,
            cityNumber: 1,
            stats: Stats()
        )
    }

    // MARK: - Türetilmiş

    /// İş kendi kendine yürüyor mu? (Çağ 0 → Çağ 1 geçişi)
    /// Yatırım katı da sensiz üretir — kadrosu olmasa bile.
    var isAutomated: Bool { floors.contains(where: \.isAutomated) }

    /// Bu katta müdür var mı?
    func hasManager(_ sectorID: String) -> Bool {
        managedSectors.contains(sectorID)
    }

    /// Bu katta açık kurallar. Müdür yoksa hiçbiri çalışmaz.
    func rules(for sectorID: String) -> [String] {
        guard hasManager(sectorID) else { return [] }
        return activeRules[sectorID] ?? []
    }

    /// Deterministik tohum. Kayıt başına sabit, kayıtlar arasında farklı.
    static func seed(from date: Date) -> UInt64 {
        let ticks = UInt64(bitPattern: Int64(date.timeIntervalSince1970 * 1_000))
        return ticks == 0 ? 0x2545F4914F6CDD1D : ticks
    }

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
        case modifiers, nextEventAtGameSeconds, eventSeed, marketShare
        case hasRoof, managedSectors, activeRules, autoResolvesEvents
        case holdingPoints, cityNumber
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
        modifiers: [ActiveModifier],
        nextEventAtGameSeconds: TimeInterval,
        eventSeed: UInt64,
        marketShare: Double,
        hasRoof: Bool,
        managedSectors: [String],
        activeRules: [String: [String]],
        autoResolvesEvents: Bool,
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
        self.modifiers = modifiers
        self.nextEventAtGameSeconds = nextEventAtGameSeconds
        self.eventSeed = eventSeed
        self.marketShare = marketShare
        self.hasRoof = hasRoof
        self.managedSectors = managedSectors
        self.activeRules = activeRules
        self.autoResolvesEvents = autoResolvesEvents
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

        // Şema 5 öncesi kayıtlarda olay ve pazar yoktu. Eksik değerler
        // `unset` kalır; ilk ilerlemede motor dengeden doldurur.
        modifiers = try container.decodeIfPresent([ActiveModifier].self, forKey: .modifiers) ?? []
        nextEventAtGameSeconds = try container.decodeIfPresent(
            TimeInterval.self, forKey: .nextEventAtGameSeconds
        ) ?? Self.unset
        eventSeed = try container.decodeIfPresent(UInt64.self, forKey: .eventSeed)
            ?? Self.seed(from: startedAt)
        marketShare = try container.decodeIfPresent(Double.self, forKey: .marketShare) ?? Self.unset

        // Şema 6 öncesi kayıtlarda süreç katmanı yoktu. Kapalı başlar.
        hasRoof = try container.decodeIfPresent(Bool.self, forKey: .hasRoof) ?? false
        managedSectors = try container.decodeIfPresent([String].self, forKey: .managedSectors) ?? []
        activeRules = try container.decodeIfPresent([String: [String]].self, forKey: .activeRules) ?? [:]
        autoResolvesEvents = try container.decodeIfPresent(Bool.self, forKey: .autoResolvesEvents) ?? false

        // Şema 7 öncesinde prestij yoktu: puan sıfır, ilk şehir.
        holdingPoints = max(0, try container.decodeIfPresent(Int.self, forKey: .holdingPoints) ?? 0)
        cityNumber = max(1, try container.decodeIfPresent(Int.self, forKey: .cityNumber) ?? 1)

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
        try container.encode(modifiers, forKey: .modifiers)
        try container.encode(nextEventAtGameSeconds, forKey: .nextEventAtGameSeconds)
        try container.encode(eventSeed, forKey: .eventSeed)
        try container.encode(marketShare, forKey: .marketShare)
        try container.encode(hasRoof, forKey: .hasRoof)
        try container.encode(managedSectors, forKey: .managedSectors)
        try container.encode(activeRules, forKey: .activeRules)
        try container.encode(autoResolvesEvents, forKey: .autoResolvesEvents)
        try container.encode(holdingPoints, forKey: .holdingPoints)
        try container.encode(cityNumber, forKey: .cityNumber)
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

    /// Satılmış katın saniyelik pasif geliri. 0 ise kat hâlâ senin işletmen.
    ///
    /// Satıştaki net üretimin bir oranıdır ve **satış anında donar** — kadro ve
    /// ekipman gittiği için yeniden hesaplanamaz. Rapor §5'in "binada kalıcı
    /// iz"i bu: sattığın şey yok olmaz, kira ödemeye devam eder. (şema 7)
    var investmentRate: Double

    var id: String { sectorID }

    private enum CodingKeys: String, CodingKey {
        case sectorID, staff, equipmentLevels, branchCount, investmentRate
    }

    init(
        sectorID: String,
        staff: [StaffMember] = [],
        equipmentLevels: [String: Int] = [:],
        branchCount: Int = 1,
        investmentRate: Double = 0
    ) {
        self.sectorID = sectorID
        self.staff = staff
        self.equipmentLevels = equipmentLevels
        self.branchCount = max(1, branchCount)
        self.investmentRate = max(0, investmentRate)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sectorID = try container.decodeIfPresent(String.self, forKey: .sectorID) ?? GameState.groundSectorID
        staff = try container.decodeIfPresent([StaffMember].self, forKey: .staff) ?? []
        equipmentLevels = try container.decodeIfPresent([String: Int].self, forKey: .equipmentLevels) ?? [:]
        branchCount = max(1, try container.decodeIfPresent(Int.self, forKey: .branchCount) ?? 1)
        investmentRate = max(0, try container.decodeIfPresent(Double.self, forKey: .investmentRate) ?? 0)
    }

    /// Bu kat satıldı mı? Yatırım katı üretir ama artık yönetilmez.
    var isInvestment: Bool { investmentRate > 0 }

    /// Bir ekipmanın sahip olunan seviyesi. Tanımadığımız kimlik 0'dır.
    func equipmentLevel(_ id: String) -> Int {
        max(0, equipmentLevels[id] ?? 0)
    }

    var isAutomated: Bool { !staff.isEmpty || isInvestment }
}

// MARK: - Olay etkisi

/// Süren bir olay etkisi. Bitiş anı oyun saniyesi cinsindendir; böylece
/// çevrimdışı geçen sürede de doğru anda sona erer.
struct ActiveModifier: Codable, Sendable, Equatable, Identifiable {

    /// Hangi olaydan ve hangi seçimden geldiği — metni buradan çözülür.
    var eventID: String
    var choiceID: String
    /// Üretim çarpanı.
    var multiplier: Double
    /// `elapsedGameSeconds` cinsinden bitiş anı.
    var endsAtGameSeconds: TimeInterval

    var id: String { "\(eventID).\(choiceID).\(endsAtGameSeconds)" }

    private enum CodingKeys: String, CodingKey {
        case eventID, choiceID, multiplier, endsAtGameSeconds
    }

    init(eventID: String, choiceID: String, multiplier: Double, endsAtGameSeconds: TimeInterval) {
        self.eventID = eventID
        self.choiceID = choiceID
        self.multiplier = multiplier
        self.endsAtGameSeconds = endsAtGameSeconds
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try container.decodeIfPresent(String.self, forKey: .eventID) ?? "unknown"
        choiceID = try container.decodeIfPresent(String.self, forKey: .choiceID) ?? "unknown"
        multiplier = try container.decodeIfPresent(Double.self, forKey: .multiplier) ?? 1
        endsAtGameSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .endsAtGameSeconds) ?? 0
    }
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

    /// Karara bağlanan olay sayısı. (şema 5)
    var eventsResolved: Int

    /// Müdürlerin yaptığı otomatik işlem sayısı. (şema 6)
    var automatedActions: Int

    /// Satılan sektör sayısı. Halka arzdan sonra da sayılmaya devam eder. (şema 7)
    var sectorsSold: Int

    /// Tamamlanıp halka arz edilen şehir sayısı.
    var citiesCompleted: Int

    /// Alınan isteğe bağlı ödül sayısı (çevrimdışı katlama, vardiya patlaması).
    var rewardsClaimed: Int

    private enum CodingKeys: String, CodingKey {
        case manualSales, offlineReturns, lastOfflineEarnings, wastedOfflineSeconds
        case eventsResolved, automatedActions, sectorsSold, citiesCompleted
        case rewardsClaimed
    }

    init(
        manualSales: Int = 0,
        offlineReturns: Int = 0,
        lastOfflineEarnings: Double = 0,
        wastedOfflineSeconds: TimeInterval = 0,
        eventsResolved: Int = 0,
        automatedActions: Int = 0,
        sectorsSold: Int = 0,
        citiesCompleted: Int = 0,
        rewardsClaimed: Int = 0
    ) {
        self.manualSales = manualSales
        self.offlineReturns = offlineReturns
        self.lastOfflineEarnings = lastOfflineEarnings
        self.wastedOfflineSeconds = wastedOfflineSeconds
        self.eventsResolved = eventsResolved
        self.automatedActions = automatedActions
        self.sectorsSold = sectorsSold
        self.citiesCompleted = citiesCompleted
        self.rewardsClaimed = rewardsClaimed
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manualSales = try container.decodeIfPresent(Int.self, forKey: .manualSales) ?? 0
        offlineReturns = try container.decodeIfPresent(Int.self, forKey: .offlineReturns) ?? 0
        lastOfflineEarnings = try container.decodeIfPresent(Double.self, forKey: .lastOfflineEarnings) ?? 0
        wastedOfflineSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .wastedOfflineSeconds) ?? 0
        eventsResolved = try container.decodeIfPresent(Int.self, forKey: .eventsResolved) ?? 0
        automatedActions = try container.decodeIfPresent(Int.self, forKey: .automatedActions) ?? 0
        sectorsSold = try container.decodeIfPresent(Int.self, forKey: .sectorsSold) ?? 0
        citiesCompleted = try container.decodeIfPresent(Int.self, forKey: .citiesCompleted) ?? 0
        rewardsClaimed = try container.decodeIfPresent(Int.self, forKey: .rewardsClaimed) ?? 0
    }
}
