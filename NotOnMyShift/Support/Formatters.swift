import Foundation

/// Para biçimlendirme.
///
/// Para birimi **dile bağlı**: oyun İngilizce'de dolar, Türkçe'de lira,
/// İspanyolca'da euro kullanır. Simge, simgenin yeri, ondalık ayracı ve
/// büyüklük kısaltmaları da dilden gelir — hepsi `Localizable.strings`
/// içindeki `format.*` anahtarlarında.
///
/// `FormatStyle` değer tipidir ve `Sendable`'dır; `static let` olarak bir kez
/// kurulur, her çağrıda yeniden yaratılmaz.
enum Money {

    /// Bir dilin para gösterimi. Testler kendi biçimini verebilsin diye
    /// katalogdan ayrı bir değer tipi.
    struct Style: Sendable, Equatable {

        /// Ondalık ve binlik ayracı bu yerelden gelir.
        var numberLocale: Locale

        /// `{amount}` yer tutucusunu içeren kalıp: `${amount}` · `{amount} ₺`
        /// Simgeyi, yerini ve aradaki boşluğu tek başına belirler.
        var pattern: String

        /// Büyükten küçüğe: 10^15, 10^12, 10^9, 10^6, 10^3 kısaltmaları.
        var suffixes: [String]

        func render(_ body: String) -> String {
            pattern.replacingOccurrences(of: "{amount}", with: body)
        }

        static let placeholder = "{amount}"
    }

    /// Uygulamanın çalıştığı dilin para biçimi.
    static let current = Style(
        numberLocale: Locale(identifier: L.numberLocaleIdentifier),
        pattern: L.currencyPattern,
        suffixes: [L.scaleE15, L.scaleE12, L.scaleE9, L.scaleE6, L.scaleE3]
    )

    private static let thresholds: [Double] = [1e15, 1e12, 1e9, 1e6, 1e3]

    // MARK: - Dışarıya açık

    /// `$1.2K` · `1,2 B ₺` · `1,2 K €`
    static func text(_ value: Double, style: Style = current) -> String {
        guard value.isFinite else { return emptyValue }
        let body = number(abs(value), style: style)
        // İşaret kalıbın da dışına çıkar: `-$5`, `-5 ₺`.
        return (value < 0 ? "-" : "") + style.render(body)
    }

    /// Küçük ve ondalıklı değerler için: saniyelik gelir gibi.
    /// `text` 100'ün altını tam sayıya yuvarlar; oranda bu bilgi kaybı can sıkar
    /// (1,2/sn "1/sn" görünür).
    static func preciseText(_ value: Double, style: Style = current) -> String {
        guard value.isFinite else { return emptyValue }
        let magnitude = abs(value)
        guard magnitude < 100 else { return text(value, style: style) }
        let body = fraction(1, magnitude, locale: style.numberLocale)
        return (value < 0 ? "-" : "") + style.render(body)
    }

    /// Simgesiz, işaretsiz gövde. Simgeyi ayrı çizen yerler için.
    static func number(_ value: Double, style: Style = current) -> String {
        guard value.isFinite else { return emptyValue }
        let magnitude = abs(value)

        guard let index = thresholds.firstIndex(where: { magnitude >= $0 }) else {
            return fraction(0, magnitude.rounded(.towardZero), locale: style.numberLocale)
        }

        let scaled = magnitude / thresholds[index]
        let suffix = style.suffixes.indices.contains(index) ? style.suffixes[index] : ""
        // 100'ün altında bir hane ondalık; üstünde tam sayı. Genişlik böylece
        // sabit kalır, sayaç zıplamaz.
        let body = scaled < 100
            ? fraction(1, scaled, locale: style.numberLocale)
            : fraction(0, scaled.rounded(.towardZero), locale: style.numberLocale)
        return body + suffix
    }

    static let emptyValue = "—"

    // MARK: - İç

    private static func fraction(_ digits: Int, _ value: Double, locale: Locale) -> String {
        FloatingPointFormatStyle<Double>()
            .locale(locale)
            .precision(.fractionLength(digits))
            .grouping(.never)
            .format(value)
    }
}

/// Süre metni. Çoğul ekleri ve birim adları dile göre `Duration.UnitsFormatStyle`
/// tarafından çözülür — "2 hours", "2 saat", "2 horas" elle yazılmaz.
enum DurationText {

    private static let base = Duration.UnitsFormatStyle(
        allowedUnits: [.days, .hours, .minutes, .seconds],
        width: .wide,
        maximumUnitCount: 2,
        zeroValueUnits: .hide,
        fractionalPart: .hide
    )

    static func text(_ seconds: TimeInterval, locale: Locale = Money.current.numberLocale) -> String {
        guard seconds.isFinite, seconds >= 1 else { return L.durationNone }
        return Duration.seconds(seconds).formatted(base.locale(locale))
    }
}

/// Yüzde metni. Sayı yereli paranınkiyle aynı — ondalık ayracı bir ekranda
/// iki türlü görünmesin.
enum Percent {

    /// `0.3` → "30%". Oran değil pay yazdığımız için ondalık yok.
    static func text(_ fraction: Double, locale: Locale = Money.current.numberLocale) -> String {
        guard fraction.isFinite else { return "—" }
        let value = (fraction * 100).formatted(.number.locale(locale).precision(.fractionLength(0)))
        return "\(value)%"
    }
}
