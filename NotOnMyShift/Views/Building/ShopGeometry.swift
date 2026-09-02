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

    /// Tek hücrenin boyu.
    let size: CGSize

    /// Hücrenin kapsayıcı içindeki sol üst köşesi. Şubeler yan yana dizilirken
    /// her hücre aynı çizim koduna farklı bir başlangıç noktasıyla girer.
    var origin: CGPoint = .zero

    /// Kompozisyonun tasarlandığı en/boy oranı. Hücre bu oranda tutulur;
    /// asla gerilmez, gerekirse küçülür.
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

    func x(_ value: Double) -> CGFloat { origin.x + size.width * value }
    func y(_ value: Double) -> CGFloat { origin.y + size.height * value }
    /// Yarıçap ve yatay kalınlıklar genişliğe oranlanır. Uzunluk olduğu için
    /// başlangıç noktası katılmaz.
    func span(_ value: Double) -> CGFloat { size.width * value }

    /// Dikey uzunluk. Konum değil uzunluk olduğu için başlangıç noktası katılmaz.
    func height(_ value: Double) -> CGFloat { size.height * value }

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

/// Kat içindeki hücrelerin yerleşimi. Şubeler yan yana dizilir.
///
/// Hücre **asla gerilmez**: tasarım oranını korur, sığmıyorsa küçülür. Şerit
/// yatayda ortalanır ve zemine yaslanır; üstünde kalan boşluk binanın devamıdır
/// ve Faz 3'te kat olacak.
struct BranchStrip {

    let count: Int
    let available: CGSize

    /// Hücre bu genişlikten darsa ince ayrıntılar çizilmez.
    /// İki şubede hücre ~183pt olur ve tam detay hâlâ okunur; üçten sonra değil.
    static let compactWidth: CGFloat = 170
    /// Bir hücrede kaç figüre yer var — genişliğe göre.
    static let pointsPerFigure: CGFloat = 34

    var cellSize: CGSize {
        guard count > 0, available.width > 0, available.height > 0 else { return .zero }
        var width = available.width / CGFloat(count)
        var height = width / ShopGeometry.designAspectRatio
        if height > available.height {
            height = available.height
            width = height * ShopGeometry.designAspectRatio
        }
        return CGSize(width: width, height: height)
    }

    func origin(of index: Int) -> CGPoint {
        let cell = cellSize
        let stripWidth = cell.width * CGFloat(count)
        return CGPoint(
            x: (available.width - stripWidth) / 2 + cell.width * CGFloat(index),
            y: available.height - cell.height
        )
    }

    func geometry(of index: Int) -> ShopGeometry {
        ShopGeometry(size: cellSize, origin: origin(of: index))
    }

    var detail: ShopScene.Detail {
        cellSize.width >= Self.compactWidth ? .full : .compact
    }

    /// Dar hücrede altı figür lapaya döner; görünen sayıyı genişlik belirler.
    var visibleFigures: Int {
        max(1, Int(cellSize.width / Self.pointsPerFigure))
    }
}
