import Foundation
import XCTest
@testable import NotOnMyShift

/// Türkçe biçimlendirme. Rakamlar ekranın en çok bakılan yeri;
/// virgül/nokta karışması ya da sessizce yuvarlanan bir oran hemen göze batar.
final class FormattersTests: XCTestCase {

    func testShortAmountsAreWholeNumbers() {
        XCTAssertEqual(Money.text(0), "0 ₺")
        XCTAssertEqual(Money.text(4), "4 ₺")
        XCTAssertEqual(Money.text(847.9), "847 ₺")
    }

    func testTurkishAbbreviations() {
        XCTAssertEqual(Money.text(1_200), "1,2 B ₺")
        XCTAssertEqual(Money.text(3_400_000), "3,4 Mn ₺")
        XCTAssertEqual(Money.text(5_600_000_000), "5,6 Mr ₺")
        XCTAssertEqual(Money.text(7_800_000_000_000), "7,8 Tn ₺")
    }

    func testLargeScaledValuesDropTheDecimal() {
        // 100'ün üstünde ondalık gösterilmez; sayaç genişliği sabit kalsın.
        XCTAssertEqual(Money.text(340_000), "340 B ₺")
    }

    func testRatesKeepTheirDecimal() {
        // 1,2 ₺/sn "1 ₺/sn" görünmemeli.
        XCTAssertEqual(Money.preciseText(1.2), "1,2 ₺")
        XCTAssertEqual(Money.preciseText(0.5), "0,5 ₺")
    }

    func testNonFiniteValuesDoNotCrash() {
        XCTAssertEqual(Money.number(.nan), "—")
        XCTAssertEqual(Money.number(.infinity), "—")
        XCTAssertEqual(Money.preciseText(.nan), "—")
    }

    func testDurationsReadLikeSpeech() {
        XCTAssertEqual(DurationText.text(45), "45 saniye")
        XCTAssertEqual(DurationText.text(600), "10 dakika")
        XCTAssertEqual(DurationText.text(7_200), "2 saat")
        XCTAssertEqual(DurationText.text(8_100), "2 saat 15 dakika")
        XCTAssertEqual(DurationText.text(86_400), "1 gün")
        XCTAssertEqual(DurationText.text(100_000), "1 gün 3 saat")
        XCTAssertEqual(DurationText.text(0), "0 dakika")
        XCTAssertEqual(DurationText.text(-5), "0 dakika")
    }
}
