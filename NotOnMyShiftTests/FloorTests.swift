import XCTest
@testable import NotOnMyShift

/// Faz 3: kat açma ve kat kat ekonomi.
///
/// Bir kat = bir sektör. Kasa ortak, kadro ve ekipman kata ait.
final class FloorTests: XCTestCase {

    private let config = BalanceFixture.config(wagePerSecond: 0.25, upperUnlockCost: 1_000)
    private var ground: BalanceConfig.SectorSpec { config.sectors[0] }
    private var upper: BalanceConfig.SectorSpec { config.sectors[1] }

    // MARK: - Kat açma

    func testNewGameStartsWithOnlyTheGroundFloor() {
        let state = BalanceFixture.state(config: config)
        XCTAssertEqual(state.floors.count, 1)
        XCTAssertEqual(state.floors[0].sectorID, "coffee")
        XCTAssertEqual(state.selectedFloor, 0)
    }

    func testUnlockingAFloorCostsMoneyAndOpensTheNextSector() {
        let state = BalanceFixture.state(money: 1_500, config: config)
        XCTAssertEqual(GameEngine.nextFloorCost(for: state, config: config) ?? -1, 1_000, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.nextSector(for: state, config: config)?.id, "bakery")

        guard case .success(let next) = GameEngine.unlockNextFloor(state, config: config) else {
            return XCTFail("Kat açılamadı")
        }

        XCTAssertEqual(next.money, 500, accuracy: 1e-9)
        XCTAssertEqual(next.floors.count, 2)
        XCTAssertEqual(next.floors[1].sectorID, "bakery")
        // Yeni kat boş gelir: kendi kadrosunu ve ekipmanını sıfırdan kurarsın.
        XCTAssertTrue(next.floors[1].staff.isEmpty)
        XCTAssertTrue(next.floors[1].equipmentLevels.isEmpty)
        XCTAssertEqual(next.floors[1].branchCount, 1)
        // Açtığın şeyin başında ol.
        XCTAssertEqual(next.selectedFloor, 1)
    }

    func testUnlockingFailsWithoutEnoughMoney() {
        let state = BalanceFixture.state(money: 999, config: config)
        guard case .failure(let error) = GameEngine.unlockNextFloor(state, config: config) else {
            return XCTFail("Para yetmezken kat açılmamalı")
        }
        XCTAssertEqual(error, .insufficientFunds)
    }

    func testBuildingFillsUpWhenEverySectorIsOpen() {
        let state = BalanceFixture.state(
            money: 1_000_000,
            extraFloors: [BalanceFixture.upperFloor(config: config)],
            config: config
        )
        XCTAssertNil(GameEngine.nextFloorCost(for: state, config: config))
        XCTAssertNil(GameEngine.nextSector(for: state, config: config))

        guard case .failure(let error) = GameEngine.unlockNextFloor(state, config: config) else {
            return XCTFail("Bina doluyken kat açılmamalı")
        }
        XCTAssertEqual(error, .allFloorsOpen)
    }

    // MARK: - Kat kat ekonomi

    func testEachFloorContributesItsOwnNet() {
        // Zemin: 2 eleman (1.0 + 2.0) × 1/sn = brüt 3, maaş 0,5 → net 2,5
        // Üst:   1 eleman (1.0) × 10/sn = brüt 10, maaş 1 → net 9
        let state = BalanceFixture.state(
            staffCount: 2,
            extraFloors: [BalanceFixture.upperFloor(staffCount: 1, config: config)],
            config: config
        )

        XCTAssertEqual(GameEngine.floorNet(state.floors[0], spec: ground), 2.5, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.floorNet(state.floors[1], spec: upper), 9.0, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.grossRate(for: state, config: config), 13.0, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.wageRate(for: state, config: config), 1.5, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 11.5, accuracy: 1e-9)
    }

    func testALosingFloorDoesNotDragDownAProfitableOne() {
        // Zarardaki kat sıfır üretir; kârdaki katın kazancını yemez.
        let harsh = BalanceFixture.config(ratePerSecond: 0.01, wagePerSecond: 5)
        let state = BalanceFixture.state(
            staffCount: 3,
            extraFloors: [BalanceFixture.upperFloor(staffCount: 1, config: harsh)],
            config: harsh
        )

        XCTAssertEqual(GameEngine.floorNet(state.floors[0], spec: harsh.sectors[0]), 0, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.floorNet(state.floors[1], spec: harsh.sectors[1]), 9, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.productionRate(for: state, config: harsh), 9, accuracy: 1e-9)
    }

    func testFloorsKeepTheirOwnCrewAndKit() {
        var state = BalanceFixture.state(
            money: 100_000,
            extraFloors: [BalanceFixture.upperFloor(config: config)],
            config: config
        )

        guard case .success(let hiredUpstairs) = GameEngine.hireStaff(onFloor: 1, state, config: config) else {
            return XCTFail("Üst kata eleman alınamadı")
        }
        state = hiredUpstairs

        XCTAssertTrue(state.floors[0].staff.isEmpty, "Zemin kat etkilenmemeli")
        XCTAssertEqual(state.floors[1].staff.count, 1)
        XCTAssertEqual(state.floors[1].staff[0].id, "baker", "Üst katın kendi havuzu kullanılmalı")

        guard case .success(let kitted) = GameEngine.upgradeEquipment("oven", onFloor: 1, state, config: config) else {
            return XCTFail("Üst katın ekipmanı yükseltilemedi")
        }
        XCTAssertEqual(kitted.floors[1].equipmentLevel("oven"), 1)
        XCTAssertEqual(kitted.floors[0].equipmentLevel("oven"), 0)
    }

    func testAnEquipmentFromAnotherSectorIsRejected() {
        let state = BalanceFixture.state(
            money: 100_000,
            extraFloors: [BalanceFixture.upperFloor(config: config)],
            config: config
        )
        // Öğütücü zemin katın parçası; fırında yeri yok.
        guard case .failure(let error) = GameEngine.upgradeEquipment("grinder", onFloor: 1, state, config: config) else {
            return XCTFail("Yanlış kata ait ekipman geçmemeli")
        }
        XCTAssertEqual(error, .unknownEquipment)
    }

    func testActionsOnAMissingFloorFailCleanly() {
        let state = BalanceFixture.state(money: 100_000, config: config)
        guard case .failure(let error) = GameEngine.hireStaff(onFloor: 7, state, config: config) else {
            return XCTFail("Olmayan katta alım geçmemeli")
        }
        XCTAssertEqual(error, .unknownFloor)
    }

    func testAFloorWhoseSectorLeftTheBalanceEarnsNothingInsteadOfCrashing() {
        var state = BalanceFixture.state(staffCount: 2, config: config)
        state.floors.append(
            FloorState(
                sectorID: "dengeden_kalkti",
                staff: [StaffMember(id: "quick", rateMultiplier: 5, hiredAtGameSeconds: 0)]
            )
        )

        // Zemin kat çalışmaya devam eder, tanınmayan kat sessizce sıfır üretir.
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 2.5, accuracy: 1e-9)
        guard case .failure(let error) = GameEngine.hireStaff(onFloor: 1, state, config: config) else {
            return XCTFail("Tanınmayan sektörde alım geçmemeli")
        }
        XCTAssertEqual(error, .unknownSector)
    }

    // MARK: - Kat seçimi

    func testSelectingAFloorIsClampedToWhatExists() {
        let state = BalanceFixture.state(
            extraFloors: [BalanceFixture.upperFloor(config: config)],
            config: config
        )

        XCTAssertEqual(GameEngine.selectFloor(1, state).selectedFloor, 1)
        // Olmayan kat seçilmez; durum değişmez.
        XCTAssertEqual(GameEngine.selectFloor(9, state).selectedFloor, state.selectedFloor)

        var broken = state
        broken.selectedFloor = 42
        XCTAssertEqual(broken.safeSelectedFloor, 1, "Bozuk kayıt sınıra kırpılmalı")
        XCTAssertEqual(broken.currentFloor?.sectorID, "bakery")
    }

    // MARK: - Elle satış katın kendi ürününü satar

    func testManualSaleUsesTheSelectedFloorsSector() {
        let state = BalanceFixture.state(
            extraFloors: [BalanceFixture.upperFloor(config: config)],
            config: config
        )

        XCTAssertEqual(GameEngine.sellManually(onFloor: 0, state, config: config).money, 10, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.sellManually(onFloor: 1, state, config: config).money, 100, accuracy: 1e-9)
    }
}
