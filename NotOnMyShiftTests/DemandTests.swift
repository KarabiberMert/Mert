import Foundation
import XCTest
@testable import NotOnMyShift

/// Talep sistemi: dükkâna gelen müşteri akışı.
///
/// Talep **kapasiteye oranlı** ölçeklenir, yani tam kurulmuş bir dükkânın
/// geliri talep yüzünden çökmez. Sistem bir ödül/ceza bandı olarak çalışır:
/// hızlı servis kapsamayı yükseltir, biriken kuyruk düşürür — ama tabanın
/// altına inmez, çünkü oyuncu geri gitmez.
final class DemandTests: XCTestCase {

    /// Kapasite talebi aşarken üretim talebe takılır; kuyruk boş kalır.
    func testProductionIsCappedByDemandWhenCapacityExceedsIt() {
        // Kapasite: 1 eleman × 10 ₺/sn ÷ 10 ₺ satış = 1 satış/sn.
        // Talep: kapsama 0,25 → 0,25 satış/sn. Taban aralık uzun ki taban
        // devreye girmesin.
        let config = BalanceFixture.config(
            revenuePerSale: 10,
            ratePerSecond: 10,
            starterArrivalSeconds: 1_000_000,
            baseArrivalSeconds: 1_000_000,
            demandStartQueue: 0,
            startCoverage: 0.25,
            minCoverage: 0.25,
            maxCoverage: 0.25
        )
        let state = BalanceFixture.state(staffCount: 1, demandQueue: 0, config: config)

        let rate = GameEngine.productionRate(for: state, config: config)
        XCTAssertEqual(rate, 2.5, accuracy: 1e-6, "Üretim talebe takılmalı: 0,25 satış/sn × 10 ₺")

        let next = GameEngine.advance(state, by: 100, config: config)
        XCTAssertEqual(next.money, 250, accuracy: 1e-6)
        XCTAssertEqual(next.floors[0].demandQueue, 0, accuracy: 1e-6, "Kapasite fazlaysa kuyruk birikmez")
    }

    /// Talep kapasiteyi aşarken üretim kapasiteye takılır ve kuyruk birikir —
    /// ama sonsuza kadar değil, `λ·T` denge noktasında durur.
    func testQueueSettlesAtTheExpiryLimitWhenDemandExceedsCapacity() {
        let config = BalanceFixture.config(
            revenuePerSale: 10,
            ratePerSecond: 10,
            starterArrivalSeconds: 1_000_000,
            baseArrivalSeconds: 0.5,          // 2 satış/sn taban
            demandExpirySeconds: 60,
            demandStartQueue: 0,
            startCoverage: 1, minCoverage: 1, maxCoverage: 1
        )
        let state = BalanceFixture.state(staffCount: 1, demandQueue: 0, config: config)

        // Kapasite 1 satış/sn, geliş 2 satış/sn → fazlalık 1/sn, tavan 60.
        let next = GameEngine.advance(state, by: 10_000, config: config)
        XCTAssertEqual(next.floors[0].demandQueue, 60, accuracy: 0.5, "Kuyruk λ·T'de durur, sonsuza gitmez")
        // Üretim kapasiteye takılı kaldığı için gelir kapasite × süre.
        XCTAssertEqual(next.money, 10 * 10_000, accuracy: 1)
    }

    /// Çağ 0: kimse hizmet vermiyor. Kuyruk birikir ama bekleyenler kaçar.
    func testWithoutStaffTheQueueFillsAndOverflowLeaves() {
        let config = BalanceFixture.config(
            starterArrivalSeconds: 3,          // 1/3 satış/sn
            demandExpirySeconds: 60,
            demandStartQueue: 0,
            startCoverage: 1, minCoverage: 1, maxCoverage: 1
        )
        let state = BalanceFixture.state(staffCount: 0, demandQueue: 0, config: config)

        let next = GameEngine.advance(state, by: 10_000, config: config)
        XCTAssertEqual(next.floors[0].demandQueue, 20, accuracy: 0.5, "1/3 × 60 = 20 kişilik kapıda kuyruk")
        XCTAssertEqual(next.money, 0, accuracy: 1e-9, "Kadro yokken kimse satmaz")
    }

    /// Müşteri gelmeden elle satış olmaz; müşteri gelince olur.
    func testManualSaleNeedsAWaitingCustomer() {
        let config = BalanceFixture.config(
            starterArrivalSeconds: 10,
            demandStartQueue: 0,
            startCoverage: 1, minCoverage: 1, maxCoverage: 1
        )
        let bos = BalanceFixture.state(demandQueue: 0, config: config)

        let denendi = GameEngine.sellManually(onFloor: 0, bos, config: config)
        XCTAssertEqual(denendi.money, 0, accuracy: 1e-9, "Kuyruk boşken tezgâh para basmaz")
        XCTAssertEqual(denendi.stats.manualSales, 0)

        // 30 saniyede 3 müşteri gelir.
        let beklendi = GameEngine.advance(bos, by: 30, config: config)
        XCTAssertGreaterThanOrEqual(beklendi.floors[0].demandQueue, 1)

        let satildi = GameEngine.sellManually(onFloor: 0, beklendi, config: config)
        XCTAssertEqual(satildi.money, 10, accuracy: 1e-9)
        XCTAssertEqual(satildi.stats.manualSales, 1)
        XCTAssertEqual(
            satildi.floors[0].demandQueue,
            beklendi.floors[0].demandQueue - 1,
            accuracy: 1e-9,
            "Her satış bir müşteriyi kuyruktan alır"
        )
    }

    /// Yeni dükkânın kapısında hazır müşteri olur — uygulamayı açan oyuncu
    /// satacak kimse bulamazsa oyun başlamaz.
    func testNewShopOpensWithCustomersWaiting() {
        let config = BalanceFixture.config(demandStartQueue: 3)
        var state = GameState.newGame(characterID: "kahveci", now: BalanceFixture.epoch)
        state.floors[0].demandQueue = GameState.unset

        let normal = GameEngine.normalised(state, config: config)
        XCTAssertEqual(normal.floors[0].demandQueue, 3, accuracy: 1e-9)
    }

    /// Kuyruk hoşgörüyü aşınca kapsama iner, ama **tabanın altına inmez**.
    /// Rapor §6'nın ruhu: ihmal yavaşlatır, geri götürmez.
    func testCoverageFallsWithBacklogButNeverBelowTheFloor() {
        let config = BalanceFixture.config(
            minCoverage: 0.6,
            maxCoverage: 1.4,
            coveragePerSecond: 0.01,
            backlogToleranceSeconds: 20
        )

        // Kuyruk 100 kişi, kapasite 1 satış/sn → 100 saniyelik birikmiş iş.
        let dolu = GameEngine.nextCoverage(
            current: 1, queue: 100, capacity: 1, seconds: 1000, config: config
        )
        XCTAssertEqual(dolu, 0.6, accuracy: 1e-9, "Taban aşılmaz")

        // Kuyruk boş → kapsama tavana tırmanır.
        let bos = GameEngine.nextCoverage(
            current: 1, queue: 0, capacity: 1, seconds: 1000, config: config
        )
        XCTAssertEqual(bos, 1.4, accuracy: 1e-9, "Hızlı servis tavana kadar ödüllendirir")

        // Tek adımda uçmaz: hız dengede tanımlı.
        let yavas = GameEngine.nextCoverage(
            current: 1, queue: 0, capacity: 1, seconds: 10, config: config
        )
        XCTAssertEqual(yavas, 1.1, accuracy: 1e-9)
    }

    /// Kadro birikmiş kuyruğu **servis ederek** eritir — müşteriler kaçtığı
    /// için değil. Ölçüt para: eriyen kişi sayısı kadar satış yapılmış olmalı.
    func testStaffWorkThroughTheQueueAndGetPaidForIt() {
        // Kapasite 1 satış/sn (10 ₺/sn ÷ 10 ₺), geliş 0,5 satış/sn.
        // Taban aralık devre dışı ki kapsama belirleyici olsun.
        let config = BalanceFixture.config(
            revenuePerSale: 10,
            ratePerSecond: 10,
            starterArrivalSeconds: 1_000_000,
            baseArrivalSeconds: 1_000_000,
            demandStartQueue: 0,
            startCoverage: 0.5, minCoverage: 0.5, maxCoverage: 0.5
        )
        let state = BalanceFixture.state(staffCount: 1, demandQueue: 100, config: config)

        let next = GameEngine.advance(state, by: 100, config: config)

        // Kuyruk boşalma hızı = kapasite − geliş = 0,5 kişi/sn.
        XCTAssertEqual(next.floors[0].demandQueue, 50, accuracy: 1e-6, "Kadro kuyruğu eritmeli")
        // Ve tam kapasiteyle çalıştığı için 100 satış yapılmış olmalı.
        XCTAssertEqual(next.money, 1000, accuracy: 1e-6, "Eriyen müşteriler paraya dönmeli")
    }

    /// Kapsama tavanı 1'i geçmemeli. Geçerse kadronun boş kapasitesi kalmaz ve
    /// kuyruk yalnızca müşteriler kaçtığı için azalır — istediğimiz bu değil.
    func testShippedBalanceKeepsCoverageAtOrBelowFullCapacity() throws {
        let config = try BalanceConfig.load()
        XCTAssertLessThanOrEqual(config.demand.maxCoverage, 1.0)
        XCTAssertLessThanOrEqual(config.demand.startCoverage, config.demand.maxCoverage)
        XCTAssertLessThanOrEqual(config.demand.minCoverage, config.demand.startCoverage)
    }

    /// Sen yokken kadro talebi karşılar: çevrimdışı kazanç talep yüzünden
    /// çökmez. Ürün sahibinin seçtiği kural buydu.
    func testStaffKeepServingWhileYouAreAway() {
        let config = BalanceFixture.config(
            revenuePerSale: 10,
            ratePerSecond: 10,
            starterArrivalSeconds: 1,
            baseArrivalSeconds: 1,
            demandStartQueue: 0,
            startCoverage: 1, minCoverage: 1, maxCoverage: 1
        )
        let state = BalanceFixture.state(staffCount: 1, demandQueue: 0, config: config)

        // İki saat uzakta: kapasite 1 satış/sn, geliş 1 satış/sn (taban).
        // Kadro geleni karşıladığı için gelir kapasiteyle aynı kalır.
        let next = GameEngine.advance(state, by: 7200, config: config)
        XCTAssertEqual(next.money, 10 * 7200, accuracy: 1, "Talep çevrimdışı kazancı düşürmemeli")
    }
}
