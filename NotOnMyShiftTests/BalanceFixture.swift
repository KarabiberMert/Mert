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
        plannedFloors: Int = 8
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
            offline: .init(minimumReportSeconds: minimumReportSeconds)
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
        return state
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
