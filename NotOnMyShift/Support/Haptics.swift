import UIKit

/// Dokunsal geri bildirim.
///
/// Sadece kazanma, yükseltme, kat açma gibi anlarda. Her dokunuşta değil —
/// her dokunuşta titreyen oyun, titremenin değerini harcar.
@MainActor
enum Haptics {

    enum Kind {
        /// Küçük bir olumlama: elle satış.
        case light
        /// Karar anı: eleman tut, yükselt.
        case medium
        /// Başarı: kat açıldı, sektör satıldı.
        case success
        /// Olmadı: para yetmedi.
        case warning
    }

    static func play(_ kind: Kind) {
        switch kind {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
