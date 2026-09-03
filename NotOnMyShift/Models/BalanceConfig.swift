import Foundation

/// Oyunun tüm sayıları. Koda gömülmez, `Resources/balance.json` içinden okunur.
///
/// Kural: bir fiyatı değiştirmek için Swift dosyası açman gerekiyorsa yanlış yerdedir.
/// Bu dosya **sadece sayı ve kimlik** tutar; ekranda görünen her metin dile
/// bağlı olduğu için `Localizable.strings` içindedir.
struct BalanceConfig: Codable, Sendable, Equatable {

    var version: Int
    var building: Building
    /// Katların sırası. Sıfırıncı sektör zemin kattır ve baştan açıktır.
    var sectors: [SectorSpec]
    var warehouse: Warehouse
    var offline: Offline
    var events: Events
    var market: Market
    var process: Process
    var prestige: Prestige

    // MARK: - Bina

    struct Building: Codable, Sendable, Equatable {
        /// Paletin tamamen kurumsala döndüğü kat sayısı. Bina bundan alçak olsa
        /// bile üst katlar oransal olarak soğur — geçiş sert olmasın diye.
        var paletteFloors: Int
    }

    // MARK: - Sektör

    /// Bir kat = bir sektör. Kat açmak sektöre girmektir.
    ///
    /// Adı, elemanlarının isimleri ve ekipmanının adları dil dosyalarındadır;
    /// burada yalnızca kimlikler ve sayılar durur.
    struct SectorSpec: Codable, Sendable, Equatable, Identifiable {
        var id: String
        /// Bu katı açmanın ücreti. Zemin katta 0.
        var unlockCost: Double
        var manual: Manual
        var staff: Staff
        var equipment: [EquipmentSpec]
        var branches: Branches
        var staffPool: [StaffTemplate]
    }

    /// Çağ 0: elle üretip satma.
    struct Manual: Codable, Sendable, Equatable {
        /// Bir dokunuşun getirisi.
        var revenuePerSale: Double
    }

    /// Çağ 1: eleman.
    struct Staff: Codable, Sendable, Equatable {
        /// Tek elemanın saniyelik taban getirisi. Elemanın kendi çarpanıyla çarpılır.
        var ratePerSecond: Double
        /// İlk elemanın ücreti.
        var baseCost: Double
        /// Her elemanda ücretin çarpanı. `cost(n) = baseCost * costGrowth^n`
        var costGrowth: Double
        /// Bu kata sığan eleman sayısı.
        var maxCount: Int
        /// Elemanın saniyelik maaşı. Brüt üretimden düşer ve ekipman yatırımını
        /// gerçek bir seçim hâline getirir: makine bir kez ödenir, maaş her saniye.
        var wagePerSecond: Double
    }

    /// Çağ 2: ekipman. Her parça kendi seviye izini yürütür; seviyelerin
    /// çarpanları birbiriyle çarpılarak katın üretim çarpanını verir.
    ///
    /// Ekipman maaş ödemez — eleman ödediği için, ekipman yatırımı zamanla
    /// eleman almaya baskın gelir. Tasarım raporundaki seçim buradan doğuyor.
    struct EquipmentSpec: Codable, Sendable, Equatable, Identifiable {
        /// Adı ve açıklaması dil dosyalarında (`equipment.<id>.name`).
        var id: String
        var levels: [Level]

        struct Level: Codable, Sendable, Equatable {
            /// Bu seviyeye çıkmanın ücreti. İlk seviyede 0 (baştan sahipsin).
            var cost: Double
            /// Katın üretim çarpanına katkısı.
            var multiplier: Double
        }
    }

    /// Şubeler: kat içindeki hücreler. Yeni şube mevcut kadro ve ekipmanı
    /// devralır — tek tuş kopyalama, ayrı ayarı yok.
    struct Branches: Codable, Sendable, Equatable {
        /// İkinci şubenin ücreti.
        var baseCost: Double
        /// `cost(n) = baseCost * costGrowth^(n-1)` — n açılacak şubenin sırası.
        var costGrowth: Double
        /// Bir kata sığan hücre sayısı.
        var maxCount: Int
    }

    /// Havuzdaki eleman şablonu. İşe alım sırası bu dizinin sırasıdır —
    /// rastgelelik yok, böylece motor saf ve testler deterministik kalır.
    ///
    /// Kimlik huyu anlatır (`quick`, `veteran`), isim değil: isim ve huy metni
    /// dile göre değiştiği için `Localizable.strings` içinde durur. Kayıtta
    /// kimlik saklandığından oyuncu dili değiştirince kadro da yeni dilde görünür.
    struct StaffTemplate: Codable, Sendable, Equatable, Identifiable {
        var id: String
        var rateMultiplier: Double
    }

    // MARK: - Genel (kata bağlı değil)

    /// Depo = çevrimdışı kazanç kapasitesi. Oyuncunun kendi kapasitesidir,
    /// katlara bölünmez.
    struct Warehouse: Codable, Sendable, Equatable {
        var levels: [Level]

        struct Level: Codable, Sendable, Equatable {
            /// Bu seviyede kaç saniyelik çevrimdışı üretim saklanabilir.
            var capacitySeconds: TimeInterval
            /// Bu seviyeye çıkmanın ücreti. İlk seviyede 0.
            var cost: Double
        }
    }

    struct Offline: Codable, Sendable, Equatable {
        /// Bu süreden kısa ayrılıklarda dönüş özeti gösterilmez.
        /// Uygulama değiştirici / bildirim merkezi gibi anlık kesintiler için.
        var minimumReportSeconds: TimeInterval
    }

    // MARK: - Olaylar

    /// Kısa seansa yakıt: günde birkaç kez, seansta en fazla bir kez bir karar.
    /// Her olay bir ya da iki dokunuşluk bir seçim sunar.
    struct Events: Codable, Sendable, Equatable {
        /// İlk olay bu kadar oyun saniyesinden önce çıkmaz — oyuncu önce
        /// Çağ 0'ı geçsin.
        var firstAfterSeconds: TimeInterval
        /// Olaylar arası ortalama oyun süresi.
        var gapSeconds: TimeInterval
        /// Aralığa eklenen rastgelelik payı (0..1). 0,4 → ±%40.
        var gapJitter: Double
        var specs: [EventSpec]

        func spec(id: String) -> EventSpec? { specs.first { $0.id == id } }
    }

    struct EventSpec: Codable, Sendable, Equatable, Identifiable {
        var id: String
        /// Ağırlıklı seçimde payı.
        var weight: Double
        /// Bir ya da iki seçenek. Metinleri dil dosyalarında.
        var choices: [EventChoice]
    }

    struct EventChoice: Codable, Sendable, Equatable, Identifiable {
        var id: String
        /// Üretim çarpanı. 1,0 etkisiz.
        var multiplier: Double
        /// Çarpanın süresi (oyun saniyesi). 0 ise çarpan uygulanmaz.
        var durationSeconds: TimeInterval
        /// Anında kasaya giren/çıkan: **mevcut saniyelik netin kaç saniyesi**
        /// kadar. Oransal olduğu için her sektörde ve her çağda anlamlı kalır.
        /// Negatif değer giderdir; kasa asla eksiye düşmez.
        var instantSeconds: Double
    }

    // MARK: - Pazar

    /// Rakipler. Tasarım raporunun cezalandırmama kuralı (§6) burada yaşıyor:
    /// **rakip oyuncunun mevcut gelirini asla düşürmez.** Sadece açılabilecek
    /// yeni şube sayısını kısar. Açılmış şube hiçbir zaman kapanmaz.
    struct Market: Codable, Sendable, Equatable {
        /// Oyuncunun başlangıç payı.
        var startShare: Double
        /// Payın inebileceği taban. Buranın altına düşmez.
        var minimumShare: Double
        /// Oyun saniyesi başına rakiplere kayan pay.
        var driftPerSecond: Double
        /// Her yatırımın geri kazandırdığı pay.
        var sharePerPurchase: Double
        var competitors: [CompetitorSpec]
    }

    struct CompetitorSpec: Codable, Sendable, Equatable, Identifiable {
        var id: String
        /// Kalan payın bu rakibe düşen ağırlığı.
        var weight: Double
    }

    // MARK: - Süreç katmanı

    /// Çağ 3: çatı katındaki yönetim ofisi.
    ///
    /// Tasarım raporunun en kritik denge kararı (§4) burada yaşıyor:
    /// **derinlik ceza kaçınma değil, ödüldür.** Süreç kurmayan oyuncu tam
    /// verimle çalışmaya devam eder — hiçbir şey eksilmez. Süreç kuran oyuncu
    /// üstüne bonus alır ve daha az dokunur. Tersi (kural kurmayan cezalanır)
    /// kısa seans hedefini öldürür.
    struct Process: Codable, Sendable, Equatable {
        /// Çatı katını açmanın ücreti.
        var roofCost: Double
        /// İlk müdürün ücreti.
        var managerBaseCost: Double
        /// Her müdürde ücretin çarpanı.
        var managerCostGrowth: Double
        /// Açık her kuralın kata kattığı verim.
        var bonusPerRule: Double
        /// Verim bonusunun tavanı. Rapor %30 diyor.
        var maxBonus: Double
        /// Otomatik alımların kasada bırakacağı yedek: mevcut netin kaç saniyesi.
        /// Müdür oyuncunun biriktirdiği parayı süpürmesin.
        var reserveSeconds: Double
        /// Bir dönüşte müdürün yapabileceği en fazla işlem. Döngü sınırlı kalsın.
        var maxActionsPerVisit: Int
        /// Kural şablonları. Kural yazma değil hazır tarif — mobilde kural
        /// editörü hızla fazla teknik hâle gelir (rapor §10.5).
        var rules: [RuleSpec]

        func rule(id: String) -> RuleSpec? { rules.first { $0.id == id } }
    }

    struct RuleSpec: Codable, Sendable, Equatable, Identifiable {
        /// `hire` · `equip` · `branch` — motor bu kimliğe göre davranır.
        var id: String
    }

    // MARK: - Yumuşak prestij

    /// Olgunlaşan sektörü satmanın karşılığı (rapor §5).
    ///
    /// Satış üç şey verir: büyük nakit, kalıcı holding puanı ve binada kalıcı
    /// bir iz — satılan kat yatırım katına dönüşüp küçük bir pasif gelir
    /// üretmeye devam eder. Üçüncüsü olmadan oyuncu satmaya direnir.
    struct Prestige: Codable, Sendable, Equatable {
        /// Satış bedeli: katın kaç saniyelik neti.
        var payoutSeconds: Double
        /// Yatırım katının koruduğu oran — satıştan önceki netin kaçta kaçı.
        var investmentShare: Double
        /// Her satışın kazandırdığı holding puanı.
        var pointsPerSale: Int
        /// Halka arzın kazandırdığı holding puanı — yeni şehir hızlanır.
        var pointsPerCity: Int
        /// Her puanın brüte kattığı oran. Kalıcıdır, hiç geri alınmaz.
        var multiplierPerPoint: Double
    }

    // MARK: - Arama

    func sector(id: String) -> SectorSpec? {
        sectors.first { $0.id == id }
    }

    func sector(at index: Int) -> SectorSpec? {
        sectors.indices.contains(index) ? sectors[index] : nil
    }

    // MARK: - Yükleme

    enum LoadError: Error, CustomStringConvertible {
        case resourceMissing(String)
        case decodingFailed(String)

        var description: String {
            switch self {
            case .resourceMissing(let name):
                "balance dosyası pakette yok: \(name)"
            case .decodingFailed(let reason):
                "balance dosyası okunamadı: \(reason)"
            }
        }
    }

    /// Paketten `balance.json` okur.
    static func load(named name: String = "balance", in bundle: Bundle = .main) throws -> BalanceConfig {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw LoadError.resourceMissing("\(name).json")
        }
        return try load(contentsOf: url)
    }

    static func load(contentsOf url: URL) throws -> BalanceConfig {
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(BalanceConfig.self, from: data)
        } catch {
            throw LoadError.decodingFailed(String(describing: error))
        }
    }
}
