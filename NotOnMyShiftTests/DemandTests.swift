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
            serviceBaseSeconds: 1,
            serviceRatePerStaffPoint: 0,
            serviceMinimumSeconds: 1,
            starterArrivalSeconds: 1_000_000,
            baseArrivalSeconds: 1_000_000,
            demandStartQueue: 0,
            startSatisfaction: 0.25,
            minSatisfaction: 0.25,
            maxSatisfaction: 0.25
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
            serviceBaseSeconds: 1,
            serviceRatePerStaffPoint: 0,
            serviceMinimumSeconds: 1,
            starterArrivalSeconds: 1_000_000,
            baseArrivalSeconds: 0.5,          // 2 satış/sn taban
            cancelSeconds: 60,
            demandStartQueue: 0,
            startSatisfaction: 1, minSatisfaction: 1, maxSatisfaction: 1
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
            cancelSeconds: 60,
            demandStartQueue: 0,
            startSatisfaction: 1, minSatisfaction: 1, maxSatisfaction: 1
        )
        let state = BalanceFixture.state(staffCount: 0, demandQueue: 0, config: config)

        let next = GameEngine.advance(state, by: 10_000, config: config)
        XCTAssertEqual(next.floors[0].demandQueue, 20, accuracy: 0.5, "1/3 × 60 = 20 kişilik kapıda kuyruk")
        XCTAssertEqual(next.money, 0, accuracy: 1e-9, "Kadro yokken kimse satmaz")
    }

    /// Kuyruğa ayrı bir tavan koymuyoruz: **iptal süresi kendisi sınırdır.**
    /// Denge noktası `geliş hızı × iptal süresi`.
    func testCancelTimeBoundsTheQueueOnItsOwn() {
        let config = BalanceFixture.config(
            starterArrivalSeconds: 1,        // saniyede bir sipariş
            cancelSeconds: 10,
            demandStartQueue: 0,
            startSatisfaction: 1, minSatisfaction: 1, maxSatisfaction: 1
        )
        let state = BalanceFixture.state(staffCount: 0, demandQueue: 0, config: config)

        // İptal olmasa 10.000 sipariş birikirdi; 1/sn × 10 sn = 10'da duruyor.
        let next = GameEngine.advance(state, by: 10_000, config: config)
        XCTAssertEqual(next.floors[0].demandQueue, 10, accuracy: 1e-6)
    }

    /// Karşılanamayan siparişler gerçekten iptal olarak sayılır — korunum:
    /// gelen + baştaki = karşılanan + kalan + iptal.
    func testUnservedOrdersAreCountedAsCancelled() {
        let config = BalanceFixture.config(cancelSeconds: 10)
        let outcome = GameEngine.serveDemand(
            queue: 5, capacity: 0, arrival: 1, seconds: 100, config: config
        )
        XCTAssertEqual(outcome.served, 0, accuracy: 1e-9)
        XCTAssertEqual(outcome.queue, 10, accuracy: 1e-3, "Denge noktası λ·T")
        XCTAssertEqual(outcome.cancelled, 5 + 100 - 0 - outcome.queue, accuracy: 1e-9)
        XCTAssertGreaterThan(outcome.cancelled, 0)
    }

    /// Kadro yetişirken iptal olmaz.
    func testNothingCancelsWhileTheShopKeepsUp() {
        let config = BalanceFixture.config(cancelSeconds: 10)
        let outcome = GameEngine.serveDemand(
            queue: 2, capacity: 5, arrival: 1, seconds: 10, config: config
        )
        XCTAssertEqual(outcome.cancelled, 0, accuracy: 1e-9)
        XCTAssertEqual(outcome.queue, 0, accuracy: 1e-9)
        XCTAssertEqual(outcome.served, 2 + 10, accuracy: 1e-9, "Baştaki iki sipariş de karşılandı")
    }

    /// Müşteri gelmeden elle satış olmaz; müşteri gelince olur.    /// Müşteri gelmeden elle satış olmaz; müşteri gelince olur.
    func testManualSaleNeedsAWaitingOrder() {
        let config = BalanceFixture.config(
            starterArrivalSeconds: 10,
            demandStartQueue: 0,
            startSatisfaction: 1, minSatisfaction: 1, maxSatisfaction: 1
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

    /// Elle karşılanan sipariş memnuniyet **oranına** girer: satış anında
    /// sayaca yazılır, bir sonraki ilerlemede kadronun karşıladıklarıyla
    /// birlikte değerlendirilir. Ayrı bir artı vermek yetmezdi — hedef bir
    /// oran olduğu için tek iptal hedefi tabana çekerdi.
    func testServingByHandCountsTowardTheSatisfactionRatio() {
        let config = BalanceFixture.config(
            starterArrivalSeconds: 1_000_000,   // yeni sipariş gelmesin
            cancelSeconds: 10,
            demandStartQueue: 0,
            startSatisfaction: 0.7,
            minSatisfaction: 0.6,
            maxSatisfaction: 1.0,
            satisfactionPerSecond: 0.02
        )
        var state = BalanceFixture.state(demandQueue: 5, config: config)
        state.floors[0].satisfaction = 0.7

        let satildi = GameEngine.sellManually(onFloor: 0, state, config: config)
        XCTAssertEqual(satildi.floors[0].servedByHand, 1, accuracy: 1e-9, "Satış sayaca yazılır")
        XCTAssertEqual(satildi.floors[0].demandQueue, 4, accuracy: 1e-9)

        // Bir sonraki ilerlemede orana giriyor: iptal yok, hedef tavan.
        let sonra = GameEngine.advance(satildi, by: 2, config: config)
        XCTAssertEqual(sonra.floors[0].satisfaction, 0.74, accuracy: 1e-6)
        XCTAssertEqual(sonra.floors[0].servedByHand, 0, accuracy: 1e-9, "Sayaç sıfırlanır")
    }

    /// Memnuniyet **ikisini birden** ister: zamanında servis ve adil fiyat.
    ///
    /// Karışım çarpımsal olduğu için biri dibe vurunca diğeri kurtaramaz —
    /// toplamsal formda ucuzluk puanı servis çöküşünü örtüyordu. İç bölgede
    /// ise ağırlık konuşuyor: kötü servis, pahalı fiyattan daha çok zarar
    /// verir.
    func testSatisfactionNeedsBothGoodServiceAndFairPrice() {
        let config = BalanceFixture.config(
            minSatisfaction: 0.6,
            maxSatisfaction: 1.0,
            satisfactionPerSecond: 1,        // tek adımda hedefe otursun
            serviceWeight: 0.7,
            priceFairnessFloor: 0
        )

        func hedef(service: Double, fiyatPuani: Double) -> Double {
            GameEngine.nextSatisfaction(
                current: 0.6,
                served: service * 10,
                cancelled: (1 - service) * 10,
                priceScore: fiyatPuani,
                seconds: 100,
                config: config
            )
        }

        // İkisi de kusursuz → tavan.
        XCTAssertEqual(hedef(service: 1, fiyatPuani: 1), 1.0, accuracy: 1e-9)

        // Biri dibe vurunca diğeri kurtaramaz.
        XCTAssertEqual(hedef(service: 1, fiyatPuani: 0), 0.6, accuracy: 1e-9)
        XCTAssertEqual(hedef(service: 0, fiyatPuani: 1), 0.6, accuracy: 1e-9)

        // İç bölgede ağırlık konuşuyor: servis 0,7 · fiyat 0,3.
        let kotuServis = hedef(service: 0.5, fiyatPuani: 1)      // 0,5^0,7
        let pahali = hedef(service: 1, fiyatPuani: 0.5)          // 0,5^0,3
        XCTAssertEqual(kotuServis, 0.6 + 0.4 * pow(0.5, 0.7), accuracy: 1e-9)
        XCTAssertEqual(pahali, 0.6 + 0.4 * pow(0.5, 0.3), accuracy: 1e-9)
        XCTAssertLessThan(kotuServis, pahali, "Kötü servis daha çok zarar verir")
    }

    /// Pahalı fiyat çöküş sarmalına sokmamalı: talep düşer, memnuniyet biraz
    /// iner, ama ikisi birbirini besleyip dibe çakmaz.
    func testHighPriceDoesNotSpiralToTheFloor() {
        let config = BalanceFixture.config(
            revenuePerSale: 10,
            serviceBaseSeconds: 1,
            serviceRatePerStaffPoint: 0,
            serviceMinimumSeconds: 1,
            starterArrivalSeconds: 1_000_000,
            baseArrivalSeconds: 1_000_000,
            cancelSeconds: 10,
            demandStartQueue: 0,
            startSatisfaction: 0.9,
            minSatisfaction: 0.6,
            maxSatisfaction: 1.0,
            satisfactionPerSecond: 0.01,
            serviceWeight: 0.7,
            priceFairnessFloor: 0.3
        )
        var state = BalanceFixture.state(staffCount: 1, demandQueue: 0, config: config)
        state = GameEngine.setPrice(20, onFloor: 0, state, config: config)   // en pahalı

        let sonra = GameEngine.advance(state, by: 3600, config: config)

        // Kadro yetiştiği için iptal yok, servis 1; fiyat adaleti tabanda
        // (0,3). Çarpımsal: 1^0,7 × 0,3^0,3 → 0,6 + 0,4 × 0,697.
        XCTAssertEqual(sonra.floors[0].satisfaction, 0.6 + 0.4 * pow(0.3, 0.3), accuracy: 1e-6)
        XCTAssertGreaterThan(sonra.floors[0].satisfaction, 0.8, "Sarmal yok")
        // Ve dükkân hâlâ para kazanıyor.
        XCTAssertGreaterThan(sonra.money, 0)
    }

    /// Ekosistemin bütünü: yetişen oyuncunun memnuniyeti yükselir,
    /// yetişemeyenin düşer. Çağ 0'da tezgâhı oyuncu çalıştırdığı için asıl
    /// sınav burası.
    func testKeepingUpRaisesSatisfactionAndFallingBehindLowersIt() {
        let config = BalanceFixture.config(
            manualCooldownSeconds: 2,
            minCooldownSeconds: 2,
            starterArrivalSeconds: 3,        // üç saniyede bir sipariş
            cancelSeconds: 10,
            demandStartQueue: 3,
            startSatisfaction: 0.7,
            minSatisfaction: 0.6,
            maxSatisfaction: 1.0,
            satisfactionPerSecond: 0.02
        )

        // Yetişen oyuncu: iki saniyede bir satış, geliş hızından hızlı.
        var yetisen = BalanceFixture.state(demandQueue: 3, config: config)
        yetisen.floors[0].satisfaction = 0.7
        for _ in 0..<30 {
            yetisen = GameEngine.advance(yetisen, by: 2, config: config)
            yetisen = GameEngine.sellManually(onFloor: 0, yetisen, config: config)
        }
        // Nereye oturduğu bir denge sayısı: oyuncunun geliş hızından ne kadar
        // hızlı olduğuna bağlı (burada 2 sn soğumaya karşı 3 sn geliş).
        // Testin ölçtüğü şey yön: yetişmek memnuniyeti yükseltir.
        XCTAssertGreaterThan(
            yetisen.floors[0].satisfaction, 0.75,
            "Zamanında karşılayan oyuncu başladığı yerin üstüne çıkmalı"
        )

        // Yetişemeyen oyuncu: hiç dokunmuyor, siparişler iptal oluyor.
        var yetisemeyen = BalanceFixture.state(demandQueue: 3, config: config)
        yetisemeyen.floors[0].satisfaction = 0.7
        yetisemeyen = GameEngine.advance(yetisemeyen, by: 60, config: config)
        XCTAssertEqual(
            yetisemeyen.floors[0].satisfaction, 0.6, accuracy: 1e-9,
            "İhmal tabana indirir — ama sıfıra değil"
        )

        // Asıl iddia bu: iki oyuncu arasında gerçek bir fark var.
        XCTAssertGreaterThan(
            yetisen.floors[0].satisfaction,
            yetisemeyen.floors[0].satisfaction + 0.1
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

    /// Memnuniyet **sonuçtan** beslenir: zamanında karşılanan sipariş
    /// yükseltir, iptal olan düşürür. Taban aşılmaz — kötü gün geliri
    /// sıfırlamaz, yavaşlatır.
    func testSatisfactionFollowsServedVersusCancelled() {
        let config = BalanceFixture.config(
            minSatisfaction: 0.6,
            maxSatisfaction: 1.0,
            satisfactionPerSecond: 0.01
        )

        // Hepsi iptal → taban.
        let kotu = GameEngine.nextSatisfaction(
            current: 1, served: 0, cancelled: 50, priceScore: 0, seconds: 1000, config: config
        )
        XCTAssertEqual(kotu, 0.6, accuracy: 1e-9, "Taban aşılmaz")

        // Hepsi karşılandı → tavan.
        let iyi = GameEngine.nextSatisfaction(
            current: 0.6, served: 50, cancelled: 0, priceScore: 1, seconds: 1000, config: config
        )
        XCTAssertEqual(iyi, 1.0, accuracy: 1e-9, "Zamanında servis tavana kadar ödüllendirir")

        // Yarısı iptal → hedef tam ortada (0,8).
        let orta = GameEngine.nextSatisfaction(
            current: 0.6, served: 25, cancelled: 25, priceScore: 0.5, seconds: 1000, config: config
        )
        XCTAssertEqual(orta, 0.8, accuracy: 1e-9)

        // Tek adımda uçmaz: hız dengede tanımlı.
        let yavas = GameEngine.nextSatisfaction(
            current: 0.6, served: 50, cancelled: 0, priceScore: 1, seconds: 10, config: config
        )
        XCTAssertEqual(yavas, 0.7, accuracy: 1e-9)

        // Hiç sipariş geçmediyse memnuniyet yerinde kalır.
        let sessiz = GameEngine.nextSatisfaction(
            current: 0.85, served: 0, cancelled: 0, priceScore: 1, seconds: 1000, config: config
        )
        XCTAssertEqual(sessiz, 0.85, accuracy: 1e-9, "Kapalı dükkân ne kazanır ne kaybeder")
    }

    /// Kadro birikmiş kuyruğu **servis ederek** eritir    /// Kadro birikmiş kuyruğu **servis ederek** eritir — müşteriler kaçtığı
    /// için değil. Ölçüt para: eriyen kişi sayısı kadar satış yapılmış olmalı.
    func testStaffWorkThroughTheQueueAndGetPaidForIt() {
        // Kapasite 1 satış/sn (10 ₺/sn ÷ 10 ₺), geliş 0,5 satış/sn.
        // Taban aralık devre dışı ki kapsama belirleyici olsun.
        let config = BalanceFixture.config(
            revenuePerSale: 10,
            serviceBaseSeconds: 1,
            serviceRatePerStaffPoint: 0,
            serviceMinimumSeconds: 1,
            starterArrivalSeconds: 1_000_000,
            baseArrivalSeconds: 1_000_000,
            demandStartQueue: 0,
            startSatisfaction: 0.5, minSatisfaction: 0.5, maxSatisfaction: 0.5
        )
        let state = BalanceFixture.state(staffCount: 1, demandQueue: 100, config: config)

        let next = GameEngine.advance(state, by: 100, config: config)

        // Kuyruk boşalma hızı = kapasite − geliş = 0,5 kişi/sn.
        XCTAssertEqual(next.floors[0].demandQueue, 50, accuracy: 1e-6, "Kadro kuyruğu eritmeli")
        // Ve tam kapasiteyle çalıştığı için 100 satış yapılmış olmalı.
        XCTAssertEqual(next.money, 1000, accuracy: 1e-6, "Eriyen müşteriler paraya dönmeli")
    }

    /// Dengedeki sayılar **ortada bir sabit nokta** üretmeli.
    ///
    /// Tavan 1'de kalsaydı geliş hızı kapasiteyi asla aşamaz, kuyruk oluşmaz
    /// ve memnuniyet tavana yapışırdı: denge yerine iki uç kalırdı. Tavan 1'in
    /// üstünde olunca negatif geri besleme doğuyor — geliş kapasiteyi aşar,
    /// kuyruk büyür, iptaller memnuniyeti düşürür, geliş yavaşlar.
    func testShippedBalanceSettlesInTheMiddleWithAQueue() throws {
        let config = try BalanceConfig.load()
        XCTAssertGreaterThan(config.demand.maxSatisfaction, 1.0, "Dükkân dolabilmeli")
        XCTAssertLessThan(config.demand.minSatisfaction, 1.0, "İhmal gerçekten aç bırakmalı")

        // Gerçek dengeyle bir eleman tut ve uzun süre çalıştır.
        var state = GameState.newGame(characterID: "kahveci", now: BalanceFixture.epoch)
        state = GameEngine.normalised(state, config: config)
        state.money = 1_000_000
        guard case .success(let hired) = GameEngine.hireStaff(onFloor: 0, state, config: config) else {
            return XCTFail("Eleman tutulamadı")
        }
        // Saniye saniye: canlı oyunda zamanlayıcı böyle ilerletiyor ve
        // ekosistem ancak adımlar arasında geri besleme yapabiliyor. Tek bir
        // 3600 saniyelik adımda memnuniyet yalnızca sonda güncellenir, döngü
        // dönmez — kapalı formun bilinen sınırı.
        var sonra = hired
        for _ in 0..<600 {
            sonra = GameEngine.advance(sonra, by: 1, config: config)
        }

        let memnuniyet = sonra.floors[0].satisfaction
        XCTAssertGreaterThan(memnuniyet, config.demand.minSatisfaction + 0.05, "Tabana yapışmamalı")
        XCTAssertLessThan(memnuniyet, config.demand.maxSatisfaction - 0.05, "Tavana da yapışmamalı")

        // Ve dükkânda gerçekten sıra olmalı — boş bir tezgâh oyun değil.
        XCTAssertGreaterThan(sonra.floors[0].demandQueue, 1, "Kuyruk oluşmalı")

        // Para akmaya devam ediyor.
        XCTAssertGreaterThan(sonra.money, hired.money)
    }

    /// Sen yokken kadro talebi karşılar    /// Sen yokken kadro talebi karşılar: çevrimdışı kazanç talep yüzünden
    /// çökmez. Ürün sahibinin seçtiği kural buydu.
    /// Sayaçtaki "ortalama satış" fiyatın **altında** olmalı: maaş düşülüyor.
    /// Üstüne çıkıyorsa gelir ile satış adedi farklı çarpanla hesaplanıyordur —
    /// ekranda tam olarak bu görüldü (fiyat 4 ₺ iken ortalama 4,8 ₺).
    func testAverageSaleValueStaysBelowThePrice() throws {
        let config = try BalanceConfig.load()
        var state = GameState.newGame(characterID: "kahveci", now: BalanceFixture.epoch)
        state = GameEngine.normalised(state, config: config)
        state.money = 1_000_000
        guard case .success(let hired) = GameEngine.hireStaff(onFloor: 0, state, config: config) else {
            return XCTFail("Eleman tutulamadı")
        }

        var sonra = hired
        for _ in 0..<300 { sonra = GameEngine.advance(sonra, by: 1, config: config) }

        let fiyat = GameEngine.price(for: sonra.floors[0], spec: config.sectors[0])
        let ortalama = GameEngine.averageSaleValue(for: sonra, config: config)
        XCTAssertGreaterThan(ortalama, 0)
        XCTAssertLessThan(ortalama, fiyat, "Maaş düşülünce ortalama fiyatın altında kalmalı")
    }

    /// Sıra uzayınca gelen müşteri kapıdan döner. Doğrusal olmayan bu fren
    /// birikimi kendiliğinden sınırlıyor: bekleme sabra yaklaştıkça yeni
    /// sipariş girişi kesiliyor, kuyruk sonsuza gitmiyor.
    func testBaulkingKeepsTheWaitNearPatience() {
        let config = BalanceFixture.config(patienceSeconds: 10, baulkSharpness: 2)
        let spec = config.sectors[0]

        // Boş kuyrukta fren yok.
        var floor = FloorState(sectorID: spec.id, demandQueue: 0)
        XCTAssertEqual(GameEngine.baulkFactor(for: floor, capacity: 1, config: config), 1, accuracy: 1e-9)

        // Bekleme sabra eşitken yarı yarıya: 1/(1+1²).
        floor = FloorState(sectorID: spec.id, demandQueue: 10)
        XCTAssertEqual(GameEngine.baulkFactor(for: floor, capacity: 1, config: config), 0.5, accuracy: 1e-9)

        // Sabrın iki katında fren sertleşiyor: 1/(1+2²).
        floor = FloorState(sectorID: spec.id, demandQueue: 20)
        XCTAssertEqual(GameEngine.baulkFactor(for: floor, capacity: 1, config: config), 0.2, accuracy: 1e-9)

        // Çağ 0'da fren yok: orada tezgâhı oyuncu çalıştırıyor.
        floor = FloorState(sectorID: spec.id, demandQueue: 50)
        XCTAssertEqual(GameEngine.baulkFactor(for: floor, capacity: 0, config: config), 1, accuracy: 1e-9)
    }

    /// Fren gerçekten birikimi kesiyor: aynı kurulumda sabırlı ve sabırsız
    /// müşteriyle kuyruk karşılaştırılıyor.
    func testBaulkingShortensTheQueue() throws {
        let base = try BalanceConfig.load()
        var frensiz = base
        frensiz.demand.patienceSeconds = 1_000_000

        func kuyruk(_ config: BalanceConfig) -> Double {
            var state = GameState.newGame(characterID: "kahveci", now: BalanceFixture.epoch)
            state = GameEngine.normalised(state, config: config)
            state.money = 1_000_000
            guard case .success(let hired) = GameEngine.hireStaff(onFloor: 0, state, config: config) else {
                return -1
            }
            var sonra = hired
            for _ in 0..<900 { sonra = GameEngine.advance(sonra, by: 1, config: config) }
            return sonra.floors[0].demandQueue
        }

        XCTAssertLessThan(kuyruk(base), kuyruk(frensiz), "Fren kuyruğu kısaltmalı")
    }

    func testStaffKeepServingWhileYouAreAway() {
        let config = BalanceFixture.config(
            revenuePerSale: 10,
            serviceBaseSeconds: 1,
            serviceRatePerStaffPoint: 0,
            serviceMinimumSeconds: 1,
            starterArrivalSeconds: 1,
            baseArrivalSeconds: 1,
            demandStartQueue: 0,
            startSatisfaction: 1, minSatisfaction: 1, maxSatisfaction: 1
        )
        let state = BalanceFixture.state(staffCount: 1, demandQueue: 0, config: config)

        // İki saat uzakta: kapasite 1 satış/sn, geliş 1 satış/sn (taban).
        // Kadro geleni karşıladığı için gelir kapasiteyle aynı kalır.
        let next = GameEngine.advance(state, by: 7200, config: config)
        XCTAssertEqual(next.money, 10 * 7200, accuracy: 1, "Talep çevrimdışı kazancı düşürmemeli")
    }
}

/// Fiyat mekaniği ve tezgâh hızı.
///
/// Tasarımın çekirdeği: gelir = `min(kapasite, talep(fiyat)) × fiyat`.
/// Ucuz satmak müşteriyi çoğaltır ama kapasiteyi aşan kısmı kuyrukta bekler;
/// pahalı satmak tezgâhı boş bırakır. Tepe nokta ikisinin kesiştiği yerdir.
final class PriceTests: XCTestCase {

    /// Aynı denge: kapasite 1 satış/sn, taban fiyat 10 ₺, esneklik 2.
    /// Taban geliş hızı devre dışı ki fiyat belirleyici olsun.
    private let config = BalanceFixture.config(
        revenuePerSale: 10,
        serviceBaseSeconds: 1,
        serviceRatePerStaffPoint: 0,
        serviceMinimumSeconds: 1,
        starterArrivalSeconds: 1_000_000,
        baseArrivalSeconds: 1_000_000,
        demandStartQueue: 0,
        startSatisfaction: 1, minSatisfaction: 1, maxSatisfaction: 1,
        priceElasticity: 2
    )

    private func rate(at price: Double) -> Double {
        var state = BalanceFixture.state(staffCount: 1, demandQueue: 0, config: config)
        state = GameEngine.setPrice(price, onFloor: 0, state, config: config)
        return GameEngine.productionRate(for: state, config: config)
    }

    /// Gelir, talebin kapasiteyi tam doldurduğu fiyatta tepe yapar.
    ///
    /// Ucuz tarafta kapasite sınırlıyız: müşteri çok ama tezgâh yetişmiyor,
    /// her satış az kazandırıyor. Pahalı tarafta tezgâh boş: satış az.
    func testIncomePeaksWhereDemandJustFillsCapacity() {
        // λ(p) = kapasite × (10/p)². Kapasite 1 → λ = 1 tam olarak p = 10'da.
        XCTAssertEqual(rate(at: 10), 10, accuracy: 1e-6, "Tepe nokta: dükkân tam dolu")

        // Ucuz: λ = 4 satış/sn ama kapasite 1 → gelir 1 × 5.
        XCTAssertEqual(rate(at: 5), 5, accuracy: 1e-6, "Ucuz satmak kapasiteyi aşan talebi boşa harcar")

        // Pahalı: λ = 0,25 satış/sn → gelir 0,25 × 20.
        XCTAssertEqual(rate(at: 20), 5, accuracy: 1e-6, "Pahalı satmak tezgâhı boş bırakır")

        XCTAssertGreaterThan(rate(at: 10), rate(at: 5))
        XCTAssertGreaterThan(rate(at: 10), rate(at: 20))
    }

    /// Fiyat dengedeki aralığın dışına çıkamaz.
    func testPriceStaysInsideTheBalanceRange() {
        let state = BalanceFixture.state(config: config)
        let range = GameEngine.priceRange(for: config.sectors[0])
        XCTAssertEqual(range.lowerBound, 5, accuracy: 1e-9)
        XCTAssertEqual(range.upperBound, 20, accuracy: 1e-9)

        let ucuz = GameEngine.setPrice(1, onFloor: 0, state, config: config)
        XCTAssertEqual(ucuz.floors[0].price, 5, accuracy: 1e-9)

        let pahali = GameEngine.setPrice(999, onFloor: 0, state, config: config)
        XCTAssertEqual(pahali.floors[0].price, 20, accuracy: 1e-9)
    }

    /// Fiyat elle satışın getirisini de değiştirir.
    func testPriceChangesWhatOneTapEarns() {
        var state = BalanceFixture.state(config: config)
        state = GameEngine.setPrice(20, onFloor: 0, state, config: config)
        XCTAssertEqual(GameEngine.manualRevenue(onFloor: 0, state, config: config), 20, accuracy: 1e-9)

        let satildi = GameEngine.sellManually(onFloor: 0, state, config: config)
        XCTAssertEqual(satildi.money, 20, accuracy: 1e-9)
    }

    /// Ekipman tezgâhı hızlandırır: oyunun başında iki saniye, makineler
    /// geldikçe bir saniyenin altına iner ve dengedeki tabanda durur.
    func testEquipmentSpeedsUpTheCounter() {
        let config = BalanceFixture.config(
            manualCooldownSeconds: 2,
            minCooldownSeconds: 0.25
        )
        let spec = config.sectors[0]

        let ekipmansiz = FloorState(sectorID: spec.id)
        XCTAssertEqual(
            GameEngine.manualCooldown(for: ekipmansiz, spec: spec, config: config),
            2, accuracy: 1e-9,
            "Oyunun başında kahve yapmak iki saniye"
        )

        // Koşumda öğütücü seviye 1 → ×2, seviye 2 → ×4.
        let birinci = FloorState(sectorID: spec.id, equipmentLevels: ["grinder": 1])
        XCTAssertEqual(
            GameEngine.manualCooldown(for: birinci, spec: spec, config: config),
            1, accuracy: 1e-9,
            "İlk geliştirme süreyi yarıya indirir"
        )

        let ikinci = FloorState(sectorID: spec.id, equipmentLevels: ["grinder": 2])
        XCTAssertEqual(
            GameEngine.manualCooldown(for: ikinci, spec: spec, config: config),
            0.5, accuracy: 1e-9,
            "İkincisiyle bir saniyenin altına iner"
        )
    }

    /// Soğuma dengedeki tabanın altına inmez.
    func testCooldownNeverGoesBelowTheFloor() {
        let config = BalanceFixture.config(manualCooldownSeconds: 2, minCooldownSeconds: 0.25)
        let spec = config.sectors[0]
        let tamEkipman = FloorState(sectorID: spec.id, equipmentLevels: ["grinder": 2])
        // ×4 → 0,5 sn. Tabanı yükseltirsek taban kazanır.
        let sikiConfig = BalanceFixture.config(manualCooldownSeconds: 2, minCooldownSeconds: 1.5)
        XCTAssertEqual(
            GameEngine.manualCooldown(for: tamEkipman, spec: sikiConfig.sectors[0], config: sikiConfig),
            1.5, accuracy: 1e-9
        )
        XCTAssertEqual(
            GameEngine.manualCooldown(for: tamEkipman, spec: spec, config: config),
            0.5, accuracy: 1e-9
        )
    }
}
