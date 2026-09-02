import Foundation

/// Ekranda görünen tüm metinler tek yerde.
///
/// Türkçe birincil dil; İngilizce sonra `en.lproj` eklenerek gelecek.
/// `defaultValue` verildiği için sözlük bulunamasa bile metin doğru görünür.
///
/// Dil: sen-dili, sade fiiller. Buton ne yapacağını söyler.
/// Boş ekran davet eder, özür dilemez.
enum L {

    // MARK: - Kasa

    static var cash: String {
        String(localized: "cash.label", defaultValue: "Kasa", comment: "Para sayacının başlığı")
    }
    static var workingByHand: String {
        String(localized: "cash.byHand", defaultValue: "Şimdilik her kahveyi sen yapıyorsun.", comment: "Çağ 0 açıklaması")
    }
    /// "saniyede 1,4 ₺"
    static func perSecond(_ amount: String) -> String {
        String(localized: "cash.perSecond", defaultValue: "saniyede \(amount)", comment: "Pasif gelir satırı")
    }

    // MARK: - Eylemler

    static var sellCoffee: String {
        String(localized: "action.sell", defaultValue: "Kahve sat", comment: "Elle üretim butonu")
    }
    static var hireStaff: String {
        String(localized: "action.hire", defaultValue: "Eleman tut", comment: "Eleman alma butonu")
    }
    static var upgradeWarehouse: String {
        String(localized: "action.upgradeWarehouse", defaultValue: "Depoyu büyüt", comment: "Çevrimdışı kapasite yükseltmesi")
    }
    static var staffFull: String {
        String(localized: "action.staffFull", defaultValue: "Arabaya daha fazla eleman sığmıyor.", comment: "Kadro dolu")
    }
    static var warehouseMaxed: String {
        String(localized: "action.warehouseMaxed", defaultValue: "Depo son seviyede.", comment: "Depo tam")
    }
    /// "38 kahve daha"
    static func coffeesToGo(_ count: Int) -> String {
        String(localized: "action.coffeesToGo", defaultValue: "\(count) kahve daha", comment: "Sonraki alıma kalan elle satış")
    }

    // MARK: - Dükkân

    static var open: String {
        String(localized: "shop.open", defaultValue: "AÇIK", comment: "Kapıdaki levha")
    }
    static var tapToSell: String {
        String(localized: "shop.tapHint", defaultValue: "Tezgâha dokun, kahveyi sat.", comment: "Çağ 0 ipucu")
    }
    static var shopAccessibility: String {
        String(localized: "shop.a11y", defaultValue: "Dükkân. Dokununca bir kahve satarsın.", comment: "Bina için erişilebilirlik etiketi")
    }

    // MARK: - Kadro

    static var crew: String {
        String(localized: "crew.title", defaultValue: "Kadro", comment: "Eleman listesi başlığı")
    }

    // MARK: - Depo

    static var warehouse: String {
        String(localized: "warehouse.title", defaultValue: "Depo", comment: "Depo bölümü başlığı")
    }
    /// "Sen yokken 2 saatlik üretim birikir."
    static func warehouseHolds(_ duration: String) -> String {
        String(localized: "warehouse.holds", defaultValue: "Sen yokken \(duration)lik üretim birikir.", comment: "Depo kapasitesi açıklaması")
    }

    // MARK: - Çağ 1 anı

    /// "Sevim Abla işe başladı"
    static func startedWork(_ name: String) -> String {
        String(localized: "firstHire.title", defaultValue: "\(name) işe başladı", comment: "İlk eleman kutlaması başlığı")
    }
    static var firstHireBody: String {
        String(localized: "firstHire.body", defaultValue: "Artık sen yokken de kahve satılıyor. Uygulamayı kapatsan bile depo dolmaya devam eder.", comment: "Çevrimdışı kazancın açıldığı an")
    }
    static var firstHireAction: String {
        String(localized: "firstHire.action", defaultValue: "Güzel", comment: "Kutlamayı kapat")
    }

    // MARK: - Dönüş özeti

    static var welcomeBack: String {
        String(localized: "offline.title", defaultValue: "Dönmüşsün", comment: "Çevrimdışı özet başlığı")
    }
    /// "3 saat 12 dakika uzaktaydın."
    static func youWereAway(_ duration: String) -> String {
        String(localized: "offline.away", defaultValue: "\(duration) uzaktaydın.", comment: "Uzakta geçen süre")
    }
    static var warehouseFilled: String {
        String(localized: "offline.full", defaultValue: "Depo doldu, ürünler bekliyor. Büyütürsen daha uzun süre çalışır.", comment: "Kapasite taştı")
    }
    static var continueAction: String {
        String(localized: "offline.continue", defaultValue: "Devam", comment: "Özeti kapat")
    }

    // MARK: - Uyarılar

    static var notEnoughMoney: String {
        String(localized: "error.funds", defaultValue: "Para yetmiyor", comment: "Yetersiz bakiye")
    }
    static var saveRecovered: String {
        String(localized: "save.recovered", defaultValue: "Kayıt bozulmuştu, yedekten geri alındı.", comment: "Yedekten kurtarma")
    }
    static var saveFailed: String {
        String(localized: "save.failed", defaultValue: "Kayıt yazılamadı. Cihazda yer olduğundan emin ol.", comment: "Kayıt hatası")
    }
    static var bootFailed: String {
        String(localized: "boot.failed", defaultValue: "Oyun açılamadı", comment: "Başlatma hatası başlığı")
    }

    // MARK: - Geliştirme (yalnızca DEBUG)

    static var engine: String {
        String(localized: "engine.title", defaultValue: "Motor", comment: "Tanılama bölümü")
    }
    static var totalPlayed: String {
        String(localized: "engine.played", defaultValue: "İşlenen süre", comment: "Toplam ilerletilen saniye")
    }
    static var manualSales: String {
        String(localized: "engine.manualSales", defaultValue: "Elle satış", comment: "Elle satış sayısı")
    }
    static var lifetime: String {
        String(localized: "engine.lifetime", defaultValue: "Toplam kazanç", comment: "Ömür boyu kazanç")
    }
    static var startOver: String {
        String(localized: "engine.startOver", defaultValue: "Baştan başla", comment: "Kaydı sil")
    }
}
