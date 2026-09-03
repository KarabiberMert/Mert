import CoreGraphics
import XCTest
@testable import NotOnMyShift

/// Bina çizimini gözle doğrulayamıyoruz, ama yerleşim matematiği saf ve
/// test edilebilir. Buradaki testler katların üst üste binmemesini, hücrelerin
/// tezgâhtan taşmamasını ve katmanların doğru sırada olmasını güvenceye alır.
final class FloorGeometryTests: XCTestCase {

    private let band = FloorGeometry(rect: CGRect(x: 20, y: 100, width: 360, height: 140))

    // MARK: - Bant

    func testNormalizedCoordinatesRespectTheBandOrigin() {
        XCTAssertEqual(band.x(0), 20, accuracy: 1e-6)
        XCTAssertEqual(band.x(1), 380, accuracy: 1e-6)
        XCTAssertEqual(band.y(0), 100, accuracy: 1e-6)
        XCTAssertEqual(band.y(1), 240, accuracy: 1e-6)
        // Uzunluklar konum değil: başlangıç noktası katılmaz.
        XCTAssertEqual(band.w(0.5), 180, accuracy: 1e-6)
        XCTAssertEqual(band.h(0.5), 70, accuracy: 1e-6)

        let box = band.box(0.25, 0.5, 0.75, 1.0)
        XCTAssertEqual(box.minX, 110, accuracy: 1e-6)
        XCTAssertEqual(box.minY, 170, accuracy: 1e-6)
        XCTAssertEqual(box.width, 180, accuracy: 1e-6)
        XCTAssertEqual(box.height, 70, accuracy: 1e-6)
    }

    func testLayersAreStackedInTheRightOrder() {
        XCTAssertLessThan(FloorGeometry.slabBottom, FloorGeometry.awningBottom, "Tente döşemenin altına iner")
        XCTAssertLessThan(FloorGeometry.awningBottom, FloorGeometry.signTop, "Tente tabelayı kesmemeli")
        XCTAssertLessThan(FloorGeometry.signBottom, FloorGeometry.tileTop)
        XCTAssertLessThan(FloorGeometry.tileBottom, FloorGeometry.floorY)
        XCTAssertEqual(FloorGeometry.tileBottom, FloorGeometry.counterTop, accuracy: 1e-9,
                       "Fayans şeridi tezgâh tablasında bitsin")
        XCTAssertLessThan(FloorGeometry.counterTop, FloorGeometry.counterSlabBottom)
        XCTAssertLessThan(FloorGeometry.counterSlabBottom, FloorGeometry.floorY)
        XCTAssertLessThan(FloorGeometry.floorY, FloorGeometry.bandBottom)
    }

    // MARK: - Hücreler (şubeler)

    func testUnitsDivideTheInteriorWithoutOverlap() {
        for count in 1...4 {
            let units = (0..<count).map { band.unit($0, of: count) }
            let width = units[0].width

            XCTAssertEqual(units[0].minX, band.x(FloorGeometry.interiorLeft), accuracy: 1e-6)
            XCTAssertEqual(
                units[count - 1].minX + width, band.x(FloorGeometry.interiorRight), accuracy: 1e-6,
                "\\(count) hücre iç genişliği tam doldurmalı"
            )
            for index in 1..<count {
                XCTAssertEqual(units[index].minX - units[index - 1].minX, width, accuracy: 1e-6)
            }
        }
    }

    func testUnitsInheritVerticalMeasuresFromTheBand() {
        // Hücre daralınca insanlar ve tezgâh kısalmaz, sadece incelir.
        let single = band.unit(0, of: 1)
        let crowded = band.unit(2, of: 4)

        XCTAssertEqual(single.y(FloorGeometry.floorY), crowded.y(FloorGeometry.floorY), accuracy: 1e-9)
        XCTAssertEqual(single.h(0.3), crowded.h(0.3), accuracy: 1e-9)
        XCTAssertGreaterThan(single.width, crowded.width)
    }

    func testCrewFitsBehindTheCounter() {
        for count in 1...6 {
            for index in 0..<count {
                let center = UnitGeometry.slotCenter(index: index, count: count)
                XCTAssertGreaterThan(center, UnitGeometry.counterLeft,
                                     "\\(count) kişide \\(index). eleman tezgâhın solundan taşıyor")
                XCTAssertLessThan(center, UnitGeometry.counterRight,
                                  "\\(count) kişide \\(index). eleman tezgâhın sağından taşıyor")
            }
        }
    }

    func testCrewIsEvenlySpaced() {
        let centers = (0..<4).map { UnitGeometry.slotCenter(index: $0, count: 4) }
        let gaps = zip(centers, centers.dropFirst()).map { $1 - $0 }
        for gap in gaps {
            XCTAssertEqual(gap, gaps[0], accuracy: 1e-9)
        }
        XCTAssertEqual(centers.sorted(), centers, "Yuvalar soldan sağa sıralı olmalı")
    }

    func testNarrowUnitsDropFineDetailAndCrowd() {
        XCTAssertEqual(band.detail(unitCount: 1), .full)
        XCTAssertEqual(band.detail(unitCount: 4), .compact)
        XCTAssertGreaterThan(band.visibleFigures(unitCount: 1), band.visibleFigures(unitCount: 4))
        XCTAssertGreaterThanOrEqual(band.visibleFigures(unitCount: 4), 1, "Her hücrede en az bir kişi görünmeli")
    }

    func testFittingSitsClearOfTheCounter() {
        XCTAssertLessThan(UnitGeometry.counterRight, UnitGeometry.fittingLeft)
        XCTAssertLessThanOrEqual(UnitGeometry.fittingRight, 1.0)
    }

    // MARK: - Bina

    private let screen = CGSize(width: 366, height: 330)

    func testFloorsStackFromTheGroundUpWithoutGaps() {
        for count in 1...4 {
            let layout = BuildingLayout(floorCount: count, available: screen)
            var previous: CGRect?

            for index in 0..<count {
                let frame = layout.frame(of: index)
                XCTAssertEqual(frame.width, screen.width, accuracy: 1e-6)
                XCTAssertGreaterThan(frame.height, 0)
                if let previous {
                    XCTAssertEqual(frame.maxY, previous.minY, accuracy: 1e-6,
                                   "\\(count) katta \\(index). kat bir altındakine yaslanmalı")
                }
                previous = frame
            }

            // Zemin kat kaldırımın üstünde durur.
            XCTAssertEqual(
                layout.frame(of: 0).maxY, layout.pavementFrame.minY, accuracy: 1e-6,
                "Zemin kat kaldırıma basmalı"
            )
        }
    }

    func testGroundFloorIsTallerBecauseItFacesTheStreet() {
        let layout = BuildingLayout(floorCount: 3, available: screen)
        XCTAssertGreaterThan(layout.height(of: 0), layout.height(of: 1))
        XCTAssertEqual(layout.height(of: 1), layout.height(of: 2), accuracy: 1e-9)
        XCTAssertEqual(
            layout.height(of: 0), layout.height(of: 1) * BuildingLayout.groundFloorScale, accuracy: 1e-6
        )
    }

    func testBuildingFitsTheAvailableBox() {
        for count in 1...5 {
            let layout = BuildingLayout(floorCount: count, available: screen)
            XCTAssertGreaterThanOrEqual(layout.buildingFrame.minY, -0.001)
            XCTAssertEqual(layout.buildingFrame.maxY, screen.height, accuracy: 1e-6)
        }
    }

    func testTallBuildingsStopBeingLegible() {
        // Faz 4+'ta üst katları kırpmamız gerekecek; sınır burada yakalanıyor.
        XCTAssertTrue(BuildingLayout(floorCount: 2, available: screen).isLegible)
        XCTAssertFalse(BuildingLayout(floorCount: 8, available: screen).isLegible)
    }

    func testDegenerateSizesDoNotCrash() {
        XCTAssertEqual(BuildingLayout(floorCount: 0, available: screen).frame(of: 0), .zero)
        XCTAssertEqual(BuildingLayout(floorCount: 0, available: screen).buildingFrame, .zero)
        XCTAssertEqual(BuildingLayout(floorCount: 2, available: .zero).bandHeight, 0, accuracy: 1e-9)
    }

    // MARK: - Palet

    func testPaletteCoolsAsTheBuildingRises() {
        let ground = FloorPalette(floor: 0, plannedFloors: 8)
        let middle = FloorPalette(floor: 4, plannedFloors: 8)
        let top = FloorPalette(floor: 7, plannedFloors: 8)

        XCTAssertEqual(ground.coolness, 0, accuracy: 1e-9)
        XCTAssertEqual(top.coolness, 1, accuracy: 1e-9)
        XCTAssertGreaterThan(middle.coolness, ground.coolness)
        XCTAssertLessThan(middle.coolness, top.coolness)
    }

    func testSecondFloorOnlyCoolsSlightly() {
        // Geçiş sert olmasın: iki katlık binada birinci kat hafifçe soğur.
        let first = FloorPalette(floor: 1, plannedFloors: 8)
        XCTAssertGreaterThan(first.coolness, 0)
        XCTAssertLessThan(first.coolness, 0.2)
    }

    func testMustardStaysTheSameOnEveryFloor() {
        // Para hep aynı renk — katmanlar arasındaki tek süreklilik.
        XCTAssertEqual(
            FloorPalette(floor: 0, plannedFloors: 8).ownerApron,
            FloorPalette(floor: 7, plannedFloors: 8).ownerApron
        )
    }

    func testPaletteIsClampedForShortAndOddBuildings() {
        XCTAssertEqual(FloorPalette(floor: 5, plannedFloors: 2).coolness, 1, accuracy: 1e-9)
        XCTAssertEqual(FloorPalette(floor: 0, plannedFloors: 1).coolness, 0, accuracy: 1e-9)
    }
}
