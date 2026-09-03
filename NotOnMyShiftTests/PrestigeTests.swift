import XCTest
@testable import NotOnMyShift

/// Faz 6: yumuşak prestij, sektör satışı ve final.
///
/// Rapor §5'in şartı burada korunuyor: satış üç şey birden vermeli — nakit,
/// kalıcı puan ve binada kalıcı bir iz. Üçüncüsü olmadan oyuncu satmaya
/// direnir, çünkü sattığı şeyin yok olduğunu sanır.
final class PrestigeTests: XCTestCase {

    // MARK: - Olgunluk

    func testFloorIsNotMatureUntilEverythingIsBought() throws {
        let config = BalanceFixture.config()
        let spec = try XCTUnwrap(config.sector(at: 0))

        XCTAssertFalse(GameEngine.isMature(FloorState(sectorID: spec.id), spec: spec))

        // Tam kadro ve tam ekipman ama tek hücre: henüz değil.
        var almost = BalanceFixture.matureFloor(config: config)
        almost.branchCount = 1
        XCTAssertFalse(GameEngine.isMature(almost, spec: spec))

        // Tam hücre ama eksik ekipman: yine değil.
        var noKit = BalanceFixture.matureFloor(config: config)
        noKit.equipmentLevels = [:]
        XCTAssertFalse(GameEngine.isMature(noKit, spec: spec))

        // Tam ekipman ve hücre ama eksik kadro: yine değil.
        var shortHanded = BalanceFixture.matureFloor(config: config)
        shortHanded.staff.removeLast()
        XCTAssertFalse(GameEngine.isMature(shortHanded, spec: spec))

        XCTAssertTrue(GameEngine.isMature(BalanceFixture.matureFloor(config: config), spec: spec))
    }

    func testMaturityProgressRisesWithEveryPurchase() throws {
        let config = BalanceFixture.config()
        let spec = try XCTUnwrap(config.sector(at: 0))

        let empty = GameEngine.maturityProgress(FloorState(sectorID: spec.id), spec: spec)
        var partial = FloorState(sectorID: spec.id)
        partial.staff = BalanceFixture.matureFloor(config: config).staff
        let half = GameEngine.maturityProgress(partial, spec: spec)
        let full = GameEngine.maturityProgress(BalanceFixture.matureFloor(config: config), spec: spec)

        XCTAssertGreaterThan(half, empty)
        XCTAssertGreaterThan(full, half)
        XCTAssertEqual(full, 1, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(empty, 0)
    }

    // MARK: - Satış

    func testSellingPaysCashKeepsThePointAndLeavesAnInvestmentFloor() throws {
        let config = BalanceFixture.config(payoutSeconds: 100, investmentShare: 0.1)
        var state = BalanceFixture.state(config: config)
        state.floors = [BalanceFixture.matureFloor(config: config)]

        // Tam kadro (1,0 + 2,0 + 0,5) × taban 1 × öğütücü ×4 × 3 hücre = 42/sn
        let before = GameEngine.productionRate(for: state, config: config)
        XCTAssertEqual(before, 42, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.saleValue(onFloor: 0, state, config: config) ?? 0, 4_200, accuracy: 1e-6)

        guard case .success(let sold) = GameEngine.sellSector(onFloor: 0, state, config: config) else {
            return XCTFail("olgun kat satılmalıydı")
        }

        XCTAssertEqual(sold.money, 4_200, accuracy: 1e-6)
        XCTAssertEqual(sold.holdingPoints, 1)
        XCTAssertEqual(sold.stats.sectorsSold, 1)

        // Binada kalıcı iz: kat duruyor ve hâlâ ödüyor.
        XCTAssertEqual(sold.floors.count, 1)
        XCTAssertTrue(sold.floors[0].isInvestment)
        XCTAssertEqual(sold.floors[0].investmentRate, 4.2, accuracy: 1e-9)
        XCTAssertTrue(sold.floors[0].staff.isEmpty)
        XCTAssertTrue(sold.floors[0].equipmentLevels.isEmpty)
        XCTAssertEqual(sold.floors[0].branchCount, 1)
    }

    /// Satılan kat üretmeye devam eder ve puan onu da çarpar.
    func testTheSoldFloorKeepsEarning() {
        let config = BalanceFixture.config(payoutSeconds: 100, investmentShare: 0.1, multiplierPerPoint: 0.5)
        var state = BalanceFixture.state(config: config)
        state.floors = [BalanceFixture.matureFloor(config: config)]

        guard case .success(let sold) = GameEngine.sellSector(onFloor: 0, state, config: config) else {
            return XCTFail("olgun kat satılmalıydı")
        }

        // Kira 4,2/sn, puan çarpanı 1,5 → 6,3/sn. Kadro yok ama iş duruyor.
        XCTAssertEqual(GameEngine.productionRate(for: sold, config: config), 6.3, accuracy: 1e-9)
        XCTAssertTrue(sold.isAutomated, "yatırım katı da sensiz üretir")

        let later = GameEngine.advance(sold, by: 100, config: config)
        XCTAssertEqual(later.money - sold.money, 630, accuracy: 1e-6)
    }

    func testAnImmatureFloorCannotBeSold() {
        let config = BalanceFixture.config()
        let state = BalanceFixture.state(staffCount: 1, config: config)

        XCTAssertNil(GameEngine.saleValue(onFloor: 0, state, config: config))
        XCTAssertEqual(GameEngine.sellSector(onFloor: 0, state, config: config), .failure(.sectorNotMature))
    }

    func testAnInvestmentFloorCannotBeSoldOrRebuilt() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(money: 1_000_000, config: config)
        state.floors = [BalanceFixture.matureFloor(config: config)]

        guard case .success(let sold) = GameEngine.sellSector(onFloor: 0, state, config: config) else {
            return XCTFail("olgun kat satılmalıydı")
        }

        XCTAssertEqual(GameEngine.sellSector(onFloor: 0, sold, config: config), .failure(.sectorAlreadySold))
        XCTAssertEqual(GameEngine.hireStaff(onFloor: 0, sold, config: config), .failure(.sectorAlreadySold))
        XCTAssertEqual(GameEngine.upgradeEquipment("grinder", onFloor: 0, sold, config: config), .failure(.sectorAlreadySold))
        XCTAssertEqual(GameEngine.openBranch(onFloor: 0, sold, config: config), .failure(.sectorAlreadySold))

        // Tezgâh gitti: elle satış da yok, ama çökme de yok.
        let tapped = GameEngine.sellManually(onFloor: 0, sold, config: config)
        XCTAssertEqual(tapped.money, sold.money, accuracy: 1e-9)
        XCTAssertEqual(tapped.stats.manualSales, sold.stats.manualSales)
        // Ekranda da sıfır görünmeli: olmayan bir kazanç uçurmayalım.
        XCTAssertEqual(GameEngine.manualRevenue(onFloor: 0, sold, config: config), 0, accuracy: 1e-9)
    }

    /// Satılan katın müdürü ve kuralları da gider — yatırım katı yönetilmez.
    func testSellingClearsTheManagerAndTheRules() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(config: config)
        state.floors = [BalanceFixture.matureFloor(config: config)]
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["hire", "equip"]

        guard case .success(let sold) = GameEngine.sellSector(onFloor: 0, state, config: config) else {
            return XCTFail("olgun kat satılmalıydı")
        }

        XCTAssertFalse(sold.hasManager("coffee"))
        XCTAssertTrue(sold.rules(for: "coffee").isEmpty)

        // Müdür yatırım katına hiç uğramaz.
        let outcome = GameEngine.applyRules(sold, config: config)
        XCTAssertTrue(outcome.actions.isEmpty)
    }

    // MARK: - Holding puanı

    func testHoldingPointsMultiplyEveryFloorAndEveryHandSale() {
        let config = BalanceFixture.config(multiplierPerPoint: 0.5)
        var state = BalanceFixture.state(
            staffCount: 2,
            extraFloors: [BalanceFixture.upperFloor(staffCount: 1, config: config)],
            config: config
        )
        // Zemin brüt 3/sn (maaşsız), fırın brüt 10/sn ve maaş 1/sn → net 12/sn.
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 12, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.manualRevenue(onFloor: 0, state, config: config), 10, accuracy: 1e-9)

        state.holdingPoints = 2
        XCTAssertEqual(GameEngine.holdingMultiplier(for: state, config: config), 2, accuracy: 1e-9)
        // Brüt ikiye katlanır, maaş yerinde kalır: 6 + (20 − 1) = 25/sn.
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 25, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.manualRevenue(onFloor: 0, state, config: config), 20, accuracy: 1e-9)
    }

    /// Çarpan brüte uygulanır, maaşa değil — olay çarpanıyla aynı kural.
    func testHoldingPointsDoNotRaiseWages() {
        let config = BalanceFixture.config(wagePerSecond: 0.5, multiplierPerPoint: 1)
        var state = BalanceFixture.state(staffCount: 1, config: config)
        let wages = GameEngine.wageRate(for: state, config: config)

        state.holdingPoints = 3
        XCTAssertEqual(GameEngine.wageRate(for: state, config: config), wages, accuracy: 1e-9)
        // Brüt 1/sn, maaş 0,5/sn. 3 puan → brüt 4/sn, net 3,5/sn.
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 3.5, accuracy: 1e-9)
    }

    // MARK: - Final: halka arz

    func testGoingPublicNeedsEverySectorGrown() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(config: config)

        // Tek kat, üstelik olgun değil.
        XCTAssertFalse(GameEngine.canGoPublic(state, config: config))
        XCTAssertEqual(GameEngine.goPublic(state, config: config), .failure(.notReadyToGoPublic))

        // Zemin kat olgun ama fırın katı hiç açılmadı.
        state.floors = [BalanceFixture.matureFloor(config: config)]
        XCTAssertFalse(GameEngine.canGoPublic(state, config: config))

        // İkinci kat açıldı ama daha büyümedi.
        state.floors.append(BalanceFixture.upperFloor(config: config))
        XCTAssertFalse(GameEngine.canGoPublic(state, config: config))

        state.floors[1] = BalanceFixture.matureFloor(sectorIndex: 1, config: config)
        XCTAssertTrue(GameEngine.canGoPublic(state, config: config))
    }

    /// Satılmış kat da "tamamlanmış" sayılır: son katı satmak finali kilitlemez.
    func testASoldFloorStillCountsAsFinished() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(config: config)
        state.floors = [
            BalanceFixture.matureFloor(config: config),
            BalanceFixture.matureFloor(sectorIndex: 1, config: config)
        ]

        guard case .success(let sold) = GameEngine.sellSector(onFloor: 0, state, config: config) else {
            return XCTFail("olgun kat satılmalıydı")
        }
        XCTAssertTrue(GameEngine.canGoPublic(sold, config: config))
    }

    func testGoingPublicResetsTheBuildingButNotWhatIsYours() throws {
        let config = BalanceFixture.config(pointsPerCity: 2)
        var state = BalanceFixture.state(money: 5_000, warehouseLevel: 2, config: config)
        state.floors = [
            BalanceFixture.matureFloor(config: config),
            BalanceFixture.matureFloor(sectorIndex: 1, config: config)
        ]
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["hire"]
        state.holdingPoints = 3
        state.lifetimeEarnings = 90_000
        state.elapsedGameSeconds = 12_345
        state.stats.manualSales = 40

        guard case .success(let next) = GameEngine.goPublic(state, config: config) else {
            return XCTFail("halka arz olmalıydı")
        }

        // Binaya ait olan sıfırlanır.
        XCTAssertEqual(next.floors.count, 1)
        XCTAssertTrue(next.floors[0].staff.isEmpty)
        XCTAssertFalse(next.floors[0].isInvestment)
        XCTAssertEqual(next.money, 0, accuracy: 1e-9)
        XCTAssertFalse(next.hasRoof)
        XCTAssertTrue(next.managedSectors.isEmpty)
        XCTAssertTrue(next.activeRules.isEmpty)
        XCTAssertEqual(next.elapsedGameSeconds, 0, accuracy: 1e-9)

        // Sana ait olan kalır.
        XCTAssertEqual(next.holdingPoints, 5, "puan taşınır ve halka arz iki puan ekler")
        XCTAssertEqual(next.warehouseLevel, 2)
        XCTAssertEqual(next.lifetimeEarnings, 90_000, accuracy: 1e-9)
        XCTAssertEqual(next.stats.manualSales, 40)
        XCTAssertEqual(next.stats.citiesCompleted, 1)
        XCTAssertEqual(next.cityNumber, 2)

        // Yeni şehir daha hızlı: aynı kadro artık daha çok üretir.
        var fresh = next
        fresh.floors[0] = BalanceFixture.matureFloor(config: config)
        var without = fresh
        without.holdingPoints = 0
        XCTAssertGreaterThan(
            GameEngine.productionRate(for: fresh, config: config),
            GameEngine.productionRate(for: without, config: config)
        )
    }

    /// Motor saf: yeni şehrin zamanı sistem saatinden değil kayıttan gelir.
    func testGoingPublicDoesNotReadTheClock() throws {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(lastSeenAt: BalanceFixture.epoch, config: config)
        state.floors = [
            BalanceFixture.matureFloor(config: config),
            BalanceFixture.matureFloor(sectorIndex: 1, config: config)
        ]

        guard case .success(let next) = GameEngine.goPublic(state, config: config) else {
            return XCTFail("halka arz olmalıydı")
        }
        XCTAssertEqual(next.startedAt, BalanceFixture.epoch)
        XCTAssertEqual(next.lastSeenAt, BalanceFixture.epoch)
        XCTAssertNotEqual(next.eventSeed, 0, "tohum sıfıra düşmemeli")
    }

    // MARK: - Kayıt

    func testPrestigeStateSurvivesASaveRoundTrip() throws {
        var state = BalanceFixture.state(config: BalanceFixture.config())
        state.holdingPoints = 4
        state.cityNumber = 3
        state.stats.sectorsSold = 6
        state.stats.citiesCompleted = 2
        state.floors[0].investmentRate = 12.5

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)

        XCTAssertEqual(restored.holdingPoints, 4)
        XCTAssertEqual(restored.cityNumber, 3)
        XCTAssertEqual(restored.stats.sectorsSold, 6)
        XCTAssertEqual(restored.stats.citiesCompleted, 2)
        XCTAssertEqual(restored.floors[0].investmentRate, 12.5, accuracy: 1e-9)
        XCTAssertTrue(restored.floors[0].isInvestment)
    }

    /// Faz 5 kaydı Faz 6 motorunda açılmalı: prestij alanları kapalı gelir.
    func testOlderSaveOpensWithNoPointsAndNoInvestmentFloor() throws {
        let older = """
        {
          "schemaVersion": 6,
          "characterID": "kahveci",
          "money": 900,
          "hasRoof": true,
          "managedSectors": ["coffee"],
          "floors": [{ "sectorID": "coffee", "staff": [], "equipmentLevels": {}, "branchCount": 2 }]
        }
        """
        guard let data = older.data(using: .utf8) else { return XCTFail("veri kurulamadı") }
        let state = try JSONDecoder().decode(GameState.self, from: data)

        XCTAssertEqual(state.holdingPoints, 0)
        XCTAssertEqual(state.cityNumber, 1)
        XCTAssertEqual(state.stats.sectorsSold, 0)
        XCTAssertFalse(state.floors[0].isInvestment)
        XCTAssertTrue(state.hasRoof, "şema 6 alanları da yerinde kalmalı")
        XCTAssertEqual(state.money, 900, accuracy: 1e-9)
    }

    // MARK: - Gönderilen denge

    func testShippedBalanceDescribesThePrestigeLoop() throws {
        let config = try loadShippedConfig()

        XCTAssertGreaterThan(config.prestige.payoutSeconds, 0)
        XCTAssertGreaterThan(config.prestige.multiplierPerPoint, 0)
        XCTAssertGreaterThanOrEqual(config.prestige.pointsPerSale, 1)
        XCTAssertGreaterThanOrEqual(config.prestige.pointsPerCity, 0)

        // Yatırım katı bir oran, bir çarpan değil: satıştan sonrasını küçültür
        // ama sıfırlamaz. Sıfır olsaydı satmak kaybetmek olurdu.
        XCTAssertGreaterThan(config.prestige.investmentShare, 0, "satılan kat üretmeye devam etmeli")
        XCTAssertLessThan(config.prestige.investmentShare, 1)

        // Satış bir üst katı açmaya yetmeli (rapor §5).
        guard let ground = config.sector(at: 0), let upstairs = config.sector(at: 1) else {
            return XCTFail("dengede iki sektör olmalı")
        }
        let mature = BalanceFixture.matureFloor(config: config)
        let payout = GameEngine.floorNet(mature, spec: ground) * config.prestige.payoutSeconds
        XCTAssertGreaterThan(payout, upstairs.unlockCost, "satış yeni kata yetmiyor")

        // Satış katı kurmanın bedelini geçmeli, yoksa satmak zarar olur.
        let buildCost = buildCost(of: ground)
        XCTAssertGreaterThan(payout, buildCost, "satış, katı kurmaya harcanandan az getiriyor")
    }

    /// Bir sektörü sıfırdan tam kurmanın toplam bedeli.
    private func buildCost(of spec: BalanceConfig.SectorSpec) -> Double {
        let capacity = min(max(0, spec.staff.maxCount), spec.staffPool.count)
        let crew = (0..<capacity).reduce(0.0) { total, index in
            total + spec.staff.baseCost * pow(spec.staff.costGrowth, Double(index))
        }
        let kit = spec.equipment.reduce(0.0) { total, item in
            total + item.levels.dropFirst().reduce(0.0) { $0 + $1.cost }
        }
        let branches = (2...max(2, spec.branches.maxCount)).reduce(0.0) { total, slot in
            total + spec.branches.baseCost * pow(spec.branches.costGrowth, Double(slot - 2))
        }
        return crew + kit + (spec.branches.maxCount > 1 ? branches : 0)
    }

    private func loadShippedConfig() throws -> BalanceConfig {
        if let config = try? BalanceConfig.load(in: .main) { return config }
        return try BalanceConfig.load(in: Bundle(for: Self.self))
    }
}
