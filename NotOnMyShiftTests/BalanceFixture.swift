import Foundation
@testable import NotOnMyShift

/// Testler yuvarlak sayılarla çalışır. Böylece denge ayarı değiştiğinde
/// testler kırılmaz — testler motoru ölçer, dengeyi değil.
///
/// `balance.json`'ın kendisi ayrıca `testShippedBalanceParses` ile doğrulanıyor.
enum BalanceFixture {

    /// Zemin kat: yuvarlak sayılar. Çarpanlar 1,0 / 2,0 / 0,5.
    static func groundSector(
        revenuePerSale: Double = 10,
        ratePerSecond: Double = 1,
        baseCost: Double = 100,
        costGrowth: Double = 2,
        maxStaff: Int = 3,
        // Varsayılan 0: maaşla ilgilenmeyen testler Faz 1'deki gibi ölçer.
        wagePerSecond: Double = 0
    ) -> BalanceConfig.SectorSpec {
        BalanceConfig.SectorSpec(
            id: "coffee",
            unlockCost: 0,
            manual: .init(revenuePerSale: revenuePerSale),
            staff: .init(
                ratePerSecond: ratePerSecond,
                baseCost: baseCost,
                costGrowth: costGrowth,
                maxCount: maxStaff,
                wagePerSecond: wagePerSecond
            ),
            // Tek parça, yuvarlak çarpanlar: 1 → 2 → 4.
            equipment: [
                .init(id: "grinder", levels: [
                    .init(cost: 0, multiplier: 1),
                    .init(cost: 50, multiplier: 2),
                    .init(cost: 200, multiplier: 4)
                ])
            ],
            branches: .init(baseCost: 500, costGrowth: 10, maxCount: 3),
            // Kimlikler katalogdakilerle aynı ki isim çözümü de test edilsin;
            // çarpanlar bilerek yuvarlak, gönderilen dengeyle ilgisi yok.
            staffPool: [
                .init(id: "quick", rateMultiplier: 1.0),
                .init(id: "opener", rateMultiplier: 2.0),
                .init(id: "chatty", rateMultiplier: 0.5)
            ]
        )
    }

    /// Birinci kat: on kat daha büyük sayılar, ayrı havuz.
    static func upperSector(unlockCost: Double = 1_000) -> BalanceConfig.SectorSpec {
        BalanceConfig.SectorSpec(
            id: "bakery",
            unlockCost: unlockCost,
            manual: .init(revenuePerSale: 100),
            staff: .init(
                ratePerSecond: 10,
                baseCost: 1_000,
                costGrowth: 2,
                maxCount: 2,
                wagePerSecond: 1
            ),
            equipment: [
                .init(id: "oven", levels: [
                    .init(cost: 0, multiplier: 1),
                    .init(cost: 5_000, multiplier: 3)
                ])
            ],
            branches: .init(baseCost: 20_000, costGrowth: 10, maxCount: 2),
            staffPool: [
                .init(id: "baker", rateMultiplier: 1.0),
                .init(id: "kneader", rateMultiplier: 2.0)
            ]
        )
    }

    static func config(
        revenuePerSale: Double = 10,
        ratePerSecond: Double = 1,
        baseCost: Double = 100,
        costGrowth: Double = 2,
        maxStaff: Int = 3,
        wagePerSecond: Double = 0,
        minimumReportSeconds: TimeInterval = 60,
        upperUnlockCost: Double = 1_000,
        plannedFloors: Int = 8,
        roofCost: Double = 1_000,
        managerBaseCost: Double = 200,
        // Varsayılan 0: otomasyonu ölçen testler yedeği ayrıca açar.
        reserveSeconds: Double = 0,
        maxActionsPerVisit: Int = 20,
        payoutSeconds: Double = 100,
        investmentShare: Double = 0.1,
        pointsPerSale: Int = 1,
        pointsPerCity: Int = 2,
        multiplierPerPoint: Double = 0.5,
        offlineRewardMultiplier: Double = 2,
        boostMultiplier: Double = 3,
        boostSeconds: Double = 60
    ) -> BalanceConfig {
        BalanceConfig(
            version: 1,
            building: .init(paletteFloors: plannedFloors),
            sectors: [
                groundSector(
                    revenuePerSale: revenuePerSale,
                    ratePerSecond: ratePerSecond,
                    baseCost: baseCost,
                    costGrowth: costGrowth,
                    maxStaff: maxStaff,
                    wagePerSecond: wagePerSecond
                ),
                upperSector(unlockCost: upperUnlockCost)
            ],
            warehouse: .init(levels: [
                .init(capacitySeconds: 3_600, cost: 0),        // 1 saat
                .init(capacitySeconds: 28_800, cost: 500),     // 8 saat
                .init(capacitySeconds: 86_400, cost: 1_500)    // 24 saat
            ]),
            offline: .init(minimumReportSeconds: minimumReportSeconds),
            // Jitter 0: testlerde olay aralığı tam olarak gapSeconds.
            events: .init(
                firstAfterSeconds: 100,
                gapSeconds: 1_000,
                gapJitter: 0,
                specs: [
                    .init(id: "boostEvent", weight: 1, choices: [
                        .init(id: "boost", multiplier: 3, durationSeconds: 60, instantSeconds: 0),
                        .init(id: "cash", multiplier: 1, durationSeconds: 0, instantSeconds: 10)
                    ]),
                    .init(id: "costEvent", weight: 1, choices: [
                        .init(id: "fine", multiplier: 1, durationSeconds: 0, instantSeconds: -10),
                        .init(id: "slow", multiplier: 0.5, durationSeconds: 60, instantSeconds: 0)
                    ])
                ]
            ),
            market: .init(
                startShare: 0.5,
                minimumShare: 0.2,
                driftPerSecond: 0.001,
                sharePerPurchase: 0.1,
                competitors: [.init(id: "cedar", weight: 1), .init(id: "mill", weight: 1)]
            ),
            // Yuvarlak sayılar: üç kural, kural başına %10, tavan %30.
            process: .init(
                roofCost: roofCost,
                managerBaseCost: managerBaseCost,
                managerCostGrowth: 2,
                bonusPerRule: 0.1,
                maxBonus: 0.3,
                reserveSeconds: reserveSeconds,
                maxActionsPerVisit: maxActionsPerVisit,
                rules: [.init(id: "hire"), .init(id: "equip"), .init(id: "branch")]
            ),
            // Yuvarlak sayılar: satış 100 saniyelik net, yatırım katı onda biri,
            // her puan brütü yarım kat artırır.
            prestige: .init(
                payoutSeconds: payoutSeconds,
                investmentShare: investmentShare,
                pointsPerSale: pointsPerSale,
                pointsPerCity: pointsPerCity,
                multiplierPerPoint: multiplierPerPoint
            ),
            // Ödüller isteğe bağlı: hiçbiri alınmazsa oyun tam çalışır.
            rewards: .init(
                offlineMultiplier: offlineRewardMultiplier,
                boostMultiplier: boostMultiplier,
                boostSeconds: boostSeconds
            )
        )
    }

    /// Sabit bir başlangıç anı — testler takvim saatinden bağımsız olsun.
    static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    /// Tek katlı bir durum. `staffCount` zemin kata alınır.
    static func state(
        money: Double = 0,
        staffCount: Int = 0,
        warehouseLevel: Int = 0,
        equipmentLevels: [String: Int] = [:],
        branchCount: Int = 1,
        extraFloors: [FloorState] = [],
        selectedFloor: Int = 0,
        lastSeenAt: Date = epoch,
        config: BalanceConfig = BalanceFixture.config()
    ) -> GameState {
        var state = GameState.newGame(characterID: "kahveci", now: lastSeenAt)
        state.money = money
        state.warehouseLevel = warehouseLevel

        var ground = FloorState(
            sectorID: config.sectors[0].id,
            equipmentLevels: equipmentLevels,
            branchCount: branchCount
        )
        for index in 0..<staffCount {
            let template = config.sectors[0].staffPool[index]
            ground.staff.append(
                StaffMember(id: template.id, rateMultiplier: template.rateMultiplier, hiredAtGameSeconds: 0)
            )
        }
        state.floors = [ground] + extraFloors
        state.selectedFloor = selectedFloor
        // Testler dengedeki başlangıç payıyla başlasın; `unset` bırakmak
        // motorun normalleştirmesine bırakırdı ve ölçüm bulanıklaşırdı.
        state.marketShare = config.market.startShare
        state.nextEventAtGameSeconds = config.events.firstAfterSeconds
        return state
    }

    /// Olgunlaşmış bir kat: tam kadro, tüm ekipman, tüm hücreler.
    /// `sellSector` ve `canGoPublic` testleri bunun üstünden ölçer.
    static func matureFloor(
        sectorIndex: Int = 0,
        config: BalanceConfig = BalanceFixture.config()
    ) -> FloorState {
        guard let spec = config.sector(at: sectorIndex) else {
            return FloorState(sectorID: GameState.groundSectorID)
        }
        var levels: [String: Int] = [:]
        for item in spec.equipment {
            levels[item.id] = max(0, item.levels.count - 1)
        }
        var floor = FloorState(
            sectorID: spec.id,
            equipmentLevels: levels,
            branchCount: max(1, spec.branches.maxCount)
        )
        let capacity = min(max(0, spec.staff.maxCount), spec.staffPool.count)
        for index in 0..<capacity {
            let template = spec.staffPool[index]
            floor.staff.append(
                StaffMember(id: template.id, rateMultiplier: template.rateMultiplier, hiredAtGameSeconds: 0)
            )
        }
        return floor
    }

    /// Kadrosu hazır bir üst kat.
    static func upperFloor(
        staffCount: Int = 0,
        equipmentLevels: [String: Int] = [:],
        branchCount: Int = 1,
        config: BalanceConfig = BalanceFixture.config()
    ) -> FloorState {
        var floor = FloorState(
            sectorID: config.sectors[1].id,
            equipmentLevels: equipmentLevels,
            branchCount: branchCount
        )
        for index in 0..<staffCount {
            let template = config.sectors[1].staffPool[index]
            floor.staff.append(
                StaffMember(id: template.id, rateMultiplier: template.rateMultiplier, hiredAtGameSeconds: 0)
            )
        }
        return floor
    }
}
