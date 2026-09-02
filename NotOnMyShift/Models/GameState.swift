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

    static let currentSchemaVersion = 2

    /// Kaydın hangi şema sürümüyle yazıldığı.
    var schemaVersion: Int

    /// Oyuncunun seçtiği karakter. Faz 0'da tek seçenek var.
    var characterID: String

    /// Kasadaki para.
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

    /// İşe alınmış kadro. Sıra, `balance.json` içindeki havuz sırasıdır.
    var staff: [StaffMember]

    /// Depo (çevrimdışı kapasite) seviyesi. `balance.json` içindeki dizinin indeksi.
    var warehouseLevel: Int

    /// Çağ 0 → Çağ 1 geçişi kutlandı mı? Bu an bir kez yaşanır. (şema 2)
    var hasCelebratedFirstHire: Bool

    var stats: Stats

    // MARK: - Yeni oyun

    /// Sıfırdan bir oyun durumu. Saati dışarıdan alır ki motor tarafı saf kalsın.
    static func newGame(characterID: String, now: Date) -> GameState {
        GameState(
            schemaVersion: currentSchemaVersion,
            characterID: characterID,
            money: 0,
            lifetimeEarnings: 0,
            elapsedGameSeconds: 0,
            lastSeenAt: now,
            startedAt: now,
            staff: [],
            warehouseLevel: 0,
            hasCelebratedFirstHire: false,
            stats: Stats()
        )
    }

    // MARK: - Türetilmiş

    /// İş kendi kendine yürüyor mu? (Çağ 0 → Çağ 1 geçişi)
    var isAutomated: Bool { !staff.isEmpty }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, characterID, money, lifetimeEarnings
        case elapsedGameSeconds, lastSeenAt, startedAt, staff, warehouseLevel, stats
        case hasCelebratedFirstHire
    }

    init(
        schemaVersion: Int,
        characterID: String,
        money: Double,
        lifetimeEarnings: Double,
        elapsedGameSeconds: TimeInterval,
        lastSeenAt: Date,
        startedAt: Date,
        staff: [StaffMember],
        warehouseLevel: Int,
        hasCelebratedFirstHire: Bool,
        stats: Stats
    ) {
        self.schemaVersion = schemaVersion
        self.characterID = characterID
        self.money = money
        self.lifetimeEarnings = lifetimeEarnings
        self.elapsedGameSeconds = elapsedGameSeconds
        self.lastSeenAt = lastSeenAt
        self.startedAt = startedAt
        self.staff = staff
        self.warehouseLevel = warehouseLevel
        self.hasCelebratedFirstHire = hasCelebratedFirstHire
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
        staff = try container.decodeIfPresent([StaffMember].self, forKey: .staff) ?? []
        warehouseLevel = try container.decodeIfPresent(Int.self, forKey: .warehouseLevel) ?? 0
        // Şema 1 kayıtlarında bu alan yok. Zaten eleman tutmuşsa kutlamayı
        // tekrar göstermeyelim — o an bir kez yaşanır.
        hasCelebratedFirstHire = try container.decodeIfPresent(Bool.self, forKey: .hasCelebratedFirstHire)
            ?? !staff.isEmpty
        stats = try container.decodeIfPresent(Stats.self, forKey: .stats) ?? Stats()
    }
}

// MARK: - Kadro

/// Kadrodaki bir eleman. Faz 0'da sadece hız çarpanı iş görür;
/// isim ve huy Faz 1'in tonunu şimdiden taşısın diye burada.
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
