import Foundation
import Observation

/// Motor ile ekran arasındaki tek köprü.
///
/// Sorumlulukları: durumu tutmak, saati okumak, sahne fazını dinlemek, diske
/// yazmak. Ekonomi hesabı yapmaz — onu `GameEngine`'e sorar.
///
/// Zamanlayıcı **görsel tazeleme** içindir. Ekonomi her zaman `lastSeenAt` ile
/// `Date()` farkından türetilir; zamanlayıcı sadece "şimdi yeniden hesapla" der.
/// Bu yüzden zamanlayıcı gecikse, atlansa, arka planda dursa bile para doğru olur.
///
/// Faz 3'ten beri panel **seçili kat** üstünde çalışır; kasa ortaktır.
@MainActor
@Observable
final class GameStore {

    // MARK: - Dışarıya açık durum

    private(set) var state: GameState
    let config: BalanceConfig

    /// Çevrimdışı dönüş özeti. Doluysa ekranda gösterilir.
    var offlineReport: OfflineReport?

    /// Sektör satıldığı an. Satılan sektörün kimliğini taşır.
    var sectorSaleCelebration: String?

    /// Halka arz özeti. Doluysa final sahnesi gösterilir.
    var finale: FinaleSummary?

    /// Çağ 0 → Çağ 1 anı. İlk eleman tutulduğunda bir kez dolar.
    var firstHireCelebration: StaffMember?

    /// Kat açıldığı an. Yeni sektörün kimliğini taşır.
    var newFloorCelebration: String?

    /// Karar bekleyen olay. Seans başına en fazla bir tane gösterilir.
    var pendingEvent: BalanceConfig.EventSpec?

    /// Müdürlerin son dönüşte yaptıkları. Doluysa rapor gösterilir.
    var managerReport: [GameEngine.AutomatedAction] = []

    /// Son başarısız eylemin sebebi. Kullanıcı bir şey yapınca temizlenir.
    private(set) var lastActionError: GameEngine.ActionError?

    /// Kayıt ana dosyadan değil yedekten mi açıldı?
    private(set) var didRecoverFromBackup = false

    /// Diske yazma başarısız oldu mu?
    private(set) var didFailToSave = false

    // MARK: - Kat

    var floors: [FloorState] { state.floors }
    var selectedFloor: Int { state.safeSelectedFloor }

    /// Panelin üstünde çalıştığı kat.
    var currentFloor: FloorState? { state.currentFloor }

    /// Seçili katın sektör tanımı.
    var currentSpec: BalanceConfig.SectorSpec? {
        currentFloor.flatMap { GameEngine.spec(for: $0, config: config) }
    }

    /// Kat başına hücre (şube) sayısı — bina çizimi bunu ister.
    var unitCounts: [Int] {
        floors.map { floor in
            guard let spec = GameEngine.spec(for: floor, config: config) else { return 1 }
            return GameEngine.branchCount(for: floor, spec: spec)
        }
    }

    /// Bir katın sektör kimliği — tabela ve şerit başlığı için.
    func sectorID(of index: Int) -> String? {
        floors.indices.contains(index) ? floors[index].sectorID : nil
    }

    // MARK: - Türetilmiş oranlar

    /// Kasaya giren net. Maaş düşülmüş hâli.
    var productionRate: Double { GameEngine.productionRate(for: state, config: config) }
    /// Maaş kesilmeden önceki üretim.
    var grossRate: Double { GameEngine.grossRate(for: state, config: config) }
    /// Saniyelik maaş gideri.
    var wageRate: Double { GameEngine.wageRate(for: state, config: config) }
    var offlineCapacitySeconds: TimeInterval { GameEngine.offlineCapacitySeconds(for: state, config: config) }
    var warehouseUpgradeCost: Double? { GameEngine.warehouseUpgradeCost(for: state, config: config) }

    /// Bir katın kendi neti — şerit üstünde gösterilir.
    func netRate(of index: Int) -> Double {
        guard floors.indices.contains(index),
              let spec = GameEngine.spec(for: floors[index], config: config) else { return 0 }
        return GameEngine.floorNet(floors[index], spec: spec)
    }

    // MARK: - Seçili kata bağlı

    /// Elle bir satışın getirisi — ekipmanla ve süren olay etkisiyle birlikte büyür.
    var manualRevenue: Double {
        GameEngine.manualRevenue(onFloor: selectedFloor, state, config: config)
    }

    var hireCost: Double? {
        guard let floor = currentFloor, let spec = currentSpec else { return nil }
        return GameEngine.hireCost(for: floor, spec: spec)
    }

    /// Sıradaki elemanın şablonu — "kimi tutuyorum" bilgisini satırda gösterebilmek için.
    var nextStaffTemplate: BalanceConfig.StaffTemplate? {
        guard let floor = currentFloor, let spec = currentSpec else { return nil }
        let index = floor.staff.count
        guard index < GameEngine.staffCapacity(spec: spec) else { return nil }
        return spec.staffPool.indices.contains(index) ? spec.staffPool[index] : nil
    }

    /// Sonraki eleman için kaç satış daha gerekiyor?
    /// Çağ 0'da hedefi somutlaştırır: "38 kahve daha".
    var manualSalesUntilHire: Int? {
        guard let floor = currentFloor, let cost = hireCost, !floor.isAutomated else { return nil }
        let revenue = manualRevenue
        guard revenue > 0 else { return nil }
        let remaining = cost - state.money
        guard remaining > 0 else { return nil }
        return Int((remaining / revenue).rounded(.up))
    }

    var branchCount: Int {
        guard let floor = currentFloor, let spec = currentSpec else { return 1 }
        return GameEngine.branchCount(for: floor, spec: spec)
    }

    /// Açılabilecek bir sonraki şubenin ücreti. Kat doluysa ya da pazar payı
    /// yetmiyorsa `nil`.
    var branchCost: Double? {
        GameEngine.availableBranchCost(onFloor: selectedFloor, state, config: config)
    }

    var maxBranches: Int { max(1, currentSpec?.branches.maxCount ?? 1) }

    /// Ekipman şeridinin satırları. Sıra `balance.json`'daki sıradır.
    var equipmentRows: [EquipmentRow] {
        guard let floor = currentFloor, let spec = currentSpec else { return [] }
        return spec.equipment.map { item in
            let level = min(floor.equipmentLevel(item.id), max(0, item.levels.count - 1))
            return EquipmentRow(
                id: item.id,
                level: level,
                maxLevel: max(0, item.levels.count - 1),
                multiplier: item.levels.indices.contains(level) ? item.levels[level].multiplier : 1,
                upgradeCost: GameEngine.equipmentUpgradeCost(item.id, for: floor, spec: spec)
            )
        }
    }

    // MARK: - Kat açma

    var nextFloorCost: Double? { GameEngine.nextFloorCost(for: state, config: config) }
    var nextSector: BalanceConfig.SectorSpec? { GameEngine.nextSector(for: state, config: config) }

    /// Bina kaç kata kadar yükselecek — palet geçişi bunun üstünden hesaplanır.
    var plannedFloors: Int { max(1, config.building.paletteFloors) }

    // MARK: - Süreç katmanı

    var hasRoof: Bool { state.hasRoof }
    var roofCost: Double? { GameEngine.roofCost(for: state, config: config) }
    var managerCost: Double? { GameEngine.managerCost(for: state, config: config) }
    var autoResolvesEvents: Bool { state.autoResolvesEvents }

    /// Kural şablonları — hazır tarifler, kural editörü değil.
    var ruleTemplates: [BalanceConfig.RuleSpec] { config.process.rules }

    /// Seçili katta müdür var mı?
    var hasManagerOnSelectedFloor: Bool {
        currentFloor.map { state.hasManager($0.sectorID) } ?? false
    }

    func isRuleActive(_ ruleID: String) -> Bool {
        guard let floor = currentFloor else { return false }
        return state.rules(for: floor.sectorID).contains(ruleID)
    }

    /// Seçili katın süreç verimi (1,0 → bonus yok).
    var processBonus: Double {
        guard let floor = currentFloor else { return 1 }
        return GameEngine.processBonus(for: floor, state: state, config: config)
    }

    /// Bonusun tavanı — "daha ne kadar var" bilgisini gösterebilmek için.
    var maxProcessBonus: Double { max(0, config.process.maxBonus) }

    // MARK: - Yumuşak prestij

    /// Kalıcı holding puanı. Satılan her sektörden kalır, hiç azalmaz.
    var holdingPoints: Int { state.holdingPoints }
    /// Puanların brüte kattığı çarpan. 1,0 ise henüz sektör satılmadı.
    var holdingMultiplier: Double { GameEngine.holdingMultiplier(for: state, config: config) }
    var cityNumber: Int { state.cityNumber }

    /// Seçili katın olgunluğu 0..1 — satışa ne kadar kaldığı.
    var maturityProgress: Double {
        guard let floor = currentFloor, let spec = currentSpec else { return 0 }
        return GameEngine.maturityProgress(floor, spec: spec)
    }

    /// Seçili kat satılabilir mi, satılırsa ne kadar eder?
    var saleValue: Double? { GameEngine.saleValue(onFloor: selectedFloor, state, config: config) }

    /// Seçili kat satıldı mı — yatırım katı yönetilmez.
    var isSelectedFloorSold: Bool { currentFloor?.isInvestment ?? false }

    /// Satıştan sonra bu kattan kalacak saniyelik pasif gelir.
    var saleInvestmentRate: Double {
        guard let floor = currentFloor, let spec = currentSpec else { return 0 }
        return GameEngine.investmentRate(of: floor, spec: spec, config: config)
    }

    /// Bina halka arza hazır mı?
    var canGoPublic: Bool { GameEngine.canGoPublic(state, config: config) }

    // MARK: - Olaylar ve pazar

    /// Süren olay etkileri.
    var modifiers: [ActiveModifier] { state.modifiers }
    /// Süren etkilerin toplam çarpanı. 1 ise etki yok.
    var eventMultiplier: Double { GameEngine.eventMultiplier(for: state) }

    /// Bir etkinin bitmesine kalan oyun süresi.
    func remainingSeconds(of modifier: ActiveModifier) -> TimeInterval {
        max(0, modifier.endsAtGameSeconds - state.elapsedGameSeconds)
    }

    /// Bir olay seçeneğinin anında getireceği/götüreceği tutar.
    /// Mevcut üretime oranlı olduğu için her çağda anlamlı kalır.
    func eventInstantAmount(_ choice: BalanceConfig.EventChoice) -> Double {
        GameEngine.productionRate(for: state, config: config) * choice.instantSeconds
    }

    var marketShare: Double { GameEngine.marketShare(for: state, config: config) }
    var competitorShares: [GameEngine.CompetitorShare] {
        GameEngine.competitorShares(for: state, config: config)
    }

    /// Pazar payının seçili katta açtığı hücre sayısı.
    var branchSlots: Int {
        guard let spec = currentSpec else { return 1 }
        return GameEngine.branchSlots(for: spec, state: state, config: config)
    }

    /// Kat dolmadığı hâlde şube açılamıyorsa sebep rakiplerdir.
    var isBranchBlockedByMarket: Bool {
        GameEngine.isBranchBlockedByMarket(onFloor: selectedFloor, state, config: config)
    }

    // MARK: - Ödüller ve satın alma (rapor §8)

    /// "Reklamsız" alındı mı?
    var hasRemovedAds: Bool { purchases.hasRemovedAds }

    /// Ödül düğmeleri hiç görünmesin mi? Ne reklam var ne alım — sessiz oyun.
    var showsRewards: Bool { ads.isReady || hasRemovedAds }

    /// Vardiya patlaması bu seansta alınabilir mi?
    var canBoost: Bool { showsRewards && !hasBoostedThisSession && boostRemaining == nil }
    /// Süren vardiya patlamasına kalan süre.
    var boostRemaining: TimeInterval? { GameEngine.boostRemaining(in: state) }
    var boostMultiplier: Double { max(1, config.rewards.boostMultiplier) }
    var boostSeconds: TimeInterval { max(0, config.rewards.boostSeconds) }
    var offlineMultiplier: Double { max(1, config.rewards.offlineMultiplier) }

    /// Dönüş özetindeki katlama teklifi hâlâ açık mı?
    /// Satın alan oyuncuya hiç sorulmaz; katlama zaten uygulanmıştır.
    var canDoubleOffline: Bool {
        guard let report = offlineReport else { return false }
        return ads.isReady && !hasRemovedAds && !hasDoubledThisReturn && report.earned > 0
    }

    /// Çevrimdışı kazancı katla. Reklamsız oyuncuda dönüşte kendiliğinden olur.
    ///
    /// View'ın çağırdığı hâli beklemez; asıl iş `claimingOfflineDouble()`
    /// içinde durur ki testler sonucu deterministik olarak bekleyebilsin.
    func claimOfflineDouble() {
        Task { [weak self] in
            await self?.claimingOfflineDouble()
        }
    }

    func claimingOfflineDouble() async {
        guard let report = offlineReport, !hasDoubledThisReturn, !hasRemovedAds else { return }
        guard await ads.present() else { return }
        applyOfflineDouble(earned: report.earned)
    }

    /// Vardiya patlamasını al. Alan oyuncu sahneyi görmez, doğrudan alır.
    func claimBoost() {
        Task { [weak self] in
            await self?.claimingBoost()
        }
    }

    func claimingBoost() async {
        guard canBoost else { return }
        // Rapor §8: para veren, reklam izleyenden yavaş kalmamalı.
        guard !hasRemovedAds else {
            applyBoost()
            return
        }
        guard await ads.present() else { return }
        applyBoost()
    }

    private func applyOfflineDouble(earned: Double) {
        guard !hasDoubledThisReturn else { return }
        hasDoubledThisReturn = true
        state = GameEngine.grantOfflineBonus(state, earned: earned, config: config)
        if var report = offlineReport {
            report.earned *= offlineMultiplier
            report.wasDoubled = true
            offlineReport = report
        }
        Haptics.play(.success)
        persist()
    }

    private func applyBoost() {
        guard !hasBoostedThisSession else { return }
        hasBoostedThisSession = true
        state = GameEngine.grantShiftBoost(state, config: config)
        Haptics.play(.success)
        persist()
    }

    /// Mağazayı hazırla ve hakları tazele. Açılışta bir kez.
    func prepareStore() {
        Task { [weak self] in
            await self?.purchases.refresh()
        }
    }

    func buyRemoveAds() {
        Task { [weak self] in
            await self?.buyingRemoveAds()
        }
    }

    func buyingRemoveAds() async {
        await purchases.buy()
        // Alım anında dönüş özeti açıksa katlamayı hemen uygula: oyuncu
        // parayı verip ödülü kaçırmasın.
        if purchases.hasRemovedAds, let report = offlineReport, !hasDoubledThisReturn {
            applyOfflineDouble(earned: report.earned)
        }
    }

    func restorePurchases() {
        Task { [weak self] in
            await self?.purchases.restore()
        }
    }

    // MARK: - İç durum

    private let saves: SaveStore
    private let now: @Sendable () -> Date

    /// Satın alma sınırı. StoreKit'i yalnızca bu tip bilir.
    let purchases: any Purchases
    /// Ödüllü reklam sınırı. Bugün ev yapımı sahne, yarın bir SDK.
    let ads: any RewardedAds

    /// Sahneyi oyunun kendisi çiziyorsa onu çizecek nesne.
    /// Gerçek bir SDK bağlanınca `nil` olur ve `AdBreakView` hiç görünmez.
    var houseAds: HouseAds? { ads as? HouseAds }
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var secondsSinceSave: TimeInterval = 0
    /// Olay seans başına bir kez sunulur; uygulama arka plana gidince sıfırlanır.
    @ObservationIgnored private var hasOfferedEventThisSession = false
    /// Vardiya patlaması da seans başına bir kez. Aynı yerden sıfırlanır.
    @ObservationIgnored private var hasBoostedThisSession = false
    /// Çevrimdışı katlama, dönüş özetinde bir kez sunulur.
    @ObservationIgnored private var hasDoubledThisReturn = false

    /// Otomatik kaydetme aralığı. Arka plana geçişte ayrıca kaydediliyor;
    /// bu, uygulama öldürülürse kaybı sınırlamak için.
    private let autosaveInterval: TimeInterval = 20

    // MARK: - Kurulum

    /// - Parameter now: Saat kaynağı. Testlerde sahte saat verilebilsin diye enjekte edilir.
    init(
        config: BalanceConfig,
        saves: SaveStore,
        now: @escaping @Sendable () -> Date = { Date() },
        purchases: any Purchases = MemoryPurchases(),
        ads: any RewardedAds = NoAds()
    ) {
        self.config = config
        self.saves = saves
        self.now = now
        self.purchases = purchases
        self.ads = ads

        let groundSector = config.sectors.first?.id ?? GameState.groundSectorID
        switch saves.load() {
        case .loaded(let loaded):
            self.state = loaded
        case .recovered(let loaded):
            self.state = loaded
            self.didRecoverFromBackup = true
        case .empty:
            self.state = GameState.newGame(characterID: "kahveci", sectorID: groundSector, now: now())
        }
    }

    // MARK: - Sahne fazı

    /// Uygulama öne geldi: uzakta geçen süreyi depo tavanıyla birlikte işle.
    func handleBecameActive() {
        let outcome = GameEngine.resume(state, at: now(), mode: .awayFromApp, config: config)
        state = outcome.state

        hasDoubledThisReturn = false
        if outcome.shouldShowReport {
            offlineReport = OfflineReport(
                awaySeconds: outcome.elapsedSeconds,
                creditedSeconds: outcome.creditedSeconds,
                earned: outcome.earned,
                didFillWarehouse: outcome.didFillWarehouse
            )
            // Rapor §8'in kritik detayı: satın alan oyuncu ödülü **otomatik**
            // alır. Aksi hâlde para veren, reklam izleyenden yavaş ilerlerdi.
            if purchases.hasRemovedAds {
                applyOfflineDouble(earned: outcome.earned)
            }
        }

        runManagerRules(reporting: true)
        offerEventIfDue()
        persist()
        startTicking()
    }

    /// Uygulama arka plana gidiyor: saati damgala, kaydet, zamanlayıcıyı durdur.
    func handleWillResignActive() {
        stopTicking()
        // Yeni seans yeni bir olay hakkı demek. Vardiya patlaması da öyle.
        hasOfferedEventThisSession = false
        hasBoostedThisSession = false
        // Ekranda görünen son saniyeleri de yazalım ki `lastSeenAt` tam olsun.
        let outcome = GameEngine.resume(state, at: now(), mode: .live, config: config)
        state = outcome.state
        persist()
    }

    // MARK: - Zamanlayıcı

    private func startTicking() {
        stopTicking()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    /// Görsel tazeleme adımı. Süreyi saatten okur, motora sorar.
    private func tick() {
        let outcome = GameEngine.resume(state, at: now(), mode: .live, config: config)
        state = outcome.state

        runManagerRules(reporting: false)
        offerEventIfDue()

        secondsSinceSave += outcome.creditedSeconds
        if secondsSinceSave >= autosaveInterval {
            persist()
            secondsSinceSave = 0
        }
    }

    /// Müdürlerin kurallarını işlet.
    ///
    /// `advance` içinde değil ondan sonra: satın alma oranı değiştirir ve bunu
    /// kapalı forma katmak motoru döngüye çevirirdi.
    private func runManagerRules(reporting: Bool) {
        guard state.hasRoof else { return }
        let outcome = GameEngine.applyRules(state, config: config)
        guard !outcome.actions.isEmpty else { return }

        state = outcome.state
        if reporting {
            managerReport = outcome.actions
        }
    }

    /// Sırası gelmiş bir olay varsa sun. Seans başına en fazla bir kez —
    /// olay kısa seansa yakıt, angarya değil.
    private func offerEventIfDue() {
        // Müdür olayları kendi hallediyorsa oyuncuyu rahatsız etme.
        guard !state.autoResolvesEvents else { return }
        guard pendingEvent == nil, !hasOfferedEventThisSession else { return }
        guard let event = GameEngine.pendingEvent(for: state, config: config) else { return }
        pendingEvent = event
        hasOfferedEventThisSession = true
        Haptics.play(.medium)
    }

    // MARK: - Eylemler

    func sellManually() {
        lastActionError = nil
        state = GameEngine.sellManually(onFloor: selectedFloor, state, config: config)
        Haptics.play(.light)
    }

    func hireStaff() {
        let wasFirstEver = !state.hasCelebratedFirstHire
        switch GameEngine.hireStaff(onFloor: selectedFloor, state, config: config) {
        case .success(var next):
            lastActionError = nil
            if wasFirstEver, let hired = next.floors[safe: selectedFloor]?.staff.last {
                // Oyunun ilk büyük ödül anı: iş artık sensiz de yürüyor.
                next.hasCelebratedFirstHire = true
                state = next
                firstHireCelebration = hired
                Haptics.play(.success)
            } else {
                state = next
                Haptics.play(.medium)
            }
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    func upgradeEquipment(_ id: String) {
        apply(GameEngine.upgradeEquipment(id, onFloor: selectedFloor, state, config: config))
    }

    func openBranch() {
        apply(GameEngine.openBranch(onFloor: selectedFloor, state, config: config), success: .success)
    }

    func upgradeWarehouse() {
        apply(GameEngine.upgradeWarehouse(state, config: config))
    }

    /// Faz 3: bir üst katı aç — yeni bir sektöre gir.
    func unlockNextFloor() {
        let opening = nextSector?.id
        switch GameEngine.unlockNextFloor(state, config: config) {
        case .success(let next):
            state = next
            lastActionError = nil
            newFloorCelebration = opening
            Haptics.play(.success)
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    /// Çatı katını aç — yönetim ofisi.
    func unlockRoof() {
        apply(GameEngine.unlockRoof(state, config: config), success: .success)
    }

    /// Seçili kata müdür ata.
    func hireManager() {
        guard let floor = currentFloor else { return }
        apply(GameEngine.hireManager(forSector: floor.sectorID, state, config: config))
    }

    /// Seçili katta bir kuralı aç ya da kapat.
    func setRule(_ ruleID: String, enabled: Bool) {
        guard let floor = currentFloor else { return }
        switch GameEngine.setRule(ruleID, enabled: enabled, forSector: floor.sectorID, state, config: config) {
        case .success(let next):
            state = next
            lastActionError = nil
            Haptics.play(.light)
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    func setAutoResolvesEvents(_ enabled: Bool) {
        state = GameEngine.setAutoResolvesEvents(enabled, state)
        Haptics.play(.light)
        persist()
    }

    func dismissManagerReport() {
        managerReport = []
    }

    // MARK: - Yumuşak prestij

    /// Olgunlaşan sektörü sat. Kat yok olmaz, yatırım katına dönüşür.
    func sellSector() {
        guard let floor = currentFloor else { return }
        let sold = floor.sectorID
        switch GameEngine.sellSector(onFloor: selectedFloor, state, config: config) {
        case .success(let next):
            state = next
            lastActionError = nil
            sectorSaleCelebration = sold
            Haptics.play(.success)
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    func dismissSectorSaleCelebration() {
        sectorSaleCelebration = nil
    }

    /// Holdingi halka arz et. Özet **sıfırlamadan önce** alınır: final sahnesi
    /// biten şehri anlatır, yeni başlayanı değil.
    func goPublic() {
        let summary = FinaleSummary(
            cityNumber: state.cityNumber,
            lifetimeEarnings: state.lifetimeEarnings,
            playedSeconds: state.elapsedGameSeconds,
            sectorsSold: state.stats.sectorsSold,
            manualSales: state.stats.manualSales,
            holdingPoints: state.holdingPoints + max(0, config.prestige.pointsPerCity)
        )
        switch GameEngine.goPublic(state, config: config) {
        case .success(let next):
            state = next
            lastActionError = nil
            finale = summary
            Haptics.play(.success)
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    func dismissFinale() {
        finale = nil
    }

    func selectFloor(_ index: Int) {
        guard index != state.selectedFloor else { return }
        state = GameEngine.selectFloor(index, state)
        lastActionError = nil
        Haptics.play(.light)
    }

    /// Satın alma sonuçlarının ortak yolu: durumu yaz, dokunsal geri bildirimi
    /// ver, kaydet. Başarısızlıkta sebebi ekrana taşı.
    private func apply(
        _ result: Result<GameState, GameEngine.ActionError>,
        success feedback: Haptics.Kind = .medium
    ) {
        switch result {
        case .success(let next):
            state = next
            lastActionError = nil
            Haptics.play(feedback)
            persist()
        case .failure(let error):
            lastActionError = error
            Haptics.play(.warning)
        }
    }

    /// Olayın bir seçeneğini uygula.
    func resolveEvent(_ eventID: String, choice choiceID: String) {
        switch GameEngine.resolveEvent(eventID, choice: choiceID, state, config: config) {
        case .success(let next):
            state = next
            pendingEvent = nil
            lastActionError = nil
            Haptics.play(.success)
            persist()
        case .failure(let error):
            lastActionError = error
            pendingEvent = nil
            Haptics.play(.warning)
        }
    }

    /// Olayı karara bağlamadan kapat.
    func dismissEvent() {
        state = GameEngine.dismissEvent(state, config: config)
        pendingEvent = nil
        persist()
    }

    func dismissOfflineReport() {
        offlineReport = nil
    }

    func dismissFirstHireCelebration() {
        firstHireCelebration = nil
    }

    func dismissNewFloorCelebration() {
        newFloorCelebration = nil
    }

    /// Sıfırdan başla. Geliştirme kolaylığı; ilerideki "yeni oyun" da bunu kullanacak.
    func startOver() {
        stopTicking()
        saves.deleteAll()
        state = GameState.newGame(
            characterID: "kahveci",
            sectorID: config.sectors.first?.id ?? GameState.groundSectorID,
            now: now()
        )
        offlineReport = nil
        firstHireCelebration = nil
        newFloorCelebration = nil
        pendingEvent = nil
        managerReport = []
        sectorSaleCelebration = nil
        finale = nil
        hasOfferedEventThisSession = false
        hasBoostedThisSession = false
        hasDoubledThisReturn = false
        lastActionError = nil
        didRecoverFromBackup = false
        didFailToSave = false
        secondsSinceSave = 0
        persist()
        startTicking()
    }

    // MARK: - Kayıt

    private func persist() {
        do {
            try saves.save(state)
            didFailToSave = false
        } catch {
            didFailToSave = true
        }
    }
}

private extension Array {
    /// Sınır dışı indeks çökme değil `nil` versin.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Ekipman şeridinin bir satırı.
struct EquipmentRow: Identifiable, Equatable, Sendable {
    let id: String
    var level: Int
    var maxLevel: Int
    /// Bu seviyenin üretim çarpanı.
    var multiplier: Double
    /// Sonraki seviyenin ücreti; son seviyedeyse `nil`.
    var upgradeCost: Double?

    var isMaxed: Bool { upgradeCost == nil }
}

/// Çevrimdışı dönüş özeti — ekranda gösterilen hâli.
/// Halka arz özeti. Biten şehrin rakamlarını taşır — final sahnesi bunu okur.
struct FinaleSummary: Identifiable, Equatable {
    let id = UUID()
    var cityNumber: Int
    var lifetimeEarnings: Double
    var playedSeconds: TimeInterval
    var sectorsSold: Int
    var manualSales: Int
    /// Yeni şehre taşınan puan — halka arzın kazandırdığı dahil.
    var holdingPoints: Int
}

struct OfflineReport: Identifiable, Equatable {
    let id = UUID()
    var awaySeconds: TimeInterval
    var creditedSeconds: TimeInterval
    var earned: Double
    var didFillWarehouse: Bool
    /// Ödül alındı mı? Alındıysa `earned` katlanmış tutarı gösterir.
    var wasDoubled = false
}
