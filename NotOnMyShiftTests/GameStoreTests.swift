import Foundation
import XCTest
@testable import NotOnMyShift

/// Sahne fazı akışı: uygulama arka plana gidip geri geldiğinde para doğru mu?
/// Saat enjekte edildiği için gerçek zaman beklemeden ölçebiliyoruz.
///
/// Not: `setUp`/`tearDown` ezilmiyor. `XCTestCase` bunları nonisolated tanımlar;
/// `@MainActor` bir sınıfta ezmek Swift 6'da izolasyon uyuşmazlığı olur.
/// Onun yerine her test kendi geçici klasörünü kurup temizliyor.
@MainActor
final class GameStoreTests: XCTestCase {

    func testReturningAfterFiveMinutesCreditsOfflineEarnings() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config()
            let clock = TestClock(BalanceFixture.epoch)
            let store = GameStore(
                config: config,
                saves: SaveStore(containerDirectory: directory),
                now: clock.provider
            )

            // Çağ 0 → Çağ 1: elle biriktir, ilk elemanı tut.
            for _ in 0..<10 { store.sellManually() }          // 10 x 10 ₺ = 100 ₺
            store.hireStaff()
            XCTAssertEqual(store.state.floors[0].staff.count, 1)
            XCTAssertEqual(store.state.money, 0, accuracy: 1e-9)

            // Uygulamayı kapat, beş dakika sonra dön.
            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(300)
            store.handleBecameActive()

            XCTAssertEqual(store.state.money, 300, accuracy: 1e-6)   // 1 ₺/sn
            XCTAssertNotNil(store.offlineReport)
            XCTAssertEqual(store.offlineReport?.earned ?? 0, 300, accuracy: 1e-6)

            store.handleWillResignActive()                            // zamanlayıcıyı durdur
        }
    }

    func testProgressSurvivesRelaunch() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config()
            let saves = SaveStore(containerDirectory: directory)
            let clock = TestClock(BalanceFixture.epoch)

            let first = GameStore(config: config, saves: saves, now: clock.provider)
            for _ in 0..<25 { first.sellManually() }                  // 250 ₺
            first.hireStaff()                                         // -100 ₺
            first.handleWillResignActive()                            // kaydeder

            // Uygulama öldürüldü, yeniden açıldı.
            let second = GameStore(config: config, saves: saves, now: clock.provider)

            XCTAssertEqual(second.state.money, 150, accuracy: 1e-6)
            XCTAssertEqual(second.state.floors[0].staff.count, 1)
            XCTAssertEqual(second.state.stats.manualSales, 25)
        }
    }

    func testOfflineEarningsStopAtWarehouseCapacity() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config()
            let clock = TestClock(BalanceFixture.epoch)
            let store = GameStore(
                config: config,
                saves: SaveStore(containerDirectory: directory),
                now: clock.provider
            )

            for _ in 0..<10 { store.sellManually() }
            store.hireStaff()
            store.handleWillResignActive()

            // Seviye 0 deposu bir saat tutar; iki gün uzakta kal.
            clock.date = BalanceFixture.epoch.addingTimeInterval(48 * 3_600)
            store.handleBecameActive()

            XCTAssertEqual(store.state.money, 3_600, accuracy: 1e-6)
            XCTAssertTrue(store.offlineReport?.didFillWarehouse == true)

            store.handleWillResignActive()
        }
    }

    func testFirstHireCelebrationFiresOnceAndOnlyOnce() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config()
            let saves = SaveStore(containerDirectory: directory)
            let store = GameStore(config: config, saves: saves, now: { BalanceFixture.epoch })

            XCTAssertNil(store.firstHireCelebration)

            for _ in 0..<10 { store.sellManually() }        // 100 ₺
            store.hireStaff()

            XCTAssertEqual(store.firstHireCelebration?.id, "quick")
            XCTAssertTrue(store.state.hasCelebratedFirstHire)
            store.dismissFirstHireCelebration()

            for _ in 0..<20 { store.sellManually() }        // ikinci eleman 200 ₺
            store.hireStaff()

            XCTAssertEqual(store.state.floors[0].staff.count, 2)
            XCTAssertNil(store.firstHireCelebration, "Çağ 1 anı ikinci kez oynatılmamalı")

            // Uygulama yeniden açıldığında da tekrar etmemeli.
            let relaunched = GameStore(config: config, saves: saves, now: { BalanceFixture.epoch })
            XCTAssertNil(relaunched.firstHireCelebration)
            XCTAssertTrue(relaunched.state.hasCelebratedFirstHire)
        }
    }

    func testManualSalesUntilHireCountsDownAndStopsAfterAutomation() async throws {
        try await withTemporaryDirectory { directory in
            let store = GameStore(
                config: BalanceFixture.config(),        // 10 ₺/dokunuş, ilk eleman 100 ₺
                saves: SaveStore(containerDirectory: directory),
                now: { BalanceFixture.epoch }
            )

            XCTAssertEqual(store.manualSalesUntilHire, 10)
            for _ in 0..<3 { store.sellManually() }
            XCTAssertEqual(store.manualSalesUntilHire, 7)

            for _ in 0..<7 { store.sellManually() }
            XCTAssertNil(store.manualSalesUntilHire, "Para yettiğinde geri sayım biter")

            store.hireStaff()
            XCTAssertNil(store.manualSalesUntilHire, "Çağ 1'de elle satış artık hedef değil")
        }
    }

    func testOpeningAFloorSelectsItAndRaisesTheCelebration() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config(upperUnlockCost: 1_000)
            let store = GameStore(
                config: config,
                saves: SaveStore(containerDirectory: directory),
                now: { BalanceFixture.epoch }
            )

            XCTAssertEqual(store.floors.count, 1)
            XCTAssertEqual(store.nextFloorCost, 1_000)

            // Para yetmiyorsa kat açılmaz.
            store.unlockNextFloor()
            XCTAssertEqual(store.floors.count, 1)
            XCTAssertNil(store.newFloorCelebration)

            for _ in 0..<120 { store.sellManually() }        // 120 × 10 = 1.200
            store.unlockNextFloor()

            XCTAssertEqual(store.floors.count, 2)
            XCTAssertEqual(store.selectedFloor, 1, "Açtığın katın başında ol")
            XCTAssertEqual(store.newFloorCelebration, "bakery")
            XCTAssertEqual(store.currentSpec?.id, "bakery")
            // Panel artık üst katın sayılarıyla çalışır.
            XCTAssertEqual(store.manualRevenue, 100, accuracy: 1e-9)

            store.dismissNewFloorCelebration()
            store.selectFloor(0)
            XCTAssertEqual(store.manualRevenue, 10, accuracy: 1e-9)

            store.handleWillResignActive()
        }
    }

    func testStartOverClearsEverything() async throws {
        try await withTemporaryDirectory { directory in
            let store = GameStore(
                config: BalanceFixture.config(),
                saves: SaveStore(containerDirectory: directory),
                now: { BalanceFixture.epoch }
            )

            for _ in 0..<10 { store.sellManually() }
            store.hireStaff()
            store.startOver()

            XCTAssertEqual(store.state.money, 0, accuracy: 1e-9)
            XCTAssertTrue(store.state.floors[0].staff.isEmpty)
            XCTAssertEqual(store.state.stats.manualSales, 0)

            store.handleWillResignActive()
        }
    }

    // MARK: - Süreç katmanı

    /// Müdür sen yokken çalışır ve döndüğünde raporunu verir.
    func testManagersWorkWhileYouAreAwayAndReportOnReturn() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config(baseCost: 100, roofCost: 100, managerBaseCost: 100)
            let clock = TestClock(BalanceFixture.epoch)
            let store = GameStore(
                config: config,
                saves: SaveStore(containerDirectory: directory),
                now: clock.provider
            )

            for _ in 0..<30 { store.sellManually() }   // 300 ₺
            store.unlockRoof()                          // -100 ₺
            store.hireManager()                         // -100 ₺
            store.setRule("hire", enabled: true)
            XCTAssertTrue(store.hasRoof)
            XCTAssertTrue(store.hasManagerOnSelectedFloor)
            XCTAssertTrue(store.isRuleActive("hire"))
            XCTAssertEqual(store.state.floors[0].staff.count, 0)

            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(300)
            store.handleBecameActive()

            // Kasadaki para ilk elemana yetiyordu; müdür sen yokken onu tuttu.
            XCTAssertEqual(store.state.floors[0].staff.count, 1)
            XCTAssertFalse(store.managerReport.isEmpty)
            XCTAssertEqual(store.managerReport.first?.rule, "hire")

            store.dismissManagerReport()
            XCTAssertTrue(store.managerReport.isEmpty)

            store.handleWillResignActive()
        }
    }

    /// Kural koymayan oyuncu hiçbir şey kaybetmez — çatı açmak tek başına
    /// ne üretimi değiştirir ne de kadroya dokunur.
    func testOpeningTheRoofAloneChangesNothingButTheDoor() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config(roofCost: 100)
            let store = GameStore(
                config: config,
                saves: SaveStore(containerDirectory: directory),
                now: { BalanceFixture.epoch }
            )

            for _ in 0..<20 { store.sellManually() }
            store.hireStaff()                            // -100 ₺, kalan 100 ₺
            let before = store.productionRate

            store.unlockRoof()
            XCTAssertTrue(store.hasRoof)
            XCTAssertEqual(store.productionRate, before, accuracy: 1e-9)
            XCTAssertEqual(store.processBonus, 1, accuracy: 1e-9)
            XCTAssertFalse(store.hasManagerOnSelectedFloor)

            store.handleWillResignActive()
        }
    }

    /// Müdüre kararı devreden oyuncuya olay kartı gösterilmez.
    func testAutoResolveKeepsTheEventCardOffTheScreen() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config(baseCost: 100, roofCost: 100)
            let clock = TestClock(BalanceFixture.epoch)
            let store = GameStore(
                config: config,
                saves: SaveStore(containerDirectory: directory),
                now: clock.provider
            )

            for _ in 0..<20 { store.sellManually() }
            store.hireStaff()
            store.unlockRoof()
            store.setAutoResolvesEvents(true)

            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(300)
            store.handleBecameActive()

            XCTAssertNil(store.pendingEvent, "karar müdürdeyse kart çıkmamalı")
            XCTAssertTrue(store.managerReport.contains { $0.rule == "event" })

            store.handleWillResignActive()
        }
    }

    // MARK: - Yumuşak prestij

    /// Satış üç şeyi birden verir ve hiçbiri geri alınmaz.
    func testSellingASectorPaysKeepsThePointAndLeavesTheFloorEarning() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config(payoutSeconds: 100, investmentShare: 0.1, multiplierPerPoint: 0.5)
            var seed = BalanceFixture.state(config: config)
            seed.floors = [BalanceFixture.matureFloor(config: config)]
            let saves = SaveStore(containerDirectory: directory)
            try saves.save(seed)

            let store = GameStore(config: config, saves: saves, now: { BalanceFixture.epoch })

            XCTAssertEqual(store.maturityProgress, 1, accuracy: 1e-9)
            XCTAssertEqual(store.saleValue ?? 0, 4_200, accuracy: 1e-6)
            XCTAssertEqual(store.saleInvestmentRate, 4.2, accuracy: 1e-9)

            store.sellSector()

            XCTAssertEqual(store.state.money, 4_200, accuracy: 1e-6)
            XCTAssertEqual(store.holdingPoints, 1)
            XCTAssertEqual(store.holdingMultiplier, 1.5, accuracy: 1e-9)
            XCTAssertEqual(store.sectorSaleCelebration, "coffee")
            XCTAssertTrue(store.isSelectedFloorSold)
            // Kat hâlâ ödüyor: 4,2/sn kira × 1,5 puan çarpanı.
            XCTAssertEqual(store.netRate(of: 0), 4.2, accuracy: 1e-9)
            XCTAssertEqual(store.productionRate, 6.3, accuracy: 1e-9)

            store.dismissSectorSaleCelebration()
            XCTAssertNil(store.sectorSaleCelebration)

            store.handleWillResignActive()
        }
    }

    func testAnUnfinishedFloorShowsProgressInsteadOfASalePrice() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config()
            let store = GameStore(
                config: config,
                saves: SaveStore(containerDirectory: directory),
                now: { BalanceFixture.epoch }
            )

            XCTAssertNil(store.saleValue)
            XCTAssertFalse(store.isSelectedFloorSold)
            XCTAssertGreaterThanOrEqual(store.maturityProgress, 0)
            XCTAssertLessThan(store.maturityProgress, 1)

            store.handleWillResignActive()
        }
    }

    /// Halka arz biten şehri özetler ve yeni şehri kurar.
    func testGoingPublicSummarisesTheCityThatEndedAndStartsTheNext() async throws {
        try await withTemporaryDirectory { directory in
            let config = BalanceFixture.config(pointsPerCity: 2)
            var seed = BalanceFixture.state(config: config)
            seed.floors = [
                BalanceFixture.matureFloor(config: config),
                BalanceFixture.matureFloor(sectorIndex: 1, config: config)
            ]
            seed.lifetimeEarnings = 50_000
            seed.stats.manualSales = 12
            seed.warehouseLevel = 1
            let saves = SaveStore(containerDirectory: directory)
            try saves.save(seed)

            let store = GameStore(config: config, saves: saves, now: { BalanceFixture.epoch })

            XCTAssertTrue(store.canGoPublic)
            store.goPublic()

            // Özet biten şehri anlatır.
            let finale = try XCTUnwrap(store.finale)
            XCTAssertEqual(finale.cityNumber, 1)
            XCTAssertEqual(finale.lifetimeEarnings, 50_000, accuracy: 1e-9)
            XCTAssertEqual(finale.manualSales, 12)
            XCTAssertEqual(finale.holdingPoints, 2)

            // Yeni şehir kuruldu; senin olan taşındı.
            XCTAssertEqual(store.cityNumber, 2)
            XCTAssertEqual(store.holdingPoints, 2)
            XCTAssertEqual(store.state.warehouseLevel, 1)
            XCTAssertEqual(store.floors.count, 1)
            XCTAssertFalse(store.canGoPublic)

            store.dismissFinale()
            XCTAssertNil(store.finale)

            store.handleWillResignActive()
        }
    }

    // MARK: - Yardımcı

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "nomsstore-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
