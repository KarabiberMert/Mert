import CoreGraphics

/// Zemin katın kesit çiziminin ölçüleri.
///
/// Tüm sabitler 0..1 normalize; böylece her ekran boyutunda aynı kompozisyon
/// çıkıyor ve Canvas ile üstüne yerleşen figür görünümleri aynı koordinat
/// uzayını paylaşıyor.
///
/// Y ölçüleri yüksekliğe, X ölçüleri genişliğe oranlanır. Yarıçaplar genişliğe
/// oranlanır ki dairesel şeyler yüksekliğe göre yamulmasın.
struct ShopGeometry {

    let size: CGSize

    /// Kompozisyonun tasarlandığı en/boy oranı. Sahne bu oranda tutulur;
    /// yoksa uzun ekranlarda bina dikey olarak gerilir.
    static let designAspectRatio: CGFloat = 390.0 / 430.0

    // MARK: - Dikey katmanlar

    static let shellTop = 0.045
    static let shellBottom = 0.900
    static let shellLeft = 0.035
    static let shellRight = 0.965

    static let signTop = 0.070
    static let signBottom = 0.152

    static let awningTop = 0.192
    static let awningBottom = 0.248
    static let awningLeft = 0.062
    static let awningRight = 0.938
    static let awningStripes = 9

    static let interiorTop = 0.262
    static let interiorBottom = 0.845
    static let interiorLeft = 0.070
    static let interiorRight = 0.930

    static let shelfY = 0.398
    static let boardTop = 0.300
    static let boardBottom = 0.428

    static let tileTop = 0.540
    static let tileBottom = 0.660
    static let tileColumns = 12
    static let tileRows = 2

    static let counterLeft = 0.088
    static let counterRight = 0.630
    static let counterTop = 0.660
    static let floorY = 0.800

    static let doorLeft = 0.800
    static let doorRight = 0.928
    static let doorTop = 0.430

    // MARK: - Figür yerleşimi

    /// Tezgâhın arkasındaki kadro bu aralığa dizilir.
    static let slotLeft = 0.125
    static let slotRight = 0.500
    /// Patron eleman tuttuktan sonra buraya çekilir, iş yürürken izler.
    static let ownerStandingX = 0.750
    /// Patron tek başına çalışırken tezgâhtaki yeri.
    static let ownerWorkingX = 0.230

    /// Figürün taban ölçüleri (ölçek 1.0 için).
    static let figureWidth = 0.080
    static let figureHeight = 0.300
    static let figureHeadRadius = 0.032

    // MARK: - Dönüşümler

    func x(_ value: Double) -> CGFloat { size.width * value }
    func y(_ value: Double) -> CGFloat { size.height * value }
    /// Yarıçap ve kalınlıklar genişliğe oranlanır.
    func span(_ value: Double) -> CGFloat { size.width * value }

    func point(_ px: Double, _ py: Double) -> CGPoint {
        CGPoint(x: x(px), y: y(py))
    }

    func rect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> CGRect {
        CGRect(x: x(x0), y: y(y0), width: x(x1) - x(x0), height: y(y1) - y(y0))
    }

    // MARK: - Kadro yerleşimi

    /// `count` kişilik kadronun `index`inci üyesinin yatay merkezi.
    static func slotCenter(index: Int, count: Int) -> Double {
        guard count > 0 else { return (slotLeft + slotRight) / 2 }
        let step = (slotRight - slotLeft) / Double(count)
        return slotLeft + step * (Double(index) + 0.5)
    }

    /// Kalabalıklaşınca figürler biraz küçülür, omuz omuza sığsınlar.
    static func slotScale(count: Int) -> Double {
        switch count {
        case ...3: 1.0
        case 4...5: 0.90
        default: 0.82
        }
    }
}
