import Foundation
@testable import NotOnMyShift

/// Testler yuvarlak sayılarla çalışır. Böylece denge ayarı değiştiğinde
/// testler kırılmaz — testler motoru ölçer, dengeyi değil.
///
/// `balance.json`'ın kendisi ayrıca `testShippedBalanceParses` ile doğrulanıyor.
enum BalanceFixture {

    static func config(
        revenuePerSale: Double = 10,
        ratePerSecond: Double = 1,
        baseCost: Double = 100,
        costGrowth: Double = 2,
        maxStaff: Int = 3,
        minimumReportSeconds: TimeInterval = 60
    ) -> BalanceConfig {
        BalanceConfig(
            version: 1,
            manual: .init(revenuePerSale: revenuePerSale),
            staff: .init(
                ratePerSecond: ratePerSecond,
                baseCost: baseCost,
                costGrowth: costGrowth,
                maxCount: maxStaff
            ),
            warehouse: .init(levels: [
                .init(capacitySeconds: 3_600, cost: 0),        // 1 saat
                .init(capacitySeconds: 28_800, cost: 500),     // 8 saat
                .init(capacitySeconds: 86_400, cost: 1_500)    // 24 saat
            ]),
            offline: .init(minimumReportSeconds: minimumReportSeconds),
            staffPool: [
                .init(id: "bir", name: "Bir", trait: "Normal", rateMultiplier: 1.0),
                .init(id: "iki", name: "İki", trait: "Hızlı", rateMultiplier: 2.0),
                .init(id: "uc", name: "Üç", trait: "Yavaş", rateMultiplier: 0.5)
            ]
        )
    }

    /// Sabit bir başlangıç anı — testler takvim saatinden bağımsız olsun.
    static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    static func state(
        money: Double = 0,
        staffCount: Int = 0,
        warehouseLevel: Int = 0,
        lastSeenAt: Date = epoch,
        config: BalanceConfig = BalanceFixture.config()
    ) -> GameState {
        var state = GameState.newGame(characterID: "kahveci", now: lastSeenAt)
        state.money = money
        state.warehouseLevel = warehouseLevel
        for index in 0..<staffCount {
            let template = config.staffPool[index]
            state.staff.append(
                StaffMember(
                    id: template.id,
                    name: template.name,
                    trait: template.trait,
                    rateMultiplier: template.rateMultiplier,
                    hiredAtGameSeconds: 0
                )
            )
        }
        return state
    }
}
