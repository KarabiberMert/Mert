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

    // MARK: - Yardımcı

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "nomsstore-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}

/// Testlerde saati elle ileri almak için. Üretimde `Date()` kullanılıyor.
private final class TestClock: @unchecked Sendable {

    private let lock = NSLock()
    private var storedDate: Date

    init(_ date: Date) {
        storedDate = date
    }

    var date: Date {
        get { lock.withLock { storedDate } }
        set { lock.withLock { storedDate = newValue } }
    }

    var provider: @Sendable () -> Date {
        { [self] in date }
    }
}
