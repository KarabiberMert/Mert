import XCTest
@testable import NotOnMyShift

/// Faz 5: süreç katmanı — çatı, müdürler, sabit kurallar.
///
/// Bu dosyanın asıl işi rapor §4'ün kuralını korumak: **derinlik ceza kaçınma
/// değil, ödüldür.** Kural kurmayan oyuncu tam verimle çalışmaya devam eder;
/// kural kuran fazladan verim alır. Hiçbir test "kural koymazsan kaybedersin"
/// diyen bir davranışı doğrulamamalı.
final class ProcessTests: XCTestCase {

    // MARK: - Çatı

    func testRoofCostsMoneyAndOpensOnce() {
        let config = BalanceFixture.config(roofCost: 1_000)
        let state = BalanceFixture.state(money: 1_000, config: config)

        guard case .success(let opened) = GameEngine.unlockRoof(state, config: config) else {
            return XCTFail("çatı açılmalıydı")
        }
        XCTAssertTrue(opened.hasRoof)
        XCTAssertEqual(opened.money, 0, accuracy: 0.0001)
        XCTAssertNil(GameEngine.roofCost(for: opened, config: config))

        XCTAssertEqual(GameEngine.unlockRoof(opened, config: config), .failure(.roofAlreadyOpen))
    }

    func testRoofNeedsTheMoney() {
        let config = BalanceFixture.config(roofCost: 1_000)
        let state = BalanceFixture.state(money: 999, config: config)
        XCTAssertEqual(GameEngine.unlockRoof(state, config: config), .failure(.insufficientFunds))
    }

    /// Çatı katı üretmez. Açmak geliri değiştirmemeli — sadece kapıyı açar.
    func testRoofDoesNotChangeProduction() {
        let config = BalanceFixture.config(roofCost: 1_000)
        let state = BalanceFixture.state(money: 1_000, staffCount: 2, config: config)
        let before = GameEngine.productionRate(for: state, config: config)

        guard case .success(let opened) = GameEngine.unlockRoof(state, config: config) else {
            return XCTFail("çatı açılmalıydı")
        }
        XCTAssertEqual(GameEngine.productionRate(for: opened, config: config), before, accuracy: 0.0001)
    }

    // MARK: - Müdür

    func testManagerNeedsARoof() {
        let config = BalanceFixture.config()
        let state = BalanceFixture.state(money: 10_000, config: config)
        XCTAssertEqual(
            GameEngine.hireManager(forSector: "coffee", state, config: config),
            .failure(.roofRequired)
        )
        XCTAssertNil(GameEngine.managerCost(for: state, config: config))
    }

    func testManagerCostGrowsWithEachManager() {
        let config = BalanceFixture.config(managerBaseCost: 200)
        var state = BalanceFixture.state(money: 10_000, extraFloors: [BalanceFixture.upperFloor()], config: config)
        state.hasRoof = true

        XCTAssertEqual(GameEngine.managerCost(for: state, config: config), 200)

        guard case .success(let one) = GameEngine.hireManager(forSector: "coffee", state, config: config) else {
            return XCTFail("ilk müdür tutulmalıydı")
        }
        XCTAssertEqual(one.money, 9_800, accuracy: 0.0001)
        // İkinci müdür iki katı: yayılma bedava olmasın.
        XCTAssertEqual(GameEngine.managerCost(for: one, config: config), 400)

        XCTAssertEqual(
            GameEngine.hireManager(forSector: "coffee", one, config: config),
            .failure(.managerAlreadyHired)
        )
    }

    func testManagerOnlyGoesToAFloorThatExists() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(money: 10_000, config: config)
        state.hasRoof = true
        XCTAssertEqual(
            GameEngine.hireManager(forSector: "bakery", state, config: config),
            .failure(.unknownFloor)
        )
    }

    // MARK: - Kurallar ve verim

    /// Kural koymayan hiçbir şey kaybetmez. Bu test kırılırsa rapor §4 kırılmıştır.
    func testNoRulesMeansFullEfficiency() {
        let config = BalanceFixture.config()
        var plain = BalanceFixture.state(staffCount: 2, config: config)
        var roofed = plain
        roofed.hasRoof = true
        roofed.managedSectors = ["coffee"]
        plain.hasRoof = false

        XCTAssertEqual(
            GameEngine.productionRate(for: roofed, config: config),
            GameEngine.productionRate(for: plain, config: config),
            accuracy: 0.0001
        )
    }

    func testEachRuleAddsBonusUpToTheCeiling() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(staffCount: 2, config: config)
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        let base = GameEngine.productionRate(for: state, config: config)

        state.activeRules["coffee"] = ["hire"]
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), base * 1.1, accuracy: 0.0001)

        state.activeRules["coffee"] = ["hire", "equip"]
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), base * 1.2, accuracy: 0.0001)

        // Tavan %30: dördüncü kural eklense de artmaz.
        state.activeRules["coffee"] = ["hire", "equip", "branch"]
        let capped = GameEngine.productionRate(for: state, config: config)
        XCTAssertEqual(capped, base * 1.3, accuracy: 0.0001)
        state.activeRules["coffee"] = ["hire", "equip", "branch", "hire"]
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), capped, accuracy: 0.0001)
    }

    /// Bonus katın kendisine yazılır: müdürsüz kat etkilenmez.
    func testBonusStaysOnTheManagedFloor() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(
            staffCount: 2,
            extraFloors: [BalanceFixture.upperFloor(staffCount: 1, config: config)],
            config: config
        )
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["hire", "equip", "branch"]

        guard let ground = state.floors.first, let upper = state.floors.last else {
            return XCTFail("iki kat olmalı")
        }
        XCTAssertEqual(GameEngine.processBonus(for: ground, state: state, config: config), 1.3, accuracy: 0.0001)
        XCTAssertEqual(GameEngine.processBonus(for: upper, state: state, config: config), 1, accuracy: 0.0001)
    }

    func testRulesWithoutAManagerDoNothing() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(staffCount: 2, config: config)
        state.hasRoof = true
        // Müdür yok ama kayıtta kural duruyor: eski bir kayıt böyle gelebilir.
        state.activeRules["coffee"] = ["hire", "equip", "branch"]

        XCTAssertTrue(state.rules(for: "coffee").isEmpty)
        guard let ground = state.floors.first else { return XCTFail("zemin kat olmalı") }
        XCTAssertEqual(GameEngine.processBonus(for: ground, state: state, config: config), 1, accuracy: 0.0001)

        XCTAssertEqual(
            GameEngine.setRule("hire", enabled: true, forSector: "coffee", state, config: config),
            .failure(.roofRequired)
        )
    }

    func testUnknownRuleIsRejected() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(config: config)
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        XCTAssertEqual(
            GameEngine.setRule("teleport", enabled: true, forSector: "coffee", state, config: config),
            .failure(.unknownRule)
        )
    }

    func testTogglingARuleIsFreeAndReversible() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(money: 500, config: config)
        state.hasRoof = true
        state.managedSectors = ["coffee"]

        guard case .success(let on) = GameEngine.setRule("hire", enabled: true, forSector: "coffee", state, config: config) else {
            return XCTFail("kural açılmalıydı")
        }
        XCTAssertEqual(on.money, 500, accuracy: 0.0001)
        XCTAssertEqual(on.rules(for: "coffee"), ["hire"])

        guard case .success(let off) = GameEngine.setRule("hire", enabled: false, forSector: "coffee", on, config: config) else {
            return XCTFail("kural kapanmalıydı")
        }
        XCTAssertTrue(off.rules(for: "coffee").isEmpty)

        // İki kez açmak kuralı iki kez saymamalı — bonus çift yazılmasın.
        guard case .success(let again) = GameEngine.setRule("hire", enabled: true, forSector: "coffee", on, config: config) else {
            return XCTFail("kural açılmalıydı")
        }
        XCTAssertEqual(again.rules(for: "coffee"), ["hire"])
    }

    // MARK: - Otomasyon

    func testHireRuleBuysTheNextPerson() {
        let config = BalanceFixture.config(baseCost: 100, costGrowth: 2)
        var state = BalanceFixture.state(money: 100, config: config)
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["hire"]

        let outcome = GameEngine.applyRules(state, config: config)
        XCTAssertEqual(outcome.state.floors[0].staff.count, 1)
        XCTAssertEqual(outcome.actions.count, 1)
        XCTAssertEqual(outcome.actions.first?.rule, "hire")
        XCTAssertEqual(outcome.actions.first?.sectorID, "coffee")
        XCTAssertEqual(outcome.actions.first?.detail, "quick")
        XCTAssertEqual(outcome.state.stats.automatedActions, 1)
    }

    func testAutomationLeavesTheCashReserveAlone() {
        // Yedek: mevcut netin 100 saniyesi. Elemanı olan bir katta net 1/sn.
        let config = BalanceFixture.config(baseCost: 100, reserveSeconds: 100)
        var state = BalanceFixture.state(money: 150, staffCount: 1, config: config)
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["hire", "equip", "branch"]

        // Net 1/sn → yedek 100. Öğütücünün ikinci seviyesi 50, kasada 150 var:
        // 150 − 50 = 100 ≥ 100 olduğu için sadece o alınır, sonrası yedeği deler.
        let outcome = GameEngine.applyRules(state, config: config)
        XCTAssertGreaterThanOrEqual(outcome.state.money, 100)
        XCTAssertEqual(outcome.state.floors[0].staff.count, 1, "yedeği delen alım yapılmamalı")
    }

    func testAutomationIsBoundedPerVisit() {
        let config = BalanceFixture.config(baseCost: 1, costGrowth: 1, maxStaff: 3, maxActionsPerVisit: 2)
        var state = BalanceFixture.state(money: 1_000_000, config: config)
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["hire", "equip", "branch"]

        let outcome = GameEngine.applyRules(state, config: config)
        XCTAssertEqual(outcome.actions.count, 2)
    }

    func testAutomationDoesNothingWithoutARoof() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(money: 1_000_000, config: config)
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["hire"]

        let outcome = GameEngine.applyRules(state, config: config)
        XCTAssertTrue(outcome.actions.isEmpty)
        XCTAssertEqual(outcome.state.floors[0].staff.count, 0)
    }

    /// Müdür asla oyuncunun kurmadığı bir kuralı işletmez.
    func testAutomationOnlyRunsEnabledRules() {
        let config = BalanceFixture.config(baseCost: 100)
        var state = BalanceFixture.state(money: 1_000_000, config: config)
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["equip"]

        let outcome = GameEngine.applyRules(state, config: config)
        XCTAssertEqual(outcome.state.floors[0].staff.count, 0, "kadro kuralı kapalıyken eleman alınmamalı")
        XCTAssertTrue(outcome.actions.allSatisfy { $0.rule == "equip" })
    }

    // MARK: - Olayların otomatik kararı

    func testBestChoicePicksTheMoreValuableOption() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(staffCount: 1, config: config)
        state.hasRoof = true

        guard let boost = config.events.specs.first(where: { $0.id == "boostEvent" }) else {
            return XCTFail("olay tanımı olmalı")
        }
        // Net 1/sn: ×3 × 60 sn = 120 fazladan, anlık seçenek 10 saniyelik = 10.
        XCTAssertEqual(GameEngine.bestChoice(for: boost, state, config: config)?.id, "boost")

        guard let cost = config.events.specs.first(where: { $0.id == "costEvent" }) else {
            return XCTFail("olay tanımı olmalı")
        }
        // Ceza olayında az zarar edeni seçer: −10 saniyelik, yavaşlatma −30.
        XCTAssertEqual(GameEngine.bestChoice(for: cost, state, config: config)?.id, "fine")
    }

    func testAutoResolveOnlyRunsWhenTheOwnerAsksForIt() {
        let config = BalanceFixture.config()
        var state = BalanceFixture.state(staffCount: 1, config: config)
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state = GameEngine.advance(state, by: 200, config: config)

        XCTAssertNotNil(GameEngine.pendingEvent(for: state, config: config))

        let untouched = GameEngine.applyRules(state, config: config)
        XCTAssertFalse(untouched.actions.contains { $0.rule == "event" })

        let opted = GameEngine.setAutoResolvesEvents(true, state)
        let handled = GameEngine.applyRules(opted, config: config)
        XCTAssertTrue(handled.actions.contains { $0.rule == "event" })
        XCTAssertNil(GameEngine.pendingEvent(for: handled.state, config: config))
    }

    // MARK: - Kayıt

    func testProcessStateSurvivesASaveRoundTrip() throws {
        var state = BalanceFixture.state(money: 500, config: BalanceFixture.config())
        state.hasRoof = true
        state.managedSectors = ["coffee"]
        state.activeRules["coffee"] = ["hire", "branch"]
        state.autoResolvesEvents = true
        state.stats.automatedActions = 7

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)

        XCTAssertTrue(restored.hasRoof)
        XCTAssertEqual(restored.managedSectors, ["coffee"])
        XCTAssertEqual(restored.rules(for: "coffee"), ["hire", "branch"])
        XCTAssertTrue(restored.autoResolvesEvents)
        XCTAssertEqual(restored.stats.automatedActions, 7)
    }

    /// Faz 4 kaydı Faz 5 motorunda açılmalı: süreç alanları kapalı gelir.
    func testOlderSaveOpensWithTheProcessLayerClosed() throws {
        let older = """
        {
          "schemaVersion": 5,
          "characterID": "kahveci",
          "money": 42,
          "lifetimeEarnings": 42,
          "elapsedGameSeconds": 10,
          "lastSeenAt": 0,
          "warehouseLevel": 0,
          "selectedFloor": 0,
          "eventSeed": 12345,
          "floors": [{ "sectorID": "coffee", "staff": [], "equipmentLevels": {}, "branchCount": 1 }]
        }
        """
        guard let data = older.data(using: .utf8) else { return XCTFail("veri kurulamadı") }
        let state = try JSONDecoder().decode(GameState.self, from: data)

        XCTAssertFalse(state.hasRoof)
        XCTAssertTrue(state.managedSectors.isEmpty)
        XCTAssertTrue(state.activeRules.isEmpty)
        XCTAssertFalse(state.autoResolvesEvents)
        XCTAssertEqual(state.money, 42, accuracy: 0.0001)
    }

    // MARK: - Gönderilen denge

    func testShippedBalanceDescribesTheProcessLayer() throws {
        let config = try loadShippedConfig()
        XCTAssertGreaterThan(config.process.roofCost, 0)
        XCTAssertGreaterThan(config.process.managerBaseCost, 0)
        XCTAssertGreaterThanOrEqual(config.process.managerCostGrowth, 1)
        XCTAssertFalse(config.process.rules.isEmpty)
        // Tavan rapor §4'ün söylediği %30'u aşmasın.
        XCTAssertLessThanOrEqual(config.process.maxBonus, 0.3)
        // Her kural motorun tanıdığı bir tarif olmalı.
        for rule in config.process.rules {
            XCTAssertTrue(["hire", "equip", "branch"].contains(rule.id), "tanınmayan kural: \(rule.id)")
        }
    }

    private func loadShippedConfig() throws -> BalanceConfig {
        if let config = try? BalanceConfig.load(in: .main) { return config }
        return try BalanceConfig.load(in: Bundle(for: Self.self))
    }
}
