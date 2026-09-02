import Foundation

/// Oyunun tüm sayıları. Koda gömülmez, `Resources/balance.json` içinden okunur.
///
/// Kural: bir fiyatı değiştirmek için Swift dosyası açman gerekiyorsa yanlış yerdedir.
struct BalanceConfig: Codable, Sendable, Equatable {

    var version: Int
    var sector: Sector
    var manual: Manual
    var staff: Staff
    var warehouse: Warehouse
    var offline: Offline
    var staffPool: [StaffTemplate]

    // MARK: - Alt bölümler

    /// Faz 1'de tek sektör var: kahve arabası. Kat açma geldiğinde bu bir dizi olacak.
    ///
    /// Dükkânın adı burada değil: tabelada yazan metin dile göre değişir,
    /// dolayısıyla `Localizable.strings` içinde (`shop.name`).
    struct Sector: Codable, Sendable, Equatable {
        var id: String
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
        /// Kahve arabasına sığan eleman sayısı.
        var maxCount: Int
    }

    /// Depo = çevrimdışı kazanç kapasitesi.
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

    /// Havuzdaki eleman şablonu. İşe alım sırası bu dizinin sırasıdır —
    /// rastgelelik yok, böylece motor saf ve testler deterministik kalır.
    ///
    /// Kimlik huyu anlatır (`quick`, `veteran`), isim değil: isim ve huy metni
    /// dile göre değiştiği için `Localizable.strings` içinde durur. Kayıtta
    /// kimlik saklandığından oyuncu dili değiştirince kadro da yeni dilde görünür.
    struct StaffTemplate: Codable, Sendable, Equatable {
        var id: String
        var rateMultiplier: Double
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
