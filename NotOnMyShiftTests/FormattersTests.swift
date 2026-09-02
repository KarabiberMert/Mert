import Foundation
import XCTest
@testable import NotOnMyShift

/// Para ve süre biçimlendirme. Rakamlar ekranın en çok bakılan yeri; virgül
/// noktayla karışırsa ya da bir dilde simge yanlış tarafa geçerse hemen belli olur.
///
/// Biçim enjekte edilebildiği için üç dili de burada, cihaz dilinden bağımsız
/// ölçebiliyoruz.
final class FormattersTests: XCTestCase {

    // Sıra: 10^15, 10^12, 10^9, 10^6, 10^3
    private let dollar = Money.Style(
        numberLocale: Locale(identifier: "en_US"),
        pattern: "${amount}",
        suffixes: ["Q", "T", "B", "M", "K"]
    )
    private let lira = Money.Style(
        numberLocale: Locale(identifier: "tr_TR"),
        pattern: "{amount} ₺",
        suffixes: ["Kt", "Tn", "Mr", "Mn", "B"]
    )
    private let euro = Money.Style(
        numberLocale: Locale(identifier: "es_ES"),
        pattern: "{amount} €",
        suffixes: ["MB", "B", "MM", "M", "K"]
    )

    // MARK: - Para

    func testSmallAmountsAreWholeNumbers() {
        XCTAssertEqual(Money.text(0, style: dollar), "$0")
        XCTAssertEqual(Money.text(4, style: dollar), "$4")
        XCTAssertEqual(Money.text(847.9, style: dollar), "$847")
    }

    func testSymbolFollowsTheLanguage() {
        XCTAssertEqual(Money.text(1_200, style: dollar), "$1.2K")
        XCTAssertEqual(Money.text(1_200, style: lira), "1,2 B ₺")
        XCTAssertEqual(Money.text(1_200, style: euro), "1,2 K €")
    }

    func testAbbreviationsFollowTheLanguage() {
        // 10^9 İngilizce'de "B", Türkçe'de "Mr", İspanyolca'da "MM".
        XCTAssertEqual(Money.text(5_600_000_000, style: dollar), "$5.6B")
        XCTAssertEqual(Money.text(5_600_000_000, style: lira), "5,6 Mr ₺")
        XCTAssertEqual(Money.text(5_600_000_000, style: euro), "5,6 MM €")

        XCTAssertEqual(Money.text(3_400_000, style: dollar), "$3.4M")
        XCTAssertEqual(Money.text(7_800_000_000_000, style: dollar), "$7.8T")
    }

    func testLargeScaledValuesDropTheDecimal() {
        // 100'ün üstünde ondalık gösterilmez; sayaç genişliği sabit kalsın.
        XCTAssertEqual(Money.text(340_000, style: dollar), "$340K")
        XCTAssertEqual(Money.text(340_000, style: lira), "340 B ₺")
    }

    func testNegativeSignSitsOutsideThePattern() {
        XCTAssertEqual(Money.text(-5, style: dollar), "-$5")
        XCTAssertEqual(Money.text(-5, style: lira), "-5 ₺")
    }

    func testRatesKeepTheirDecimal() {
        // 1,2/sn "1/sn" görünmemeli.
        XCTAssertEqual(Money.preciseText(1.2, style: dollar), "$1.2")
        XCTAssertEqual(Money.preciseText(1.2, style: lira), "1,2 ₺")
        XCTAssertEqual(Money.preciseText(0.5, style: euro), "0,5 €")
    }

    func testNonFiniteValuesDoNotCrash() {
        XCTAssertEqual(Money.text(.nan, style: dollar), Money.emptyValue)
        XCTAssertEqual(Money.number(.infinity, style: dollar), Money.emptyValue)
        XCTAssertEqual(Money.preciseText(.nan, style: lira), Money.emptyValue)
    }

    func testShippedStyleIsUsable() {
        XCTAssertTrue(Money.current.pattern.contains(Money.Style.placeholder))
        XCTAssertEqual(Money.current.suffixes.count, 5)
        XCTAssertFalse(Money.current.suffixes.contains { $0.isEmpty })
        XCTAssertFalse(Money.text(1_234, style: Money.current).isEmpty)
    }

    // MARK: - Süre

    func testDurationsAreLocalised() {
        // Birim adlarını ve çoğul eklerini sistem çözüyor; biz dilin gerçekten
        // devreye girdiğini doğruluyoruz.
        let english = DurationText.text(7_200, locale: Locale(identifier: "en_US"))
        let turkish = DurationText.text(7_200, locale: Locale(identifier: "tr_TR"))
        let spanish = DurationText.text(7_200, locale: Locale(identifier: "es_ES"))

        XCTAssertTrue(english.lowercased().contains("hour"), english)
        XCTAssertTrue(turkish.lowercased().contains("saat"), turkish)
        XCTAssertTrue(spanish.lowercased().contains("hora"), spanish)

        for text in [english, turkish, spanish] {
            XCTAssertTrue(text.contains("2"), text)
        }
    }

    func testDurationsShowTwoUnitsWhenBothMatter() {
        let english = Locale(identifier: "en_US")
        let short = DurationText.text(7_200, locale: english)      // tam 2 saat
        let long = DurationText.text(8_100, locale: english)       // 2 saat 15 dakika

        XCTAssertGreaterThan(long.count, short.count)
        XCTAssertTrue(long.contains("15"), long)
    }

    func testShortAndVeryLongDurations() {
        let english = Locale(identifier: "en_US")
        XCTAssertTrue(DurationText.text(45, locale: english).contains("45"))
        XCTAssertTrue(DurationText.text(100_000, locale: english).contains("1"))
        XCTAssertEqual(DurationText.text(0, locale: english), L.durationNone)
        XCTAssertEqual(DurationText.text(-5, locale: english), L.durationNone)
    }
}
