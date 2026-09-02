import Foundation

/// Ekranda görünen tüm metinler tek yerde.
///
/// Türkçe birincil dil; İngilizce sonra `en.lproj` eklenerek gelecek.
/// `defaultValue` verildiği için sözlük bulunamasa bile metin doğru görünür.
enum L {

    // Kasa
    static var cash: String {
        String(localized: "cash.label", defaultValue: "Kasa", comment: "Para sayacının başlığı")
    }
    static var perSecond: String {
        String(localized: "cash.perSecond", defaultValue: "saniyede", comment: "Pasif gelir birimi")
    }
    static var workingByHand: String {
        String(localized: "cash.byHand", defaultValue: "Şimdilik her kahveyi sen yapıyorsun.", comment: "Çağ 0 açıklaması")
    }

    // Eylemler
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
        String(localized: "action.staffFull", defaultValue: "Arabaya daha fazla eleman sığmıyor", comment: "Kadro dolu")
    }
    static var warehouseMaxed: String {
        String(localized: "action.warehouseMaxed", defaultValue: "Depo son seviyede", comment: "Depo tam")
    }

    // Kadro
    static var crew: String {
        String(localized: "crew.title", defaultValue: "Kadro", comment: "Eleman listesi başlığı")
    }
    static var crewEmpty: String {
        String(localized: "crew.empty", defaultValue: "Henüz kimse yok. İlk elemanı tuttuğunda iş sensiz de yürümeye başlar.", comment: "Boş kadro daveti")
    }

    // Depo
    static var warehouse: String {
        String(localized: "warehouse.title", defaultValue: "Depo", comment: "Depo bölümü başlığı")
    }
    static var warehouseExplainer: String {
        String(localized: "warehouse.explainer", defaultValue: "Sen yokken bu kadar süre üretim birikir.", comment: "Depo kapasitesi açıklaması")
    }

    // Dönüş özeti
    static var welcomeBack: String {
        String(localized: "offline.title", defaultValue: "Dönmüşsün", comment: "Çevrimdışı özet başlığı")
    }
    static var warehouseFull: String {
        String(localized: "offline.full", defaultValue: "Depo doldu, ürünler bekliyor. Büyütürsen daha uzun süre çalışır.", comment: "Kapasite taştı")
    }
    static var continueAction: String {
        String(localized: "offline.continue", defaultValue: "Devam", comment: "Özeti kapat")
    }

    // Motor / tanılama
    static var engine: String {
        String(localized: "engine.title", defaultValue: "Motor", comment: "Faz 0 tanılama bölümü")
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

    // Uyarılar
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
}
