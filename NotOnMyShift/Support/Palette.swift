import SwiftUI

/// Renk tonu. Katlar arası geçiş sayısal karışım gerektirdiği için renkleri
/// bileşenleriyle tutuyoruz; `Color` bunlardan türetiliyor.
struct Tone: Sendable, Equatable {

    var red: Double
    var green: Double
    var blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// İki ton arasında doğrusal karışım. `amount` 0 → kendisi, 1 → hedef.
    func blended(to other: Tone, _ amount: Double) -> Tone {
        let t = min(max(amount, 0), 1)
        return Tone(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    func color(opacity: Double) -> Color { color.opacity(opacity) }
}

/// Palet oyuncunun yükselişini anlatır: zemin katta el boyası esnaf estetiği,
/// yukarı çıktıkça soğuyan ve camlaşan kurumsal katman.
///
/// Hardal vurgusu iki katmanda da aynı kalır — para hep aynı renk.
enum Palette {

    // MARK: - Zemin kat (esnaf katmanı)

    static let enamelTone = Tone(0x1D5B79)
    static let pistachioTone = Tone(0x4C7A55)
    static let mustardTone = Tone(0xD9A441)
    static let wallTone = Tone(0xE9E4D6)
    static let inkTone = Tone(0x23282B)

    static let enamelDeepTone = Tone(0x144259)
    static let pistachioDeepTone = Tone(0x3A5F41)
    static let mustardDeepTone = Tone(0xB0822C)
    static let plasterTone = Tone(0xF5F1E8)
    static let stoneTone = Tone(0xE2DDCE)
    static let tileFieldTone = Tone(0xF0EDE3)
    static let tileLineTone = Tone(0xD8D2C3)
    static let shadowTone = Tone(0xCBC4B4)
    static let slateTone = Tone(0x2E3432)
    static let chalkTone = Tone(0xCECABE)
    static let steelTone = Tone(0xCCCAC4)
    static let steelDeepTone = Tone(0x9C9A96)

    // MARK: - Üst katlar (kurumsal katman)

    /// Cam gri.
    static let glassTone = Tone(0x8FA3B0)
    /// Beton.
    static let concreteTone = Tone(0x52616B)
    /// Camlaşmış duvar — sıvanın soğuk karşılığı.
    static let glassWallTone = Tone(0xDCE4E8)
    /// Soğuk zemin.
    static let coldStoneTone = Tone(0xD3DADE)

    // MARK: - Kullanıma hazır renkler

    static let enamel = enamelTone.color
    static let enamelDeep = enamelDeepTone.color
    static let pistachio = pistachioTone.color
    static let pistachioDeep = pistachioDeepTone.color
    /// Vurgu, para, ödül anları. Katlar boyunca değişmez.
    static let mustard = mustardTone.color
    static let mustardDeep = mustardDeepTone.color
    static let wall = wallTone.color
    static let ink = inkTone.color
    static let plaster = plasterTone.color
    static let stone = stoneTone.color
    static let shadow = shadowTone.color
    static let slate = slateTone.color
    static let chalk = chalkTone.color
    static let steel = steelTone.color
    static let steelDeep = steelDeepTone.color

    /// İkincil metin.
    static let inkSoft = inkTone.color(opacity: 0.62)
    /// Üçüncül metin, ipucu.
    static let inkFaint = inkTone.color(opacity: 0.42)

    /// Ten tonları — kadro tek tip görünmesin.
    static let skinTones: [Color] = [
        Tone(0xDEB28D).color, Tone(0xC49470).color, Tone(0xEECDB0).color, Tone(0xAC7C5C).color
    ]
}

/// Bir katın renkleri. Kat yükseldikçe esnaf katmanından kurumsal katmana
/// karışır — oyuncu kat değiştirdiğinde bunu kimse söylemeden hisseder.
struct FloorPalette: Sendable, Equatable {

    /// 0 → tamamen esnaf, 1 → tamamen kurumsal.
    let coolness: Double

    /// - Parameters:
    ///   - index: Katın sıra numarası, zemin kat 0.
    ///   - plannedFloors: Binanın planlanan kat sayısı. Bina bundan alçak olsa
    ///     bile geçiş oransal kalır; iki katlık binada ikinci kat hafifçe soğur.
    init(floor index: Int, plannedFloors: Int) {
        let top = Double(max(1, plannedFloors - 1))
        coolness = min(max(Double(index) / top, 0), 1)
    }

    private func mix(_ warm: Tone, _ cool: Tone) -> Color {
        warm.blended(to: cool, coolness).color
    }

    /// Kesit kenarı, kat döşemesi.
    var frame: Color { mix(Palette.enamelTone, Palette.concreteTone) }
    var frameDeep: Color { mix(Palette.enamelDeepTone, Palette.concreteTone.blended(to: Tone(0x36434B), 0.6)) }
    /// İç duvar.
    var wall: Color { mix(Palette.plasterTone, Palette.glassWallTone) }
    /// Fayans zemini.
    var tileField: Color { mix(Palette.tileFieldTone, Palette.glassWallTone) }
    var tileLine: Color { mix(Palette.tileLineTone, Palette.glassTone.blended(to: Palette.glassWallTone, 0.5)) }
    /// Fayans motifi ve şerit kenarı.
    var tileMotif: Color { mix(Palette.enamelTone, Palette.concreteTone) }
    var tileEdge: Color { mix(Palette.pistachioTone, Palette.glassTone) }
    /// Tezgâh gövdesi.
    var counter: Color { mix(Palette.mustardTone, Palette.glassTone) }
    var counterShade: Color { mix(Palette.mustardDeepTone, Palette.concreteTone.blended(to: Palette.glassTone, 0.4)) }
    /// Tezgâh tablası.
    var counterTop: Color { mix(Palette.enamelTone, Palette.concreteTone) }
    /// Zemin.
    var ground: Color { mix(Palette.stoneTone, Palette.coldStoneTone) }
    /// Demirbaşların gövdesi.
    var fixture: Color { mix(Palette.steelTone, Palette.glassWallTone) }
    var fixtureDeep: Color { mix(Palette.steelDeepTone, Palette.glassTone) }
    /// Önlük tonları — kadro tek tip görünmesin, ama kat da kendini belli etsin.
    var apron: Color { mix(Palette.pistachioTone, Palette.glassTone) }
    var apronAlt: Color { mix(Palette.pistachioDeepTone, Palette.concreteTone) }
    /// Patronun önlüğü. Hardal her katta aynı.
    var ownerApron: Color { Palette.mustard }
    /// Tabela zemini.
    var sign: Color { mix(Palette.enamelTone, Palette.concreteTone) }
    var signText: Color { mix(Palette.plasterTone, Palette.glassWallTone) }
}
