import CoreGraphics

/// Bir kat bandının ölçüleri.
///
/// Bina kat kat yükseldiği için kat artık kare bir dükkân cephesi değil, **geniş
/// ve alçak bir bant**. Bandın yapısı (döşeme, duvar, fayans, zemin) tüm genişlik
/// boyunca sürer; şubeler bandı dikey bölmelerle hücrelere ayırır — "kat içindeki
/// hücreler" tam olarak bu.
///
/// Tüm sabitler 0..1 normalize. Dikey ölçüler banttan, yatay ölçüler hücreden
/// gelir; böylece hücre daralınca insanlar ve tezgâh kısalmaz, sadece incelir.
struct FloorGeometry {

    let rect: CGRect

    // MARK: - Dikey katmanlar (bandın kendisi)

    /// Üstteki kat döşemesi. Zemin katta yerini tenteye bırakır.
    static let slabTop = 0.0
    static let slabBottom = 0.085
    /// Zemin katın tentesi döşemenin yerine geçer, fistolarıyla biraz daha iner.
    static let awningBottom = 0.150
    static let awningStripes = 9

    static let signTop = 0.170
    static let signBottom = 0.310

    static let tileTop = 0.355
    static let tileBottom = 0.620
    static let tileRows = 1

    static let counterTop = 0.620
    static let counterSlabBottom = 0.690
    static let floorY = 0.915
    static let bandBottom = 1.0

    static let interiorLeft = 0.018
    static let interiorRight = 0.982

    // MARK: - Figür (bandın yüksekliğine oranlı)

    /// Gövde yüksekliği — bandın yüksekliğine oranlı, hücre genişliğine değil.
    /// Ayaklar zeminde, baş tezgâh tablasının biraz üstünde kalacak kadar:
    /// daha uzunu tabelayı eziyor, daha kısası tezgâhın arkasında kayboluyor.
    static let figureBodyHeight = 0.335
    /// Gövde genişliği, gövde yüksekliğine oranlı.
    static let figureWidthRatio = 0.34
    static let figureHeadRatio = 0.115

    // MARK: - Dönüşümler

    func x(_ value: Double) -> CGFloat { rect.minX + rect.width * value }
    func y(_ value: Double) -> CGFloat { rect.minY + rect.height * value }
    /// Yatay uzunluk.
    func w(_ value: Double) -> CGFloat { rect.width * value }
    /// Dikey uzunluk. Yarıçaplar da buna oranlanır — bant alçaldıkça her şey birlikte küçülür.
    func h(_ value: Double) -> CGFloat { rect.height * value }

    func point(_ px: Double, _ py: Double) -> CGPoint { CGPoint(x: x(px), y: y(py)) }

    func box(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> CGRect {
        CGRect(x: x(x0), y: y(y0), width: w(x1 - x0), height: h(y1 - y0))
    }

    // MARK: - Hücreler (şubeler)

    /// `count` hücrenin `index`incisi. Dikey ölçüler banttan devralınır.
    func unit(_ index: Int, of count: Int) -> UnitGeometry {
        let total = max(1, count)
        let left = x(Self.interiorLeft)
        let span = w(Self.interiorRight - Self.interiorLeft)
        let width = span / CGFloat(total)
        return UnitGeometry(band: self, minX: left + width * CGFloat(min(max(index, 0), total - 1)), width: width)
    }

    /// Hücre bu genişlikten darsa ince ayrıntılar çizilmez.
    static let compactUnitWidth: CGFloat = 130
    /// Bir hücreye kaç figür sığar.
    static let pointsPerFigure: CGFloat = 26

    func detail(unitCount: Int) -> FloorDetail {
        unit(0, of: unitCount).width >= Self.compactUnitWidth ? .full : .compact
    }

    func visibleFigures(unitCount: Int) -> Int {
        max(1, Int(unit(0, of: unitCount).width / Self.pointsPerFigure) - 1)
    }
}

/// Kat içindeki tek hücre: bir şube. Dikey ölçüleri banttan alır.
struct UnitGeometry {

    let band: FloorGeometry
    let minX: CGFloat
    let width: CGFloat

    // Hücre içi yatay ölçüler
    static let counterLeft = 0.07
    static let counterRight = 0.78
    static let fittingLeft = 0.80
    static let fittingRight = 0.98
    static let slotLeft = 0.11
    static let slotRight = 0.72

    func x(_ value: Double) -> CGFloat { minX + width * value }
    func y(_ value: Double) -> CGFloat { band.y(value) }
    func w(_ value: Double) -> CGFloat { width * value }
    func h(_ value: Double) -> CGFloat { band.h(value) }

    func point(_ px: Double, _ py: Double) -> CGPoint { CGPoint(x: x(px), y: y(py)) }

    func box(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> CGRect {
        CGRect(x: x(x0), y: y(y0), width: w(x1 - x0), height: h(y1 - y0))
    }

    /// `count` kişilik kadronun `index`incisinin yatay merkezi.
    static func slotCenter(index: Int, count: Int) -> Double {
        guard count > 0 else { return (slotLeft + slotRight) / 2 }
        let step = (slotRight - slotLeft) / Double(count)
        return slotLeft + step * (Double(index) + 0.5)
    }
}

/// Hücre daraldıkça ince ayrıntılar (fayans motifi, tabela yazısı, raf) atlanır.
enum FloorDetail: Sendable, Equatable {
    case full
    case compact

    var showsFineDetail: Bool { self == .full }
}

/// Binadaki katların dikey yerleşimi.
///
/// Zemin kat daha yüksektir: tentesi, kaldırımı ve sokağa bakan yüzü var.
/// Katlar aşağıdan yukarı dizilir; bina yükseldikçe bantlar incelir.
/// Satılmış katın ölçüleri. Bandın kendi kutusuna göre 0..1.
///
/// Kat aynı bant, sadece tezgâhın yerinde kepenk var. Bu yüzden kendi
/// katman sırası yok — yalnızca kepenk dokusu ve kapı levhası.
enum InvestmentGeometry {

    /// İnik kepenk. Dikey olarak tezgâhın ve fayansın yerini alır, yanlardan
    /// içeri girer — duvara boyanmış değil, açıklığa inmiş görünsün.
    static let shutterLeft = 0.060
    static let shutterRight = 0.940
    static let shutterTop = FloorGeometry.tileTop
    static let shutterBottom = FloorGeometry.counterSlabBottom
    /// Kepenkteki lama sayısı. Bant alçalınca aralık küçülür, sayı değil.
    static let shutterSlats = 7

    /// Kapı levhası. Kepenkin altındaki duvar şeridinde, zeminin üstünde.
    static let plaqueLeft = 0.060
    static let plaqueRight = 0.260
    static let plaqueTop = 0.730
    static let plaqueBottom = 0.870
}

/// Çatıdaki yönetim katı.
///
/// Sektör katı değil: kadrosu, tezgâhı, hücresi yok — bu yüzden kendi ölçü
/// takımı var. Normal bir banttan alçaktır; binanın üstüne oturan bir ofis
/// kutusu gibi okunur. Tüm sabitler bandın kendi kutusuna göre 0..1.
enum RoofGeometry {

    /// Normal bir kat bandına göre yükseklik oranı.
    static let scale: CGFloat = 0.62

    /// Saçak — binanın tepesini kapatan ince silme.
    static let capTop = 0.0
    static let capBottom = 0.14

    /// Ofis camı. Kapı levhasının sağında durur, üstüne binmez.
    static let glassTop = 0.30
    static let glassBottom = 0.74
    static let glassLeft = 0.46
    static let glassRight = 0.94
    static let panes = 6

    /// Kapı levhası. Tabela gibi büyük harf taşır — arayüz değil, binanın parçası.
    static let plateTop = 0.32
    static let plateBottom = 0.62
    static let plateLeft = 0.06
    static let plateRight = 0.40

    /// Bandın oturduğu döşeme.
    static let baseTop = 0.86
    static let baseBottom = 1.0

    static let interiorLeft = 0.018
    static let interiorRight = 0.982
}

struct BuildingLayout {

    let floorCount: Int
    let available: CGSize
    /// Çatı katı açıldı mı. Açıldıysa bina bir bant daha taşır.
    var hasRoof: Bool = false

    /// Zemin katın diğerlerine göre yükseklik oranı.
    static let groundFloorScale: CGFloat = 1.35
    /// Kaldırım payı.
    static let pavement: CGFloat = 0.055
    /// Bandın altına düşemeyeceği yükseklik — bundan alçak bant okunmaz olur.
    static let minimumBandHeight: CGFloat = 74

    private var units: CGFloat {
        CGFloat(max(0, floorCount - 1)) + Self.groundFloorScale + (hasRoof ? RoofGeometry.scale : 0)
    }

    /// Normal bir katın yüksekliği.
    var bandHeight: CGFloat {
        guard floorCount > 0, units > 0 else { return 0 }
        let usable = available.height * (1 - Self.pavement)
        return max(0, usable / units)
    }

    func height(of index: Int) -> CGFloat {
        index == 0 ? bandHeight * Self.groundFloorScale : bandHeight
    }

    /// `index`inci katın kutusu. Zemin kat en altta.
    func frame(of index: Int) -> CGRect {
        guard floorCount > 0 else { return .zero }
        let pavementHeight = available.height * Self.pavement
        var bottom = available.height - pavementHeight
        for lower in 0..<min(index, floorCount) {
            bottom -= height(of: lower)
        }
        let bandHeight = height(of: index)
        return CGRect(x: 0, y: bottom - bandHeight, width: available.width, height: bandHeight)
    }

    /// Çatı katının kutusu. Kat yoksa ya da çatı açılmadıysa yok.
    var roofFrame: CGRect? {
        guard hasRoof, floorCount > 0 else { return nil }
        let top = frame(of: floorCount - 1)
        let height = bandHeight * RoofGeometry.scale
        return CGRect(x: 0, y: top.minY - height, width: available.width, height: height)
    }

    /// Binanın tamamı — kaldırım ve çatı dahil.
    var buildingFrame: CGRect {
        guard floorCount > 0 else { return .zero }
        let top = roofFrame?.minY ?? frame(of: floorCount - 1).minY
        return CGRect(x: 0, y: top, width: available.width, height: available.height - top)
    }

    var pavementFrame: CGRect {
        let height = available.height * Self.pavement
        return CGRect(x: 0, y: available.height - height, width: available.width, height: height)
    }

    /// Bina bu yükseklikte okunaklı mı? Değilse üst katlar kırpılmalı (Faz 4+).
    var isLegible: Bool { bandHeight >= Self.minimumBandHeight }
}
