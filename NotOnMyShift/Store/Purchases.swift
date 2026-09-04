import Foundation
import Observation
import StoreKit

/// Satın alma sınırı.
///
/// Oyun kodu StoreKit'i bilmez; `hasRemovedAds` bayrağını ve iki eylemi bilir.
/// Testler ve önizlemeler `MemoryPurchases` ile çalışır, mağaza hesabı gerekmez.
@MainActor
protocol Purchases: AnyObject {
    /// "Reklamsız" alındı mı? Rapor §8: alan oyuncu ödülleri otomatik alır.
    var hasRemovedAds: Bool { get }
    /// Mağazadan gelen yerelleştirilmiş fiyat. Ürün okunamadıysa `nil`.
    var priceText: String? { get }
    /// Bir işlem sürüyor mu? Buton bu sırada beklesin.
    var isBusy: Bool { get }
    /// Son işlem başarısız olduysa oyuncuya gösterilecek kısa metin.
    var failureText: String? { get }

    /// Ürünü ve mevcut hakkı tazele. Açılışta çağrılır.
    func refresh() async
    /// Satın al.
    func buy() async
    /// Başka bir cihazda alınmışı geri yükle. App Review bunu şart koşar.
    func restore() async
}

/// StoreKit 2 ile gerçek satın alma.
///
/// Tek seferlik, tüketilmeyen bir ürün. Doğrulama Apple tarafında yapılır;
/// `VerificationResult` doğrulanmamış işlemi eler, biz kendi imza kontrolümüzü
/// yazmayız.
@MainActor
@Observable
final class StoreKitPurchases: Purchases {

    /// App Store Connect'teki ürün kimliği. Fiyat orada durur, kodda değil.
    static let removeAdsID = "com.karabibermert.notonmyshift.noads"

    private(set) var hasRemovedAds = false
    private(set) var isBusy = false
    private(set) var failureText: String?

    @ObservationIgnored private var product: Product?
    @ObservationIgnored private var updates: Task<Void, Never>?

    private(set) var priceText: String?

    init() {
        // İşlem başka bir cihazda ya da mağaza uygulamasında tamamlanabilir.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.apply(update)
            }
        }
    }

    deinit {
        updates?.cancel()
    }

    func refresh() async {
        failureText = nil
        do {
            let products = try await Product.products(for: [Self.removeAdsID])
            product = products.first
            priceText = products.first?.displayPrice
        } catch {
            // Ağ yoksa fiyat görünmez ama oyun çalışmaya devam eder.
            priceText = nil
        }
        await refreshEntitlement()
    }

    func buy() async {
        guard !isBusy, let product else { return }
        isBusy = true
        failureText = nil
        defer { isBusy = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await apply(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            failureText = L.purchaseFailed
        }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true
        failureText = nil
        defer { isBusy = false }

        do {
            try await AppStore.sync()
        } catch {
            failureText = L.purchaseFailed
        }
        await refreshEntitlement()
    }

    private func refreshEntitlement() async {
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.removeAdsID, transaction.revocationDate == nil {
                hasRemovedAds = true
                return
            }
        }
        hasRemovedAds = false
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.removeAdsID {
            hasRemovedAds = transaction.revocationDate == nil
        }
        await transaction.finish()
    }
}

/// Testlerin ve önizlemelerin kullandığı sahte mağaza. Ağ yok, hesap yok.
@MainActor
@Observable
final class MemoryPurchases: Purchases {

    private(set) var hasRemovedAds: Bool
    private(set) var isBusy = false
    private(set) var failureText: String?
    var priceText: String?
    /// `buy()` başarısız olsun mu? Hata yolunu test etmek için.
    var failsToBuy = false

    init(hasRemovedAds: Bool = false, priceText: String? = "$2.99") {
        self.hasRemovedAds = hasRemovedAds
        self.priceText = priceText
    }

    func refresh() async {}

    func buy() async {
        failureText = nil
        if failsToBuy {
            failureText = L.purchaseFailed
            return
        }
        hasRemovedAds = true
    }

    func restore() async {
        failureText = nil
    }
}
