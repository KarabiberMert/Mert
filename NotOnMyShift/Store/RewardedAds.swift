import Foundation
import Observation

/// Ödüllü reklam sınırı.
///
/// Bu sürümde üçüncü parti bir reklam SDK'sı yok (proje kuralı: sıfır
/// bağımlılık). Sınır yine de SDK biçiminde duruyor — yarın bir sağlayıcı
/// geldiğinde tek tip değişir, oyun kodu hiç değişmez.
///
/// Ödül **asla zorunlu değildir**: reklamı hiç izlemeyen oyuncu oyunu tam
/// oynar. Ödül yalnızca hızlandırır (rapor §8).
@MainActor
protocol RewardedAds: AnyObject {
    /// Gösterilecek bir şey var mı?
    var isReady: Bool { get }
    /// Sahneyi göster. Ödül hak edildiyse `true`.
    func present() async -> Bool
}

/// Oyunun kendi çizdiği "sponsor arası".
///
/// Gerçek bir reklam değil: kısa bir geri sayım ve bir tabela. Ödül gerçekten
/// verilir, böylece akış baştan sona test edilebilir. SDK gelince bu tip
/// silinir; `RewardedAds` sınırı yerinde kalır.
///
/// `present()` bir devamlılıkla bekler; sahneyi `AdBreakView` çizer ve
/// `finish(rewarded:)` ile sonucu bildirir. Bu iki üye protokolde değil:
/// bir SDK'nın böyle bir kancaya ihtiyacı olmaz.
@MainActor
@Observable
final class HouseAds: RewardedAds {

    /// Sahnenin süresi. Geri sayım bitmeden ödül verilmez.
    let seconds: TimeInterval

    private(set) var isPresenting = false
    @ObservationIgnored private var pending: CheckedContinuation<Bool, Never>?

    init(seconds: TimeInterval = 5) {
        self.seconds = max(1, seconds)
    }

    var isReady: Bool { !isPresenting }

    func present() async -> Bool {
        guard !isPresenting else { return false }
        return await withCheckedContinuation { continuation in
            pending = continuation
            isPresenting = true
        }
    }

    /// Sahne bitti. `rewarded` false ise oyuncu erken kapatmıştır.
    func finish(rewarded: Bool) {
        guard isPresenting else { return }
        isPresenting = false
        pending?.resume(returning: rewarded)
        pending = nil
    }
}

/// Reklam yokmuş gibi davranan sağlayıcı. Testler ve reklamsız oyuncu için.
@MainActor
final class NoAds: RewardedAds {
    var isReady: Bool { false }
    func present() async -> Bool { false }
}
