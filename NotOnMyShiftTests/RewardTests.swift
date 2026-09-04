import XCTest
@testable import NotOnMyShift

/// Faz 7: isteğe bağlı ödüller ve tek seferlik "Reklamsız" alımı.
///
/// Rapor §8'in iki kuralı burada korunuyor:
/// 1. Ödül **asla zorunlu değildir** — hiç almayan oyuncu oyunu tam oynar.
/// 2. Satın alan oyuncu ödülleri **otomatik** alır; para veren, reklam
///    izleyenden yavaş kalmaz.
@MainActor
final class RewardTests: XCTestCase {

    // MARK: - Motor

    func testDoublingOfflineEarningsAddsTheSameAmountAgain() {
        let config = BalanceFixture.config(offlineRewardMultiplier: 2)
        let state = BalanceFixture.state(money: 500, staffCount: 1, config: config)

        let doubled = GameEngine.grantOfflineBonus(state, earned: 300, config: config)
        XCTAssertEqual(doubled.money, 800, accuracy: 1e-9)
        XCTAssertEqual(doubled.lifetimeEarnings - state.lifetimeEarnings, 300, accuracy: 1e-9)
        XCTAssertEqual(doubled.stats.rewardsClaimed, 1)
    }

    /// Ödül yoksa hiçbir şey eksilmez: çarpan 1 ise durum aynen kalır.
    func testOfflineBonusWithoutAMultiplierChangesNothing() {
        let config = BalanceFixture.config(offlineRewardMultiplier: 1)
        let state = BalanceFixture.state(money: 500, config: config)
        XCTAssertEqual(GameEngine.grantOfflineBonus(state, earned: 300, config: config), state)
        // Kazanç yoksa katlanacak bir şey de yok.
        XCTAssertEqual(GameEngine.grantOfflineBonus(state, earned: 0, config: BalanceFixture.config()), state)
    }

    func testShiftBoostMultipliesProductionForItsDuration() {
        let config = BalanceFixture.config(boostMultiplier: 3, boostSeconds: 60)
        let state = BalanceFixture.state(staffCount: 1, config: config)
        let base = GameEngine.productionRate(for: state, config: config)

        let boosted = GameEngine.grantShiftBoost(state, config: config)
        XCTAssertEqual(GameEngine.productionRate(for: boosted, config: config), base * 3, accuracy: 1e-9)
        XCTAssertEqual(GameEngine.boostRemaining(in: boosted) ?? 0, 60, accuracy: 1e-9)
        XCTAssertEqual(boosted.stats.rewardsClaimed, 1)

        // Süre dolunca oran kendiliğinden eski hâline döner.
        let after = GameEngine.advance(boosted, by: 60, config: config)
        XCTAssertNil(GameEngine.boostRemaining(in: after))
        XCTAssertEqual(GameEngine.productionRate(for: after, config: config), base, accuracy: 1e-9)
    }

    /// Patlama `advance`'i döngüye çevirmez: bitişi bir kırılım noktasıdır.
    func testBoostIsCreditedAsASegmentNotATickLoop() {
        let config = BalanceFixture.config(boostMultiplier: 3, boostSeconds: 60)
        let state = BalanceFixture.state(staffCount: 1, config: config)
        let boosted = GameEngine.grantShiftBoost(state, config: config)

        // Taban 1/sn. 60 sn ×3 = 180, sonraki 40 sn ×1 = 40 → 220.
        let later = GameEngine.advance(boosted, by: 100, config: config)
        XCTAssertEqual(later.money - boosted.money, 220, accuracy: 1e-6)
    }

    func testTakingTheBoostTwiceRestartsItInsteadOfStacking() {
        let config = BalanceFixture.config(boostMultiplier: 3, boostSeconds: 60)
        let state = BalanceFixture.state(staffCount: 1, config: config)
        let once = GameEngine.grantShiftBoost(state, config: config)
        let moved = GameEngine.advance(once, by: 30, config: config)
        let twice = GameEngine.grantShiftBoost(moved, config: config)

        XCTAssertEqual(twice.modifiers.filter { $0.eventID == GameEngine.boostID }.count, 1)
        XCTAssertEqual(GameEngine.boostRemaining(in: twice) ?? 0, 60, accuracy: 1e-9)
        // Çarpan üst üste binmez.
        XCTAssertEqual(GameEngine.eventMultiplier(for: twice), 3, accuracy: 1e-9)
    }

    // MARK: - Sınır: ev yapımı sahne

    func testTheHouseAdSceneWaitsForItsAnswer() async {
        let ads = HouseAds(seconds: 1)
        XCTAssertTrue(ads.isReady)
        XCTAssertFalse(ads.isPresenting)

        async let rewarded = ads.present()
        // Sahne açılana kadar bekle, sonra ödülü ver.
        while !ads.isPresenting { await Task.yield() }
        XCTAssertFalse(ads.isReady, "sahne açıkken ikinci bir sahne açılmamalı")
        ads.finish(rewarded: true)

        let result = await rewarded
        XCTAssertTrue(result)
        XCTAssertFalse(ads.isPresenting)
        XCTAssertTrue(ads.isReady)
    }

    func testSkippingTheSceneGivesNoReward() async {
        let ads = HouseAds(seconds: 1)
        async let rewarded = ads.present()
        while !ads.isPresenting { await Task.yield() }
        ads.finish(rewarded: false)
        let result = await rewarded
        XCTAssertFalse(result)
    }

    func testNoAdsProviderNeverPresents() async {
        let ads = NoAds()
        XCTAssertFalse(ads.isReady)
        let rewarded = await ads.present()
        XCTAssertFalse(rewarded)
    }

    // MARK: - Store: ödül akışı

    func testWatchingTheSceneDoublesTheOfflineEarnings() async throws {
        try await withStore(ads: StubAds(rewards: true)) { store, clock in
            for _ in 0..<10 { store.sellManually() }
            store.hireStaff()

            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(300)
            store.handleBecameActive()

            let report = try XCTUnwrap(store.offlineReport)
            XCTAssertEqual(report.earned, 300, accuracy: 1e-6)
            XCTAssertTrue(store.canDoubleOffline)
            XCTAssertFalse(report.wasDoubled)

            await store.claimingOfflineDouble()

            XCTAssertEqual(store.state.money, 600, accuracy: 1e-6)
            XCTAssertEqual(store.offlineReport?.earned ?? 0, 600, accuracy: 1e-6)
            XCTAssertEqual(store.offlineReport?.wasDoubled, true)
            XCTAssertFalse(store.canDoubleOffline, "teklif bir kez")

            // İkinci kez çağırmak para eklemez.
            await store.claimingOfflineDouble()
            XCTAssertEqual(store.state.money, 600, accuracy: 1e-6)
        }
    }

    func testSkippingTheSceneLeavesTheEarningsAlone() async throws {
        let ads = StubAds(rewards: false)
        try await withStore(ads: ads) { store, clock in
            for _ in 0..<10 { store.sellManually() }
            store.hireStaff()
            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(300)
            store.handleBecameActive()

            await store.claimingOfflineDouble()

            XCTAssertEqual(ads.presentCount, 1, "sahne gerçekten gösterilmeli")
            XCTAssertEqual(store.state.money, 300, accuracy: 1e-6)
            XCTAssertTrue(store.canDoubleOffline, "geçen oyuncuya teklif açık kalır")
        }
    }

    /// Rapor §8'in kritik detayı: alan oyuncuya hiç sorulmaz.
    func testBuyerGetsTheOfflineDoubleWithoutBeingAsked() async throws {
        try await withStore(purchases: MemoryPurchases(hasRemovedAds: true), ads: NoAds()) { store, clock in
            for _ in 0..<10 { store.sellManually() }
            store.hireStaff()
            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(300)
            store.handleBecameActive()

            XCTAssertEqual(store.state.money, 600, accuracy: 1e-6)
            XCTAssertEqual(store.offlineReport?.wasDoubled, true)
            XCTAssertFalse(store.canDoubleOffline, "alan oyuncuya teklif gösterilmez")
        }
    }

    func testBuyerTakesTheBoostWithoutAScene() async throws {
        let ads = StubAds(rewards: true)
        try await withStore(purchases: MemoryPurchases(hasRemovedAds: true), ads: ads) { store, _ in
            XCTAssertTrue(store.showsRewards)
            XCTAssertTrue(store.canBoost)

            await store.claimingBoost()

            XCTAssertNotNil(store.boostRemaining)
            XCTAssertEqual(ads.presentCount, 0, "alan oyuncuya sahne gösterilmez")
            XCTAssertFalse(store.canBoost, "seans başına bir kez")
        }
    }

    func testTheBoostIsOncePerSessionAndComesBackNextSession() async throws {
        try await withStore(ads: StubAds(rewards: true)) { store, clock in
            await store.claimingBoost()
            XCTAssertNotNil(store.boostRemaining)
            XCTAssertFalse(store.canBoost)

            // Yeni seans: patlama süresi de dolmuş olsun.
            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(600)
            store.handleBecameActive()

            XCTAssertNil(store.boostRemaining)
            XCTAssertTrue(store.canBoost)
        }
    }

    /// Reklam da alım da yoksa ödül şeridi hiç görünmez — sessiz oyun.
    func testWithoutAdsOrAPurchaseNoRewardIsOffered() async throws {
        try await withStore(purchases: MemoryPurchases(hasRemovedAds: false), ads: NoAds()) { store, clock in
            XCTAssertFalse(store.showsRewards)
            XCTAssertFalse(store.canBoost)

            for _ in 0..<10 { store.sellManually() }
            store.hireStaff()
            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(300)
            store.handleBecameActive()

            XCTAssertFalse(store.canDoubleOffline)
            XCTAssertEqual(store.state.money, 300, accuracy: 1e-6, "ödül yokken oyun aynen yürür")
        }
    }

    // MARK: - Satın alma

    func testBuyingRemovesTheAdsAndUnlocksTheRewards() async throws {
        try await withStore(purchases: MemoryPurchases(hasRemovedAds: false), ads: NoAds()) { store, _ in
            XCTAssertFalse(store.hasRemovedAds)
            await store.buyingRemoveAds()
            XCTAssertTrue(store.hasRemovedAds)
            XCTAssertTrue(store.showsRewards)
            XCTAssertTrue(store.canBoost)
        }
    }

    /// Dönüş özeti açıkken satın alan oyuncu katlamayı hemen alır.
    func testBuyingDuringTheReturnScreenAppliesTheDoubleAtOnce() async throws {
        let purchases = MemoryPurchases(hasRemovedAds: false)
        try await withStore(purchases: purchases, ads: NoAds()) { store, clock in
            for _ in 0..<10 { store.sellManually() }
            store.hireStaff()
            store.handleWillResignActive()
            clock.date = BalanceFixture.epoch.addingTimeInterval(300)
            store.handleBecameActive()
            XCTAssertEqual(store.state.money, 300, accuracy: 1e-6)

            await store.buyingRemoveAds()

            XCTAssertEqual(store.state.money, 600, accuracy: 1e-6)
            XCTAssertEqual(store.offlineReport?.wasDoubled, true)
        }
    }

    func testAFailedPurchaseChangesNothingAndSaysSo() async throws {
        let purchases = MemoryPurchases(hasRemovedAds: false)
        purchases.failsToBuy = true
        try await withStore(purchases: purchases, ads: NoAds()) { store, _ in
            await store.buyingRemoveAds()
            XCTAssertFalse(store.hasRemovedAds)
            XCTAssertEqual(store.purchases.failureText, L.purchaseFailed)
        }
    }

    // MARK: - Gönderilen denge

    func testShippedBalanceKeepsTheRewardsOptionalAndModest() throws {
        let config = try loadShippedConfig()

        XCTAssertGreaterThan(config.rewards.offlineMultiplier, 1, "katlama bir şey vermeli")
        XCTAssertLessThanOrEqual(config.rewards.offlineMultiplier, 2, "ödül dengeyi devirmemeli")
        XCTAssertGreaterThan(config.rewards.boostMultiplier, 1)
        XCTAssertGreaterThan(config.rewards.boostSeconds, 0)

        // Patlama bir seansı domine etmemeli: en uzun olay etkisinden çok
        // uzun sürmesin, yoksa "ödül almadan oynanmaz" hissi doğar.
        let longestEvent = config.events.specs
            .flatMap(\.choices)
            .map(\.durationSeconds)
            .max() ?? 0
        XCTAssertLessThanOrEqual(config.rewards.boostSeconds, longestEvent * 2)
    }

    // MARK: - Yardımcı

    /// Sahte reklam sağlayıcı: sahne göstermeden anında cevap verir.
    @MainActor
    private final class StubAds: RewardedAds {
        let rewards: Bool
        private(set) var presentCount = 0
        init(rewards: Bool) { self.rewards = rewards }
        var isReady: Bool { true }
        func present() async -> Bool {
            presentCount += 1
            return rewards
        }
    }

    private func withStore(
        purchases: any Purchases = MemoryPurchases(),
        ads: any RewardedAds,
        _ body: (GameStore, TestClock) async throws -> Void
    ) async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "nomsreward-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let clock = TestClock(BalanceFixture.epoch)
        let store = GameStore(
            config: BalanceFixture.config(),
            saves: SaveStore(containerDirectory: directory),
            now: clock.provider,
            purchases: purchases,
            ads: ads
        )
        try await body(store, clock)
        store.handleWillResignActive()
    }

    private func loadShippedConfig() throws -> BalanceConfig {
        if let config = try? BalanceConfig.load(in: .main) { return config }
        return try BalanceConfig.load(in: Bundle(for: Self.self))
    }
}
