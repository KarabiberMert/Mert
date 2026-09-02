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

    // MARK: - Şube şeridi

    private let phone = CGSize(width: 366, height: 330)

    func testCellsNeverDistort() {
        // Hücre gerilirse dükkân yamulur. Sığmıyorsa küçülmeli, esnememeli.
        for count in 1...4 {
            let strip = BranchStrip(count: count, available: phone)
            let cell = strip.cellSize
            XCTAssertEqual(
                cell.width / cell.height, ShopGeometry.designAspectRatio, accuracy: 1e-6,
                "\(count) şubede hücre oranı bozuldu"
            )
        }
    }

    func testStripFitsInsideTheAvailableBox() {
        for count in 1...4 {
            let strip = BranchStrip(count: count, available: phone)
            let cell = strip.cellSize
            XCTAssertLessThanOrEqual(cell.width * CGFloat(count), phone.width + 0.001)
            XCTAssertLessThanOrEqual(cell.height, phone.height + 0.001)

            let first = strip.origin(of: 0)
            let last = strip.origin(of: count - 1)
            XCTAssertGreaterThanOrEqual(first.x, -0.001)
            XCTAssertLessThanOrEqual(last.x + cell.width, phone.width + 0.001)
        }
    }

    func testStripIsCentredAndSitsOnTheGround() {
        let strip = BranchStrip(count: 2, available: phone)
        let cell = strip.cellSize

        // Zemine yaslı: üstünde kalan boşluk binanın devamı, Faz 3'te kat olacak.
        XCTAssertEqual(strip.origin(of: 0).y, phone.height - cell.height, accuracy: 1e-6)
        XCTAssertEqual(strip.origin(of: 1).y, strip.origin(of: 0).y, accuracy: 1e-6)

        let leftGap = strip.origin(of: 0).x
        let rightGap = phone.width - (strip.origin(of: 1).x + cell.width)
        XCTAssertEqual(leftGap, rightGap, accuracy: 1e-6, "Şerit yatayda ortalanmalı")
    }

    func testCellsSitSideBySideWithoutOverlap() {
        let strip = BranchStrip(count: 4, available: phone)
        let cell = strip.cellSize
        for index in 1..<4 {
            XCTAssertEqual(
                strip.origin(of: index).x - strip.origin(of: index - 1).x,
                cell.width, accuracy: 1e-6
            )
        }
    }

    func testNarrowCellsDropFineDetailAndCrowd() {
        XCTAssertEqual(BranchStrip(count: 1, available: phone).detail, .full)
        XCTAssertEqual(BranchStrip(count: 4, available: phone).detail, .compact)

        let single = BranchStrip(count: 1, available: phone)
        let crowded = BranchStrip(count: 4, available: phone)
        XCTAssertGreaterThan(single.visibleFigures, crowded.visibleFigures)
        XCTAssertGreaterThanOrEqual(crowded.visibleFigures, 1, "Her hücrede en az bir kişi görünmeli")
    }

    func testDegenerateSizesDoNotCrash() {
        XCTAssertEqual(BranchStrip(count: 0, available: phone).cellSize, .zero)
        XCTAssertEqual(BranchStrip(count: 2, available: .zero).cellSize, .zero)
        XCTAssertGreaterThanOrEqual(BranchStrip(count: 2, available: .zero).visibleFigures, 1)
    }

    func testGeometryOfACellIsOffsetButKeepsItsScale() {
        let strip = BranchStrip(count: 2, available: phone)
        let first = strip.geometry(of: 0)
        let second = strip.geometry(of: 1)

        // Konumlar kayar…
        XCTAssertEqual(second.x(0.5) - first.x(0.5), strip.cellSize.width, accuracy: 1e-6)
        // …ama uzunluklar aynı kalır.
        XCTAssertEqual(first.span(0.1), second.span(0.1), accuracy: 1e-9)
        XCTAssertEqual(first.height(0.1), second.height(0.1), accuracy: 1e-9)
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
