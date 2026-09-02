import XCTest
@testable import NotOnMyShift

/// Ekonominin tamamı burada, UI olmadan ölçülüyor.
/// `GameEngine` saf olduğu için her testi tek satırda kurabiliyoruz.
final class GameEngineTests: XCTestCase {

    private let config = BalanceFixture.config()

    // MARK: - İlerleme

    func testAdvanceOneSecondCreditsOneSecondOfProduction() {
        let state = BalanceFixture.state(staffCount: 1, config: config)   // çarpan 1.0, oran 1/sn

        let next = GameEngine.advance(state, by: 1, config: config)

        XCTAssertEqual(next.money, 1.0, accuracy: 1e-9)
        XCTAssertEqual(next.lifetimeEarnings, 1.0, accuracy: 1e-9)
        XCTAssertEqual(next.elapsedGameSeconds, 1.0, accuracy: 1e-9)
    }

    func testAdvanceWithoutStaffEarnsNothing() {
        // Çağ 0: iş sensiz yürümüyor, dolayısıyla çevrimdışı kazanç da yok.
        let state = BalanceFixture.state(config: config)

        let next = GameEngine.advance(state, by: 3_600, config: config)

        XCTAssertEqual(next.money, 0)
        XCTAssertEqual(next.elapsedGameSeconds, 3_600, accuracy: 1e-9)
    }

    func testAdvanceIsClosedFormNotALoop() {
        // Bir kerede 1 saat ilerletmek ile 3600 kez 1 saniye ilerletmek aynı
        // sonucu vermeli. Kapalı-form kuralının kanıtı.
        let state = BalanceFixture.state(staffCount: 2, config: config)

        let single = GameEngine.advance(state, by: 3_600, config: config)

        var stepped = state
        for _ in 0..<3_600 {
            stepped = GameEngine.advance(stepped, by: 1, config: config)
        }

        XCTAssertEqual(single.money, stepped.money, accuracy: 1e-6)
        XCTAssertEqual(single.elapsedGameSeconds, stepped.elapsedGameSeconds, accuracy: 1e-6)
    }

    func testAdvanceIgnoresZeroAndNonFiniteDurations() {
        let state = BalanceFixture.state(money: 42, staffCount: 1, config: config)

        XCTAssertEqual(GameEngine.advance(state, by: 0, config: config), state)
        XCTAssertEqual(GameEngine.advance(state, by: -5, config: config), state)
        XCTAssertEqual(GameEngine.advance(state, by: .infinity, config: config), state)
        XCTAssertEqual(GameEngine.advance(state, by: .nan, config: config), state)
    }

    // MARK: - Çevrimdışı

    func testEightHoursOfflineIsCreditedWhenWarehouseIsBigEnough() {
        // Seviye 1 deposu 8 saat tutar.
        let state = BalanceFixture.state(staffCount: 1, warehouseLevel: 1, config: config)
        let eightHours: TimeInterval = 8 * 3_600

        let outcome = GameEngine.resume(
            state,
            at: BalanceFixture.epoch.addingTimeInterval(eightHours),
            mode: .awayFromApp,
            config: config
        )

        XCTAssertEqual(outcome.creditedSeconds, eightHours, accuracy: 1e-9)
        XCTAssertEqual(outcome.wastedSeconds, 0, accuracy: 1e-9)
        XCTAssertEqual(outcome.earned, eightHours, accuracy: 1e-6)     // 1 ₺/sn
        XCTAssertFalse(outcome.didFillWarehouse)
        XCTAssertTrue(outcome.shouldShowReport)
        XCTAssertEqual(outcome.state.stats.offlineReturns, 1)
    }

    func testOfflineEarningsAreCappedByWarehouseCapacity() {
        // Seviye 0 deposu 1 saat tutar; 8 saat uzakta kalınca 7 saat yanmalı.
        let state = BalanceFixture.state(staffCount: 1, warehouseLevel: 0, config: config)
        let eightHours: TimeInterval = 8 * 3_600

        let outcome = GameEngine.resume(
            state,
            at: BalanceFixture.epoch.addingTimeInterval(eightHours),
            mode: .awayFromApp,
            config: config
        )

        XCTAssertEqual(outcome.elapsedSeconds, eightHours, accuracy: 1e-9)
        XCTAssertEqual(outcome.creditedSeconds, 3_600, accuracy: 1e-9)
        XCTAssertEqual(outcome.wastedSeconds, eightHours - 3_600, accuracy: 1e-9)
        XCTAssertEqual(outcome.earned, 3_600, accuracy: 1e-6)
        XCTAssertTrue(outcome.didFillWarehouse)
        XCTAssertEqual(outcome.state.stats.wastedOfflineSeconds, eightHours - 3_600, accuracy: 1e-9)
        // Kesilen süre de tüketilmiş sayılır: tekrar dönünce yeniden yazılmaz.
        XCTAssertEqual(
            outcome.state.lastSeenAt.timeIntervalSince1970,
            BalanceFixture.epoch.addingTimeInterval(eightHours).timeIntervalSince1970,
            accuracy: 1e-6
        )
    }

    func testLiveModeIsNotCapped() {
        // Uygulama açıkken tavan uygulanmaz; tavan sadece uzakta geçen süre içindir.
        let state = BalanceFixture.state(staffCount: 1, warehouseLevel: 0, config: config)
        let twoHours: TimeInterval = 2 * 3_600

        let outcome = GameEngine.resume(
            state,
            at: BalanceFixture.epoch.addingTimeInterval(twoHours),
            mode: .live,
            config: config
        )

        XCTAssertEqual(outcome.creditedSeconds, twoHours, accuracy: 1e-9)
        XCTAssertEqual(outcome.earned, twoHours, accuracy: 1e-6)
        XCTAssertFalse(outcome.shouldShowReport)
    }

    func testShortAbsenceDoesNotShowReport() {
        // Uygulama değiştiriciye bakıp dönmek "dönüş özeti" hak etmez.
        let state = BalanceFixture.state(staffCount: 1, warehouseLevel: 1, config: config)

        let outcome = GameEngine.resume(
            state,
            at: BalanceFixture.epoch.addingTimeInterval(30),
            mode: .awayFromApp,
            config: config
        )

        XCTAssertGreaterThan(outcome.earned, 0)
        XCTAssertFalse(outcome.shouldShowReport)
        XCTAssertEqual(outcome.state.stats.offlineReturns, 0)
    }

    // MARK: - Saat manipülasyonu

    func testNegativeElapsedEarnsNothingButStillMovesLastSeen() {
        let state = BalanceFixture.state(money: 500, staffCount: 1, warehouseLevel: 1, config: config)
        let pastMoment = BalanceFixture.epoch.addingTimeInterval(-3_600)

        let outcome = GameEngine.resume(state, at: pastMoment, mode: .awayFromApp, config: config)

        XCTAssertTrue(outcome.clockWentBackwards)
        XCTAssertEqual(outcome.elapsedSeconds, 0)
        XCTAssertEqual(outcome.earned, 0)
        XCTAssertEqual(outcome.state.money, 500)
        XCTAssertEqual(
            outcome.state.lastSeenAt.timeIntervalSince1970,
            pastMoment.timeIntervalSince1970,
            accuracy: 1e-6
        )
    }

    func testClockRollbackCannotBeFarmed() {
        // Saati geri al, sonra ileri al: elde edilen para, saat hiç oynanmamış
        // gibi davranıldığındakinden fazla olmamalı.
        let start = BalanceFixture.state(staffCount: 1, warehouseLevel: 1, config: config)

        let rolledBack = GameEngine.resume(
            start,
            at: BalanceFixture.epoch.addingTimeInterval(-7_200),
            mode: .awayFromApp,
            config: config
        ).state

        let returned = GameEngine.resume(
            rolledBack,
            at: BalanceFixture.epoch.addingTimeInterval(600),
            mode: .awayFromApp,
            config: config
        ).state

        // Sunucu yok, mükemmel koruma da yok. Verdiğimiz garanti şu: saati ileri
        // geri oynatarak tek dönüşte bir depo dolusundan fazlası alınamaz.
        XCTAssertLessThanOrEqual(returned.money, GameEngine.offlineCapacitySeconds(for: start, config: config))
    }

    // MARK: - Eleman

    func testHiringDeductsCostAndIncreasesProduction() {
        var state = BalanceFixture.state(money: 1_000, config: config)
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 0)

        guard case .success(let afterFirst) = GameEngine.hireStaff(state, config: config) else {
            return XCTFail("İlk eleman alınamadı")
        }
        state = afterFirst

        XCTAssertEqual(state.money, 900, accuracy: 1e-9)              // taban ücret 100
        XCTAssertEqual(state.staff.count, 1)
        XCTAssertEqual(state.staff[0].id, "quick")
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 1.0, accuracy: 1e-9)
        XCTAssertTrue(state.isAutomated)

        guard case .success(let afterSecond) = GameEngine.hireStaff(state, config: config) else {
            return XCTFail("İkinci eleman alınamadı")
        }
        state = afterSecond

        XCTAssertEqual(state.money, 700, accuracy: 1e-9)              // 100 * 2^1 = 200
        // İkinci elemanın çarpanı 2.0 → toplam oran 1.0 + 2.0
        XCTAssertEqual(GameEngine.productionRate(for: state, config: config), 3.0, accuracy: 1e-9)
    }

    func testHiringFailsWithoutEnoughMoney() {
        let state = BalanceFixture.state(money: 99, config: config)

        guard case .failure(let error) = GameEngine.hireStaff(state, config: config) else {
            return XCTFail("Para yetmezken alım başarılı olmamalı")
        }
        XCTAssertEqual(error, .insufficientFunds)
    }

    func testStaffLimitIsRespected() {
        let state = BalanceFixture.state(money: 1_000_000, staffCount: 3, config: config)

        XCTAssertNil(GameEngine.hireCost(for: state, config: config))
        guard case .failure(let error) = GameEngine.hireStaff(state, config: config) else {
            return XCTFail("Kadro doluyken alım başarılı olmamalı")
        }
        XCTAssertEqual(error, .staffLimitReached)
    }

    func testHireCostFollowsGrowthCurve() {
        for count in 0..<3 {
            let state = BalanceFixture.state(staffCount: count, config: config)
            XCTAssertEqual(
                GameEngine.hireCost(for: state, config: config) ?? -1,
                100 * pow(2.0, Double(count)),
                accuracy: 1e-9
            )
        }
    }

    // MARK: - Depo

    func testWarehouseUpgradeRaisesOfflineCapacity() {
        var state = BalanceFixture.state(money: 500, config: config)
        XCTAssertEqual(GameEngine.offlineCapacitySeconds(for: state, config: config), 3_600)

        guard case .success(let upgraded) = GameEngine.upgradeWarehouse(state, config: config) else {
            return XCTFail("Depo yükseltilemedi")
        }
        state = upgraded

        XCTAssertEqual(state.money, 0, accuracy: 1e-9)
        XCTAssertEqual(state.warehouseLevel, 1)
        XCTAssertEqual(GameEngine.offlineCapacitySeconds(for: state, config: config), 28_800)
    }

    func testWarehouseStopsAtLastLevel() {
        let state = BalanceFixture.state(money: 1_000_000, warehouseLevel: 2, config: config)

        XCTAssertNil(GameEngine.warehouseUpgradeCost(for: state, config: config))
        guard case .failure(let error) = GameEngine.upgradeWarehouse(state, config: config) else {
            return XCTFail("Son seviyede yükseltme başarılı olmamalı")
        }
        XCTAssertEqual(error, .maxLevelReached)
    }

    // MARK: - Elle satış

    func testManualSaleAddsRevenueAndCountsUp() {
        let state = BalanceFixture.state(config: config)

        let next = GameEngine.sellManually(state, config: config)

        XCTAssertEqual(next.money, 10, accuracy: 1e-9)
        XCTAssertEqual(next.lifetimeEarnings, 10, accuracy: 1e-9)
        XCTAssertEqual(next.stats.manualSales, 1)
        XCTAssertEqual(next.elapsedGameSeconds, 0)   // elle satış zamanı ilerletmez
    }

    // MARK: - Gönderilen denge dosyası

    func testShippedBalanceParsesAndIsSane() throws {
        let config = try loadShippedConfig()

        XCTAssertFalse(config.sector.id.isEmpty)
        XCTAssertGreaterThan(config.manual.revenuePerSale, 0)
        XCTAssertGreaterThan(config.staff.ratePerSecond, 0)
        XCTAssertGreaterThan(config.staff.baseCost, 0)
        XCTAssertGreaterThan(config.staff.costGrowth, 1, "Ücret eğrisi artmıyorsa oyun kırılır")
        XCTAssertFalse(config.warehouse.levels.isEmpty)
        XCTAssertEqual(config.warehouse.levels.first?.cost, 0, "İlk depo seviyesi bedava olmalı")
        XCTAssertEqual(config.warehouse.levels.last?.capacitySeconds, 86_400, "Tasarım hedefi 24 saat")

        // Kapasite ve ücret monoton artmalı.
        for (previous, next) in zip(config.warehouse.levels, config.warehouse.levels.dropFirst()) {
            XCTAssertGreaterThan(next.capacitySeconds, previous.capacitySeconds)
            XCTAssertGreaterThan(next.cost, previous.cost)
        }

        // Havuz, kadro sınırını doldurmaya yetmeli — isimsiz eleman olmayacak.
        XCTAssertGreaterThanOrEqual(config.staffPool.count, config.staff.maxCount)
        XCTAssertEqual(Set(config.staffPool.map(\.id)).count, config.staffPool.count, "Eleman kimlikleri benzersiz olmalı")
        for template in config.staffPool {
            XCTAssertGreaterThan(template.rateMultiplier, 0)
            // İsim ve huy dil dosyalarından geliyor; kimliğin karşılığı olmalı.
            XCTAssertNotEqual(
                L.staffName(template.id), L.staffName("__yok__"),
                "'\(template.id)' için dil dosyasında isim yok"
            )
            XCTAssertNotEqual(
                L.staffTrait(template.id), L.staffTrait("__yok__"),
                "'\(template.id)' için dil dosyasında huy yok"
            )
        }
    }

    private func loadShippedConfig() throws -> BalanceConfig {
        if let config = try? BalanceConfig.load(in: .main) { return config }
        return try BalanceConfig.load(in: Bundle(for: Self.self))
    }
}
