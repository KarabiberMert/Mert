import CoreText
import SwiftUI
import UIKit

/// İki aile: başlıklar ve rakamlar için sıkışık bir grotesk (Archivo Condensed),
/// gövde metni ve arayüz için sistem fontu.
///
/// Archivo değişken fontundan iki kesit üretildi (`scripts/build_fonts.py`);
/// ikisi de `ığüşöçİĞÜŞÖÇ` ve `₺` gliflerini eksiksiz taşıyor ve `tnum`
/// tabular figür özelliğine sahip.
///
/// Font pakete girmemişse sistem fontunun sıkışık genişliğine düşüyoruz:
/// ekran bozulmuyor, sadece karakteri azalıyor.
enum Typography {

    private static let displayName = "ArchivoCond-SemiBold"
    private static let labelName = "ArchivoCond-Medium"

    /// Özel fontlar kayıtlı mı? Bir kez ölçülür.
    static let hasCustomFonts: Bool =
        UIFont(name: displayName, size: 12) != nil && UIFont(name: labelName, size: 12) != nil

    // MARK: - Dışarıya açık yüzler

    /// Başlıklar, tabela, büyük anlar.
    static func display(_ size: CGFloat) -> Font {
        font(displayName, size: size, fallbackWeight: .semibold, tabular: false)
    }

    /// Para ve süre sayaçları. Rakamlar sabit genişlikte — sayaç zıplamaz.
    static func money(_ size: CGFloat) -> Font {
        font(displayName, size: size, fallbackWeight: .semibold, tabular: true)
    }

    /// İkincil etiketler, rozetler, küçük sayılar.
    static func label(_ size: CGFloat) -> Font {
        font(labelName, size: size, fallbackWeight: .medium, tabular: true)
    }

    /// Çizimin içindeki yazı: tabela, kapı levhası.
    /// Bunlar mimarinin parçası, arayüz değil — Dynamic Type ile büyümezler,
    /// yoksa tabela kendi çerçevesinden taşar.
    static func signage(_ size: CGFloat) -> Font {
        font(displayName, size: size, fallbackWeight: .semibold, tabular: false, scaled: false)
    }

    // MARK: - Kurulum

    private static func font(
        _ name: String,
        size: CGFloat,
        fallbackWeight: UIFont.Weight,
        tabular: Bool,
        scaled: Bool = true
    ) -> Font {
        let base: UIFont
        if let custom = UIFont(name: name, size: size) {
            base = custom
        } else {
            base = UIFont.systemFont(ofSize: size, weight: fallbackWeight, width: .condensed)
        }

        let shaped = tabular ? tabularFigures(base) : base
        guard scaled else { return Font(shaped as CTFont) }

        // Dynamic Type'a uy ama başlıkları düzeni bozacak kadar büyütme.
        let metric = UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: shaped, maximumPointSize: size * 1.35)

        return Font(metric as CTFont)
    }

    /// OpenType `tnum`. `monospacedDigit()` sadece sistem fontunda çalışır,
    /// özel fontta özelliği elle açmak gerekiyor.
    private static func tabularFigures(_ font: UIFont) -> UIFont {
        let feature: [UIFontDescriptor.FeatureKey: Int] = [
            .type: Int(kNumberSpacingType),
            .selector: Int(kMonospacedNumbersSelector)
        ]
        let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: [feature]])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
