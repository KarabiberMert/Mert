import Foundation
import XCTest
@testable import NotOnMyShift

/// Dengeyi **gerçek `balance.json` ile** ölçen sonda.
///
/// Elle oynayarak denge ayarlamak yavaş ve güvenilmez; burada motor saniye
/// saniye çalıştırılıp memnuniyet, kuyruk ve gelir izleniyor. Hem tabloyu
/// basıyor (ayar yaparken okumak için) hem sağlıklı bandı doğruluyor.
@MainActor
final class DemandBalanceProbe: XCTestCase {

    private func shipped() throws -> BalanceConfig { try BalanceConfig.load() }

    /// Belirtilen kurulumla `seconds` saniye çalıştırır.
    private func run(
        config: BalanceConfig,
        staff: Int,
        equipment: Bool,
        branches: Int,
        price: Double?,
        seconds: Int
    ) -> GameState {
        var state = GameState.newGame(characterID: "kahveci", now: BalanceFixture.epoch)
        state = GameEngine.normalised(state, config: config)
        state.money = 1_000_000_000

        let spec = config.sectors[0]
        for index in 0..<staff {
            guard index < spec.staffPool.count else { break }
            let template = spec.staffPool[index]
            state.floors[0].staff.append(
                StaffMember(id: template.id, rateMultiplier: template.rateMultiplier, hiredAtGameSeconds: 0)
            )
        }
        if equipment {
            for piece in spec.equipment {
                state.floors[0].equipmentLevels[piece.id] = piece.levels.count - 1
            }
        }
        state.floors[0].branchCount = branches
        if let price {
            state = GameEngine.setPrice(price, onFloor: 0, state, config: config)
        }

        for _ in 0..<seconds {
            state = GameEngine.advance(state, by: 1, config: config)
        }
        return state
    }

    private func satır(_ ad: String, _ state: GameState, _ config: BalanceConfig, _ seconds: Int) -> String {
        let floor = state.floors[0]
        let s = floor.satisfaction
        let range = config.demand.minSatisfaction...config.demand.maxSatisfaction
        let band = (s - range.lowerBound) / (range.upperBound - range.lowerBound)
        let sales = GameEngine.salesRate(for: state, config: config)
        let perMinute = GameEngine.productionRate(for: state, config: config) * 60
        return String(
            format: "%-26@ memnuniyet %.2f (%%%2.0f)  kuyruk %6.1f  satış/sn %7.2f  ₺/dk %12.0f",
            ad as NSString, s, band * 100, floor.demandQueue, sales, perMinute
        )
    }

    /// Dengenin **şekli**: memnuniyet taban fiyatta tepe yapmalı ve iki yana
    /// da düşmeli, gelir tepesi de kuyruğun olduğu yerde olmalı.
    ///
    /// Bunlar keyfi sayılar değil, ürün sahibinin koyduğu şartların ölçüsü:
    /// "dükkân dolsun sıra oluşsun", "fiyatı arttırmak memnuniyeti azaltsın",
    /// "parametreler ortalarda kalsın".
    func testBalanceShapeRewardsKeepingTheShopBusy() throws {
        let config = try shipped()
        let range = GameEngine.priceRange(for: config.sectors[0])
        let base = config.sectors[0].manual.revenuePerSale

        func olc(_ price: Double) -> (memnuniyet: Double, kuyruk: Double, gelir: Double) {
            let state = run(config: config, staff: 6, equipment: false,
                            branches: 1, price: price, seconds: 900)
            return (state.floors[0].satisfaction,
                    state.floors[0].demandQueue,
                    GameEngine.productionRate(for: state, config: config))
        }

        let ucuz = olc(range.lowerBound)
        let taban = olc(base)
        let pahali = olc(range.upperBound)

        // Memnuniyet ortada tepe yapar: iki uç da cezalanır.
        XCTAssertGreaterThan(taban.memnuniyet, ucuz.memnuniyet, "Taşan dükkân memnun değil")
        XCTAssertGreaterThan(taban.memnuniyet, pahali.memnuniyet, "Pahalı dükkân da memnun değil")

        // Fiyatı yükseltmek memnuniyeti düşürür — ürün sahibinin şartı.
        XCTAssertLessThan(pahali.memnuniyet, taban.memnuniyet)

        // Gelir tepesi kuyruğun olduğu yerde: en kârlı oynayış dükkânı dolu
        // tutmak. Boş tezgâh en iyi seçenek olsaydı oyun ters çalışırdı.
        XCTAssertGreaterThan(taban.gelir, ucuz.gelir)
        XCTAssertGreaterThan(taban.gelir, pahali.gelir)
        XCTAssertGreaterThan(taban.kuyruk, 1, "Taban fiyatta dükkânda sıra olmalı")
        XCTAssertEqual(pahali.kuyruk, 0, accuracy: 1e-6, "Pahalı fiyat sırayı eritir")

        // Ucuz satmak müşteriyi çoğaltır ama kazandırmaz.
        XCTAssertGreaterThan(ucuz.kuyruk, taban.kuyruk * 5, "Ucuz fiyat dükkânı taşırır")
    }

    func testPrintEquilibriumAcrossStages() throws {
        let config = try shipped()
        let seconds = 900

        print("PROBE ---- aşamalar (taban fiyat, \(seconds) sn) ----")
        let asamalar: [(String, Int, Bool, Int)] = [
            ("Çağ 0 (kadro yok)", 0, false, 1),
            ("1 eleman", 1, false, 1),
            ("3 eleman", 3, false, 1),
            ("tam kadro", 6, false, 1),
            ("tam kadro + ekipman", 6, true, 1),
            ("hepsi + 4 şube", 6, true, 4),
        ]
        for (ad, staff, equipment, branches) in asamalar {
            let state = run(config: config, staff: staff, equipment: equipment,
                            branches: branches, price: nil, seconds: seconds)
            print("PROBE " + satır(ad, state, config, seconds))
        }

        print("PROBE ---- fiyat taraması (tam kadro, \(seconds) sn) ----")
        let range = GameEngine.priceRange(for: config.sectors[0])
        for adim in 0...6 {
            let price = range.lowerBound + (range.upperBound - range.lowerBound) * Double(adim) / 6
            let state = run(config: config, staff: 6, equipment: false,
                            branches: 1, price: price, seconds: seconds)
            print("PROBE " + satır(String(format: "fiyat %.1f ₺", price), state, config, seconds))
        }
    }
}
