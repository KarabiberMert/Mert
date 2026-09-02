import SwiftUI

/// Zemin kat paleti — esnaf katmanı.
///
/// Fikir şu: palet oyuncunun yükselişini anlatır. Aşağıda emaye tabela, çini
/// fayans ve boyalı duvar var; yukarı çıktıkça renkler soğuyacak, yüzeyler
/// camlaşacak. Üst kat paleti (cam grisi, beton) kat açma geldiğinde eklenecek.
/// Hardal vurgusu iki palette de aynı kalır — para hep aynı renk.
enum Palette {

    // MARK: - Ana beşli (docs/claude-code-prompt.md §5)

    /// Emaye mavi — tabela ve ana çerçeve.
    static let enamel = hex(0x1D5B79)
    /// Fıstık yeşili — fayans, ikincil yüzeyler.
    static let pistachio = hex(0x4C7A55)
    /// Hardal — vurgu, para, ödül anları.
    static let mustard = hex(0xD9A441)
    /// Boyalı duvar — arka plan.
    static let wall = hex(0xE9E4D6)
    /// Mürekkep — metin.
    static let ink = hex(0x23282B)

    // MARK: - Türetilenler

    /// Kesit kenarı, tabela gölgesi.
    static let enamelDeep = hex(0x144259)
    /// Koyu fıstık — ikinci önlük tonu.
    static let pistachioDeep = hex(0x3A5F41)
    /// Tezgâh gövdesi, çıta gölgesi.
    static let mustardDeep = hex(0xB0822C)
    /// İç duvar — boyalı duvardan bir ton açık.
    static let plaster = hex(0xF5F1E8)
    /// Zemin, kaldırım, kapı kanadı.
    static let stone = hex(0xE2DDCE)
    /// Fayans zemini.
    static let tileField = hex(0xF0EDE3)
    /// Ayırıcı çizgi, hafif gölge.
    static let shadow = hex(0xCBC4B4)
    /// Kara tahta.
    static let slate = hex(0x2E3432)
    /// Tebeşir yazısı.
    static let chalk = hex(0xCECABE)
    /// Fayans derz çizgisi.
    static let tileLine = hex(0xD8D2C3)
    /// Espresso makinesi gövdesi.
    static let steel = hex(0xCCCAC4)
    /// Makine grubu, koyu metal.
    static let steelDeep = hex(0x9C9A96)

    /// İkincil metin.
    static let inkSoft = hex(0x23282B).opacity(0.62)
    /// Üçüncül metin, ipucu.
    static let inkFaint = hex(0x23282B).opacity(0.42)

    /// Ten tonları — kadro tek tip görünmesin.
    static let skinTones: [Color] = [
        hex(0xDEB28D), hex(0xC49470), hex(0xEECDB0), hex(0xAC7C5C)
    ]

    private static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
