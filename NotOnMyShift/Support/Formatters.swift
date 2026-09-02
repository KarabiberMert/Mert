import Foundation

/// Para ve süre biçimlendirme.
///
/// `FormatStyle` değer tipidir ve `Sendable`'dır; `static let` olarak bir kez
/// kurulur, her çağrıda yeniden yaratılmaz. (Kural: formatter'ı her çağrıda
/// yaratma. `NumberFormatter` yerine `FormatStyle` seçildi çünkü sınıf değil,
/// dolayısıyla Swift 6 strict concurrency altında paylaşımı sorunsuz.)
enum Money {

    /// Oyun Türkçe; sayı biçimi cihaz diline değil oyuna bağlı.
    static let locale = Locale(identifier: "tr_TR")

    static let symbol = "₺"

    private static let oneFraction = FloatingPointFormatStyle<Double>()
        .locale(locale)
        .precision(.fractionLength(1))
        .grouping(.never)

    private static let noFraction = FloatingPointFormatStyle<Double>()
        .locale(locale)
        .precision(.fractionLength(0))
        .grouping(.never)

    private struct Scale: Sendable {
        var threshold: Double
        var suffix: String
    }

    /// Büyükten küçüğe. İlk eşiği geçen kısaltma kullanılır.
    private static let scales: [Scale] = [
        Scale(threshold: 1e15, suffix: "Kt"),   // katrilyon
        Scale(threshold: 1e12, suffix: "Tn"),   // trilyon
        Scale(threshold: 1e9,  suffix: "Mr"),   // milyar
        Scale(threshold: 1e6,  suffix: "Mn"),   // milyon
        Scale(threshold: 1e3,  suffix: "B")     // bin
    ]

    /// `1,2 B ₺` · `3,4 Mn ₺` · `847 ₺`
    static func text(_ value: Double) -> String {
        "\(number(value)) \(symbol)"
    }

    /// Küçük ve ondalıklı değerler için: saniyelik gelir gibi.
    /// `text` 100'ün altını tam sayıya yuvarlar; oranda bu bilgi kaybı can sıkar
    /// (1,2 ₺/sn "1 ₺/sn" görünür).
    static func preciseText(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        guard abs(value) < 100 else { return text(value) }
        return "\(oneFraction.format(value)) \(symbol)"
    }

    /// Simgesiz hâli. Rozet, sayaç gibi yerlerde simge ayrı çiziliyorsa.
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let magnitude = abs(value)

        guard let scale = scales.first(where: { magnitude >= $0.threshold }) else {
            return noFraction.format(value.rounded(.towardZero))
        }

        let scaled = value / scale.threshold
        // 100'ün altında bir hane ondalık; üstünde tam sayı. Genişlik böylece
        // sabit kalır, sayaç zıplamaz.
        let body = abs(scaled) < 100
            ? oneFraction.format(scaled)
            : noFraction.format(scaled.rounded(.towardZero))
        return "\(body) \(scale.suffix)"
    }
}

/// Süreyi Türkçe, konuşma diliyle yazar: `3 saat 12 dakika`.
enum DurationText {

    static func text(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0 dakika" }

        let total = Int(seconds.rounded())
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "\(days) gün \(hours) saat" : "\(days) gün"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours) saat \(minutes) dakika" : "\(hours) saat"
        }
        if minutes > 0 {
            return "\(minutes) dakika"
        }
        return "\(total) saniye"
    }
}
