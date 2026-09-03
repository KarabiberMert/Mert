import XCTest
@testable import NotOnMyShift

/// Çağ 2: ekipman, maaş ve şubeler — hepsi kat başına.
///
/// Tasarım raporundaki asıl soru burada ölçülüyor: eleman maaşı ile makine
/// yatırımı arasında gerçek bir seçim var mı? Ekipman bir kez ödenir ve çarpar;
/// eleman her saniye maaş ister.
final class EquipmentAndBranchTests: XCTestCase {

    private let config = BalanceFixture.config(wagePerSecond: 0.25)
    private var ground: BalanceConfig.SectorSpec { config.sectors[0] }

    private func floor(_ state: GameState) -> FloorState { state.floors[0] }

    // MARK: - Ekipman

    func testEquipmentMultiplierIsOneWhenNothingIsUpgraded() {
        let state = BalanceFixture.state(config: config)
        XCTAssertEqual(GameEngine.equipmentMultiplier(for: floor(state), spec: ground), 1, accuracy: 1e-9)
    }

    func testEquipmentMultiplierFollowsTheOwnedLevel() {
        for (level, expected) in [(0, 1.0), (1, 2.0), (2, 4.0)] {
            let state = BalanceFixture.state(equipmentLevels: ["grinder": level], config: config)
            XCTAssertEqual(
                GameEngine.equipmentMultiplier(for: floor(state), spec: ground), expected, accuracy: 1e-9
            )
        }
    }

    func testUnknownOrOutOfRangeLevelsAreClamped() {
        // Dengeye yeni parça eklendiğinde ya da seviye dizisi kısaldığında
        // eski kayıt çökmemeli.
        let tooHigh = BalanceFixture.state(equipmentLevels: ["grinder": 99], config: config)
        XCTAssertEqual(GameEngine.equipmentMultiplier(for: floor(tooHigh), spec: ground), 4, accuracy: 1e-9)

        let unknown = BalanceFixture.state(equipmentLevels: ["bilinmeyen": 3], config: config)
        XCTAssertEqual(GameEngine.equipmentMultiplier(for: floor(unknown), spec: ground), 1, accuracy: 1e-9)
    }

    func testUpgradingEquipmentDeductsCostAndRaisesOutput() {
        let state = BalanceFixture.state(money: 100, staffCount: 1, config: config)
        let before = GameEngine.grossRate(for: state, config: config)

        guard case .success(let next) = GameEngine.upgradeEquipment("grinder", onFloor: 0, state, config: config) else {
            return XCTFail("Öğütücü yükseltilemedi")
        }

        XCTAssertEqual(next.money, 50, accuracy: 1e-9)
        XCTAssertEqual(next.floors[0].equipmentLevel("grinder"), 1)
        XCTAssertEqual(GameEngine.grossRate(for: next, config: config), before * 2, accuracy: 1e-9)
    }

    func testEquipmentUpgradeFailsCleanly() {
        let poor = BalanceFixture.state(money: 10, config: config)
        guard case .failure(let funds) = GameEngine.upgradeEquipment("grinder", onFloor: 0, poor, config: config) else {
            return XCTFail("Para yetmezken yükseltme geçmemeli")
        }
        XCTAssertEqual(funds, .insufficientFunds)

        let rich = BalanceFixture.state(money: 1_000_000, config: config)
        guard case .failure(let unknown) = GameEngine.upgradeEquipment("yok_boyle", onFloor: 0, rich, config: config) else {
            return XCTFail("Tanınmayan ekipman geçmemeli")
        }
        XCTAssertEqual(unknown, .unknownEquipment)

        let maxed = BalanceFixture.state(money: 1_000_000, equipmentLevels: ["grinder": 2], config: config)
        guard case .failure(let level) = GameEngine.upgradeEquipment("grinder", onFloor: 0, maxed, config: config) else {
            return XCTFail("Son seviyede yükseltme geçmemeli")
        }
        XCTAssertEqual(level, .maxLevelReached)
        XCTAssertNil(GameEngine.equipmentUpgradeCost("grinder", for: floor(maxed), spec: ground))
    }

    func testEquipmentAlsoHelpsHandSelling() {
        // Çağ 0'daki oyuncu da makineden fayda görsün.
        let plain = BalanceFixture.state(config: config)
        let upgraded = BalanceFixture.state(equipmentLevels: ["grinder": 1], config: config)

        XCTAssertEqual(GameEngine.manualRevenue(for: floor(plain), spec: ground), 10, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.manualRevenue(for: floor(upgraded), spec: ground), 20, accuracy: 1e-9)

        let sold = GameEngine.sellManually(onFloor: 0, upgraded, config: config)
        XCTAssertEqual(sold.money, 20, accuracy: 1e-9)
    }

    // MARK: - Maaş

    func testWagesAreDeductedFromGross() {
        // 2 eleman: çarpanlar 1.0 + 2.0 = 3.0, oran 1/sn → brüt 3.0
        // maaş 2 × 0.25 = 0.5 → net 2.5
        let state = BalanceFixture.state(staffCount: 2, config: config)

        XCTAssertEqual(GameEngine.grossRate(for: state, config: config), 3.0, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.wageRate(for: state, config: config), 0.5, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 2.5, accuracy: 1e-9)
    }

    func testAdvanceCreditsTheNetRate() {
        let state = BalanceFixture.state(staffCount: 2, config: config)
        let next = GameEngine.advance(state, by: 10, config: config)
        XCTAssertEqual(next.money, 25, accuracy: 1e-9)
    }

    func testNetNeverGoesNegative() {
        // Maaş brütü geçse bile oyuncu geri gitmez; üretim sıfırda durur.
        let heavy = BalanceFixture.config(ratePerSecond: 0.01, wagePerSecond: 5)
        let state = BalanceFixture.state(staffCount: 3, config: heavy)

        XCTAssertGreaterThan(GameEngine.wageRate(for: state, config: heavy),
                             GameEngine.grossRate(for: state, config: heavy))
        XCTAssertEqual(GameEngine.productionRate(for: state, config: heavy), 0, accuracy: 1e-9)

        let next = GameEngine.advance(state, by: 3_600, config: heavy)
        XCTAssertEqual(next.money, state.money, accuracy: 1e-9, "Borç birikmemeli")
    }

    func testEquipmentBeatsHiringOnceWagesBite() {
        // Çağ 2'nin vaat ettiği seçim: makine bir kez ödenir ve her şeyi çarpar;
        // eleman hem pahalıdır hem her saniye maaş ister.
        let base = BalanceFixture.state(money: 500, staffCount: 2, config: config)

        XCTAssertEqual(GameEngine.equipmentUpgradeCost("grinder", for: floor(base), spec: ground) ?? -1,
                       50, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.hireCost(for: floor(base), spec: ground) ?? -1, 400, accuracy: 1e-9)

        guard case .success(let withKit) = GameEngine.upgradeEquipment("grinder", onFloor: 0, base, config: config),
              case .success(let withStaff) = GameEngine.hireStaff(onFloor: 0, base, config: config) else {
            return XCTFail("Karşılaştırma kurulamadı")
        }

        // Ekipman: brüt 3 → 6, maaş sabit 0,5 → net 5,5
        XCTAssertEqual(GameEngine.productionRate(for: withKit, config: config), 5.5, accuracy: 1e-9)
        // Üçüncü eleman: brüt 3 → 3,5, maaş 0,5 → 0,75 → net 2,75
        XCTAssertEqual(GameEngine.productionRate(for: withStaff, config: config), 2.75, accuracy: 1e-9)
        XCTAssertGreaterThan(withKit.money, withStaff.money, "Üstelik ekipman daha ucuzdu")
    }

    // MARK: - Şubeler

    func testBranchesMultiplyBothOutputAndWages() {
        let single = BalanceFixture.state(staffCount: 2, config: config)
        let triple = BalanceFixture.state(staffCount: 2, branchCount: 3, config: config)

        XCTAssertEqual(GameEngine.grossRate(for: triple, config: config),
                       GameEngine.grossRate(for: single, config: config) * 3, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.wageRate(for: triple, config: config),
                       GameEngine.wageRate(for: single, config: config) * 3, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.productionRate(for: triple, config: config), 7.5, accuracy: 1e-9)
    }

    func testBranchCostFollowsTheGrowthCurve() {
        // İkinci şube 500, üçüncü 5000.
        let first = BalanceFixture.state(config: config)
        XCTAssertEqual(GameEngine.branchCost(for: floor(first), spec: ground) ?? -1, 500, accuracy: 1e-9)

        let second = BalanceFixture.state(branchCount: 2, config: config)
        XCTAssertEqual(GameEngine.branchCost(for: floor(second), spec: ground) ?? -1, 5_000, accuracy: 1e-9)
    }

    func testOpeningABranchCopiesTheShop() {
        let state = BalanceFixture.state(money: 600, staffCount: 2, equipmentLevels: ["grinder": 1], config: config)

        guard case .success(let next) = GameEngine.openBranch(onFloor: 0, state, config: config) else {
            return XCTFail("Şube açılamadı")
        }

        XCTAssertEqual(next.money, 100, accuracy: 1e-9)
        XCTAssertEqual(next.floors[0].branchCount, 2)
        // Kadro ve ekipman devralınır — ayrı ayar yok.
        XCTAssertEqual(next.floors[0].staff.count, state.floors[0].staff.count)
        XCTAssertEqual(next.floors[0].equipmentLevel("grinder"), 1)
        XCTAssertEqual(GameEngine.grossRate(for: next, config: config),
                       GameEngine.grossRate(for: state, config: config) * 2, accuracy: 1e-9)
    }

    func testBranchLimitIsRespected() {
        let full = BalanceFixture.state(money: 1_000_000, branchCount: 3, config: config)
        XCTAssertNil(GameEngine.branchCost(for: floor(full), spec: ground))

        guard case .failure(let error) = GameEngine.openBranch(onFloor: 0, full, config: config) else {
            return XCTFail("Kat doluyken şube açılmamalı")
        }
        XCTAssertEqual(error, .branchLimitReached)
    }

    func testSavedBranchCountIsClampedToTheBalance() {
        // Denge sınırı düşerse eski kayıt sınırın üstünde kalmasın.
        let overflowing = BalanceFixture.state(branchCount: 99, config: config)
        XCTAssertEqual(GameEngine.branchCount(for: floor(overflowing), spec: ground), 3)
    }
}
