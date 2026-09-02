import SwiftUI

/// Zemin kat paleti — esnaf katmanı.
///
/// Fikir şu: palet oyuncunun yükselişini anlatır. Aşağıda emaye tabela ve çini
/// fayans var; yukarı çıktıkça renkler soğur, yüzeyler camlaşır. Üst kat paleti
/// (cam grisi, beton) kat açma geldiğinde eklenecek. Hardal vurgusu iki palette
/// de aynı kalır — para hep aynı renk.
enum Palette {

    /// Emaye mavi — tabela ve ana çerçeve.
    static let enamel = Color(red: 0.114, green: 0.357, blue: 0.475)      // #1D5B79
    /// Fıstık yeşili — fayans, ikincil yüzeyler.
    static let pistachio = Color(red: 0.298, green: 0.478, blue: 0.333)   // #4C7A55
    /// Hardal — vurgu, para, ödül anları.
    static let mustard = Color(red: 0.851, green: 0.643, blue: 0.255)     // #D9A441
    /// Boyalı duvar — arka plan.
    static let wall = Color(red: 0.914, green: 0.894, blue: 0.839)        // #E9E4D6
    /// Mürekkep — metin.
    static let ink = Color(red: 0.137, green: 0.157, blue: 0.169)         // #23282B

    /// Mürekkebin soluk hâli — ikincil metin.
    static let inkSoft = Color(red: 0.137, green: 0.157, blue: 0.169).opacity(0.6)
}
