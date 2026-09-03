import XCTest
@testable import NotOnMyShift

/// Faz 4: olaylar ve rakipler.
///
/// İki kritik davranış burada ölçülüyor:
/// 1. Süreli etkiler `advance`'i segmentlere böler ama kapalı form kalır.
/// 2. Rakip oyuncunun **mevcut gelirini asla düşürmez** — sadece açılabilecek
///    yeni hücre sayısını kısar (tasarım raporu §6).
final class EventAndMarketTests: XCTestCase {

    private let config = BalanceFixture.config(wagePerSecond: 0.25)
    private var ground: BalanceConfig.SectorSpec { config.sectors[0] }

    /// 2 eleman: brüt 3/sn, maaş 0,5/sn, net 2,5/sn.
    private func working(money: Double = 0) -> GameState {
        BalanceFixture.state(money: money, staffCount: 2, config: config)
    }

    private func boosted(_ state: GameState, multiplier: Double, seconds: TimeInterval) -> GameState {
        var next = state
        next.modifiers.append(
            ActiveModifier(
                eventID: "boostEvent", choiceID: "boost",
                multiplier: multiplier,
                endsAtGameSeconds: state.elapsedGameSeconds + seconds
            )
        )
        return next
    }

    // MARK: - Segmentli ilerleme

    func testAdvanceSplitsAtTheEndOfAnEffect() {
        // 60 sn boyunca ×3, sonra normal. 120 sn ilerlet:
        // brüt 3×3 − maaş 0,5 = 8,5/sn × 60  +  2,5/sn × 60 = 510 + 150 = 660
        let state = boosted(working(), multiplier: 3, seconds: 60)

        let next = GameEngine.advance(state, by: 120, config: config)

        XCTAssertEqual(next.money, 660, accuracy: 1e-6)
        XCTAssertTrue(next.modifiers.isEmpty, "Süresi dolan etki düşmeli")
    }

    func testSegmentedAdvanceMatchesSecondBySecond() {
        // Kırılım noktası varken de kapalı form ile adım adım aynı sonucu vermeli.
        let state = boosted(working(), multiplier: 3, seconds: 45)

        let single = GameEngine.advance(state, by: 300, config: config)

        var stepped = state
        for _ in 0..<300 {
            stepped = GameEngine.advance(stepped, by: 1, config: config)
        }

        XCTAssertEqual(single.money, stepped.money, accuracy: 1e-6)
        XCTAssertEqual(single.elapsedGameSeconds, stepped.elapsedGameSeconds, accuracy: 1e-6)
    }

    func testOverlappingEffectsMultiplyAndExpireIndependently() {
        var state = boosted(working(), multiplier: 2, seconds: 30)
        state = boosted(state, multiplier: 3, seconds: 60)
        XCTAssertEqual(GameEngine.eventMultiplier(for: state), 6, accuracy: 1e-9)

        // 0-30 sn: ×6 → 3×6 − 0,5 = 17,5/sn → 525
        // 30-60 sn: ×3 → 3×3 − 0,5 = 8,5/sn → 255
        // 60-90 sn: ×1 → 2,5/sn → 75
        let next = GameEngine.advance(state, by: 90, config: config)
        XCTAssertEqual(next.money, 525 + 255 + 75, accuracy: 1e-6)
        XCTAssertTrue(next.modifiers.isEmpty)
    }

    func testEffectAppliesToGrossNotToWages() {
        // Yavaşlatan bir olayda maaş yine ödenir: brüt 3×0,5 = 1,5 − 0,5 = 1/sn
        let slowed = boosted(working(), multiplier: 0.5, seconds: 3_600)
        XCTAssertEqual(GameEngine.productionRate(for: slowed, config: config), 1.0, accuracy: 1e-9)
    }

    func testASevereSlowdownStillNeverGoesNegative() {
        let stopped = boosted(working(), multiplier: 0, seconds: 60)
        XCTAssertEqual(GameEngine.productionRate(for: stopped, config: config), 0, accuracy: 1e-9)

        let next = GameEngine.advance(stopped, by: 30, config: config)
        XCTAssertEqual(next.money, stopped.money, accuracy: 1e-9, "Borç birikmemeli")
    }

    func testOfflineTimeConsumesEffectsCorrectly() {
        // Uzaktayken de etki doğru anda biter.
        let state = boosted(working(), multiplier: 3, seconds: 60)
        let outcome = GameEngine.resume(
            state,
            at: BalanceFixture.epoch.addingTimeInterval(120),
            mode: .awayFromApp,
            config: config
        )
        XCTAssertEqual(outcome.earned, 660, accuracy: 1e-6)
        XCTAssertTrue(outcome.state.modifiers.isEmpty)
    }

    // MARK: - Olay sunumu

    func testNoEventBeforeTheFirstWindow() {
        let fresh = BalanceFixture.state(config: config)
        XCTAssertNil(GameEngine.pendingEvent(for: fresh, config: config))

        let later = GameEngine.advance(fresh, by: 100, config: config)
        XCTAssertNotNil(GameEngine.pendingEvent(for: later, config: config))
    }

    func testPendingEventIsStableForTheSameState() {
        let state = GameEngine.advance(working(), by: 200, config: config)
        let first = GameEngine.pendingEvent(for: state, config: config)
        let second = GameEngine.pendingEvent(for: state, config: config)

        XCTAssertNotNil(first)
        XCTAssertEqual(first?.id, second?.id, "Aynı durum aynı olayı vermeli")
    }

    func testDifferentSeedsCanGiveDifferentEvents() {
        // Rastgelelik tohumdan geliyor; farklı kayıtlar farklı olay görmeli.
        var seen: Set<String> = []
        for seed in UInt64(1)...40 {
            var state = GameEngine.advance(working(), by: 200, config: config)
            state.eventSeed = seed
            if let event = GameEngine.pendingEvent(for: state, config: config) {
                seen.insert(event.id)
            }
        }
        XCTAssertEqual(seen.count, 2, "İki olay da çıkabilmeli, gördüklerimiz: \(seen)")
    }

    // MARK: - Olay sonucu

    func testInstantRewardScalesWithCurrentProduction() {
        // "cash" seçeneği 10 saniyelik üretim: 2,5/sn × 10 = 25
        let state = GameEngine.advance(working(), by: 200, config: config)
        let before = state.money

        guard case .success(let next) = GameEngine.resolveEvent("boostEvent", choice: "cash", state, config: config) else {
            return XCTFail("Olay karara bağlanamadı")
        }
        XCTAssertEqual(next.money - before, 25, accuracy: 1e-6)
        XCTAssertEqual(next.stats.eventsResolved, 1)
    }

    func testInstantCostNeverTakesTheCashBoxBelowZero() {
        var state = working(money: 5)
        state = GameEngine.advance(state, by: 200, config: config)
        let poor = { () -> GameState in
            var copy = state
            copy.money = 5      // ceza 10 sn × 2,5 = 25, kasada 5 var
            return copy
        }()

        guard case .success(let next) = GameEngine.resolveEvent("costEvent", choice: "fine", poor, config: config) else {
            return XCTFail("Olay karara bağlanamadı")
        }
        XCTAssertEqual(next.money, 0, accuracy: 1e-9, "Oyuncu geri gitmez, sıfırda durur")
    }

    func testChoosingATimedEffectStartsIt() {
        let state = GameEngine.advance(working(), by: 200, config: config)

        guard case .success(let next) = GameEngine.resolveEvent("boostEvent", choice: "boost", state, config: config) else {
            return XCTFail("Olay karara bağlanamadı")
        }
        XCTAssertEqual(next.modifiers.count, 1)
        XCTAssertEqual(GameEngine.eventMultiplier(for: next), 3, accuracy: 1e-9)
        XCTAssertEqual(
            next.modifiers[0].endsAtGameSeconds, state.elapsedGameSeconds + 60, accuracy: 1e-6
        )
    }

    func testResolvingSchedulesTheNextEventAndMovesTheSeed() {
        let state = GameEngine.advance(working(), by: 200, config: config)

        guard case .success(let next) = GameEngine.resolveEvent("boostEvent", choice: "cash", state, config: config) else {
            return XCTFail("Olay karara bağlanamadı")
        }
        // Jitter 0 → aralık tam olarak gapSeconds.
        XCTAssertEqual(next.nextEventAtGameSeconds, state.elapsedGameSeconds + 1_000, accuracy: 1e-6)
        XCTAssertNotEqual(next.eventSeed, state.eventSeed, "Tohum ilerlemeli")
        XCTAssertNil(GameEngine.pendingEvent(for: next, config: config))
    }

    func testDismissingSchedulesWithoutAnyEffect() {
        let state = GameEngine.advance(working(), by: 200, config: config)
        let next = GameEngine.dismissEvent(state, config: config)

        XCTAssertEqual(next.money, state.money, accuracy: 1e-9)
        XCTAssertTrue(next.modifiers.isEmpty)
        XCTAssertEqual(next.stats.eventsResolved, 0)
        XCTAssertNil(GameEngine.pendingEvent(for: next, config: config))
    }

    func testUnknownEventOrChoiceFailsCleanly() {
        let state = GameEngine.advance(working(), by: 200, config: config)

        guard case .failure(let missingEvent) = GameEngine.resolveEvent("yok", choice: "cash", state, config: config) else {
            return XCTFail("Tanınmayan olay geçmemeli")
        }
        XCTAssertEqual(missingEvent, .unknownEvent)

        guard case .failure(let missingChoice) = GameEngine.resolveEvent("boostEvent", choice: "yok", state, config: config) else {
            return XCTFail("Tanınmayan seçenek geçmemeli")
        }
        XCTAssertEqual(missingChoice, .unknownEvent)
    }

    // MARK: - Pazar payı

    func testShareDriftsToCompetitorsAndStopsAtTheFloor() {
        let state = working()
        XCTAssertEqual(GameEngine.marketShare(for: state, config: config), 0.5, accuracy: 1e-9)

        // 0,001/sn × 100 sn = 0,1
        let after = GameEngine.advance(state, by: 100, config: config)
        XCTAssertEqual(GameEngine.marketShare(for: after, config: config), 0.4, accuracy: 1e-9)

        let muchLater = GameEngine.advance(state, by: 100_000, config: config)
        XCTAssertEqual(
            GameEngine.marketShare(for: muchLater, config: config), 0.2, accuracy: 1e-9,
            "Pay tabanın altına inmez"
        )
    }

    func testInvestingWinsShareBack() {
        var state = working(money: 10_000)
        state = GameEngine.advance(state, by: 200, config: config)     // pay 0,3
        let before = GameEngine.marketShare(for: state, config: config)

        guard case .success(let next) = GameEngine.upgradeEquipment("grinder", onFloor: 0, state, config: config) else {
            return XCTFail("Ekipman yükseltilemedi")
        }
        XCTAssertEqual(
            GameEngine.marketShare(for: next, config: config), before + 0.1, accuracy: 1e-9,
            "Yatırım pay kazandırmalı"
        )
    }

    func testShareIsClampedToOne() {
        var state = working(money: 1_000_000)
        state.marketShare = 0.98
        guard case .success(let next) = GameEngine.upgradeWarehouse(state, config: config) else {
            return XCTFail("Depo yükseltilemedi")
        }
        XCTAssertEqual(GameEngine.marketShare(for: next, config: config), 1, accuracy: 1e-9)
    }

    func testCompetitorSharesFillWhatIsLeft() {
        var state = working()
        state.marketShare = 0.6
        let rivals = GameEngine.competitorShares(for: state, config: config)

        XCTAssertEqual(rivals.count, 2)
        XCTAssertEqual(rivals.reduce(0) { $0 + $1.share }, 0.4, accuracy: 1e-9)
        XCTAssertEqual(rivals[0].share, rivals[1].share, accuracy: 1e-9, "Eşit ağırlık, eşit pay")
    }

    // MARK: - Cezalandırmama kuralı

    func testShareGatesNewUnitsOnly() {
        var state = working(money: 1_000_000)

        state.marketShare = 1.0
        XCTAssertEqual(GameEngine.branchSlots(for: ground, state: state, config: config), 3)

        state.marketShare = 0.5
        XCTAssertEqual(GameEngine.branchSlots(for: ground, state: state, config: config), 2)

        state.marketShare = 0.2
        XCTAssertEqual(GameEngine.branchSlots(for: ground, state: state, config: config), 1)
    }

    func testBranchIsDelayedNotDenied() {
        var state = working(money: 1_000_000)
        state.marketShare = 0.2                               // sadece bir hücre

        XCTAssertNil(GameEngine.availableBranchCost(onFloor: 0, state, config: config))
        XCTAssertTrue(GameEngine.isBranchBlockedByMarket(onFloor: 0, state, config: config))
        guard case .failure(let error) = GameEngine.openBranch(onFloor: 0, state, config: config) else {
            return XCTFail("Pay yetmezken şube açılmamalı")
        }
        XCTAssertEqual(error, .marketShareTooLow)

        // Yatırım yapınca pay geri gelir ve kapı açılır.
        guard case .success(let invested) = GameEngine.upgradeEquipment("grinder", onFloor: 0, state, config: config),
              case .success(let again) = GameEngine.upgradeEquipment("grinder", onFloor: 0, invested, config: config) else {
            return XCTFail("Yatırım yapılamadı")
        }
        XCTAssertEqual(GameEngine.marketShare(for: again, config: config), 0.4, accuracy: 1e-9)
        XCTAssertNotNil(GameEngine.availableBranchCost(onFloor: 0, again, config: config))
    }

    func testFallingShareNeverClosesAnOpenBranchOrCutsIncome() {
        // Tasarım raporunun cezalandırmama kuralı. Üç şube açıkken pay dibe
        // vursa bile üretim aynı kalmalı.
        var state = BalanceFixture.state(money: 0, staffCount: 2, branchCount: 3, config: config)
        state.marketShare = 1.0
        let richIncome = GameEngine.productionRate(for: state, config: config)

        var starved = state
        starved.marketShare = config.market.minimumShare

        XCTAssertEqual(starved.floors[0].branchCount, 3, "Açılmış şube kapanmaz")
        XCTAssertEqual(
            GameEngine.productionRate(for: starved, config: config), richIncome, accuracy: 1e-9,
            "Rakip mevcut geliri asla düşürmez"
        )
        // Sadece dördüncüyü açmak engellenir — zaten kat sınırı da üç.
        XCTAssertNil(GameEngine.availableBranchCost(onFloor: 0, starved, config: config))
    }

    func testLongAbsenceCostsOpportunityNotMoney() {
        // Üç gün uğramamak parayı azaltmaz; sadece hücre hakkını daraltır.
        let state = BalanceFixture.state(money: 500, staffCount: 2, config: config)
        let before = GameEngine.branchSlots(for: ground, state: state, config: config)

        let returned = GameEngine.advance(state, by: 3 * 86_400, config: config)

        XCTAssertGreaterThan(returned.money, state.money, "Uzaktayken para birikir")
        XCTAssertLessThan(
            GameEngine.branchSlots(for: ground, state: returned, config: config), before,
            "Kaçırılan şey fırsat"
        )
    }
}
