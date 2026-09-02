import CoreGraphics
import XCTest
@testable import NotOnMyShift

/// Bina çizimini gözle doğrulayamıyoruz, ama yerleşim matematiği saf ve
/// test edilebilir. Buradaki testler kadronun tezgâhtan taşmamasını güvenceye alır.
final class ShopGeometryTests: XCTestCase {

    private let geometry = ShopGeometry(size: CGSize(width: 390, height: 430))

    func testNormalizedCoordinatesMapToPoints() {
        XCTAssertEqual(geometry.x(0.5), 195, accuracy: 0.001)
        XCTAssertEqual(geometry.y(0.5), 215, accuracy: 0.001)
        // Yarıçaplar genişliğe oranlanır, yoksa daireler yamulur.
        XCTAssertEqual(geometry.span(0.1), 39, accuracy: 0.001)

        let rect = geometry.rect(0.25, 0.5, 0.75, 1.0)
        XCTAssertEqual(rect.minX, 97.5, accuracy: 0.001)
        XCTAssertEqual(rect.width, 195, accuracy: 0.001)
        XCTAssertEqual(rect.height, 215, accuracy: 0.001)
    }

    func testCrewAlwaysFitsBehindTheCounter() {
        for count in 1...6 {
            let scale = ShopGeometry.slotScale(count: count)
            let halfWidth = ShopGeometry.figureWidth * scale / 2

            for index in 0..<count {
                let center = ShopGeometry.slotCenter(index: index, count: count)
                XCTAssertGreaterThan(
                    center - halfWidth, ShopGeometry.counterLeft,
                    "\(count) kişilik kadroda \(index). eleman tezgâhın solundan taşıyor"
                )
                XCTAssertLessThan(
                    center + halfWidth, ShopGeometry.counterRight,
                    "\(count) kişilik kadroda \(index). eleman tezgâhın sağından taşıyor"
                )
            }
        }
    }

    func testCrewIsEvenlySpaced() {
        let centers = (0..<4).map { ShopGeometry.slotCenter(index: $0, count: 4) }
        let gaps = zip(centers, centers.dropFirst()).map { $1 - $0 }
        for gap in gaps {
            XCTAssertEqual(gap, gaps[0], accuracy: 1e-9)
        }
        XCTAssertTrue(centers.sorted() == centers, "Yuvalar soldan sağa sıralı olmalı")
    }

    func testCrowdedCrewShrinks() {
        XCTAssertEqual(ShopGeometry.slotScale(count: 1), 1.0, accuracy: 1e-9)
        XCTAssertLessThan(ShopGeometry.slotScale(count: 6), ShopGeometry.slotScale(count: 2))
    }

    func testOwnerStandsClearOfTheDoorAndTheCounter() {
        let halfWidth = ShopGeometry.figureWidth * 0.92 / 2
        XCTAssertGreaterThan(ShopGeometry.ownerStandingX - halfWidth, ShopGeometry.counterRight)
        XCTAssertLessThan(ShopGeometry.ownerStandingX + halfWidth, ShopGeometry.doorLeft)
    }

    func testLayersAreStackedInTheRightOrder() {
        XCTAssertLessThan(ShopGeometry.signBottom, ShopGeometry.awningTop, "Tente tabelanın yazısını kesmemeli")
        XCTAssertLessThan(ShopGeometry.awningBottom, ShopGeometry.interiorTop)
        XCTAssertLessThan(ShopGeometry.tileBottom, ShopGeometry.floorY)
        XCTAssertEqual(ShopGeometry.tileBottom, ShopGeometry.counterTop, accuracy: 1e-9,
                       "Fayans şeridi tezgâh tablasında bitsin")
        XCTAssertLessThan(ShopGeometry.floorY, ShopGeometry.interiorBottom)
        XCTAssertLessThan(ShopGeometry.interiorBottom, ShopGeometry.shellBottom)
    }
}
