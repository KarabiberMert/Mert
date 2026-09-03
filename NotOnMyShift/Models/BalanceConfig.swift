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
