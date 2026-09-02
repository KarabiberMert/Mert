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
        // Varsayılan 0: maaşla ilgilenmeyen testler Faz 1'deki gibi ölçer.
        wagePerSecond: Double = 0,
        minimumReportSeconds: TimeInterval = 60
    ) -> BalanceConfig {
        BalanceConfig(
            version: 1,
            sector: .init(id: "test_sektor"),
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
            warehouse: .init(levels: [
                .init(capacitySeconds: 3_600, cost: 0),        // 1 saat
                .init(capacitySeconds: 28_800, cost: 500),     // 8 saat
                .init(capacitySeconds: 86_400, cost: 1_500)    // 24 saat
            ]),
            offline: .init(minimumReportSeconds: minimumReportSeconds),
            // Kimlikler katalogdakilerle aynı ki isim çözümü de test edilsin;
            // çarpanlar bilerek yuvarlak, gönderilen dengeyle ilgisi yok.
            staffPool: [
                .init(id: "quick", rateMultiplier: 1.0),
                .init(id: "opener", rateMultiplier: 2.0),
                .init(id: "chatty", rateMultiplier: 0.5)
            ]
        )
    }

    /// Sabit bir başlangıç anı — testler takvim saatinden bağımsız olsun.
    static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    static func state(
        money: Double = 0,
        staffCount: Int = 0,
        warehouseLevel: Int = 0,
        equipmentLevels: [String: Int] = [:],
        branchCount: Int = 1,
        lastSeenAt: Date = epoch,
        config: BalanceConfig = BalanceFixture.config()
    ) -> GameState {
        var state = GameState.newGame(characterID: "kahveci", now: lastSeenAt)
        state.money = money
        state.warehouseLevel = warehouseLevel
        state.equipmentLevels = equipmentLevels
        state.branchCount = branchCount
        for index in 0..<staffCount {
            let template = config.staffPool[index]
            state.staff.append(
                StaffMember(id: template.id, rateMultiplier: template.rateMultiplier, hiredAtGameSeconds: 0)
            )
        }
        return state
    }
}
