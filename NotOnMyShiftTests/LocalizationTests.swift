import Foundation
import XCTest
@testable import NotOnMyShift

/// Dil dosyaları. `scripts/check_localization.py` anahtar ve yer tutucu
/// eşleşmesini derlemeden tarıyor; burada çalışma anındaki çözümü ölçüyoruz.
final class LocalizationTests: XCTestCase {

    private let languages = ["en", "tr", "es"]

    func testEveryShippedCrewIdHasANameAndAQuirk() throws {
        let config = try loadShippedConfig()
        let fallbackName = L.staffName("__bilinmeyen__")
        let fallbackTrait = L.staffTrait("__bilinmeyen__")

        for template in config.staffPool {
            XCTAssertNotEqual(L.staffName(template.id), fallbackName,
                              "'\(template.id)' dil dosyasında isimsiz")
            XCTAssertNotEqual(L.staffTrait(template.id), fallbackTrait,
                              "'\(template.id)' dil dosyasında huysuz")
        }
    }

    func testUnknownCrewIdFallsBackInsteadOfShowingTheKey() {
        // Eski bir kayıttan tanımadığımız bir kimlik gelirse ekranda ham
        // anahtar değil, insanca bir metin görünmeli.
        let name = L.staffName("bu_kimlik_yok")
        XCTAssertFalse(name.isEmpty)
        XCTAssertFalse(name.contains("staff."))
    }

    func testEveryLanguageIsInTheBundleAndCarriesTheFormatKeys() throws {
        for language in languages {
            let bundle = try XCTUnwrap(
                Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
                    ?? Bundle(for: Self.self).path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)),
                "\(language).lproj pakette yok"
            )

            let pattern = bundle.localizedString(forKey: "format.currencyPattern", value: nil, table: nil)
            XCTAssertTrue(pattern.contains(Money.Style.placeholder),
                          "\(language): para kalıbında yer tutucu yok (\(pattern))")

            let localeID = bundle.localizedString(forKey: "format.numberLocale", value: nil, table: nil)
            XCTAssertFalse(localeID.isEmpty)
            XCTAssertNotEqual(localeID, "format.numberLocale", "\(language): sayı yereli tanımsız")

            for scale in ["e3", "e6", "e9", "e12", "e15"] {
                let key = "format.scale.\(scale)"
                let suffix = bundle.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertNotEqual(suffix, key, "\(language): \(key) tanımsız")
                XCTAssertFalse(suffix.isEmpty)
            }
        }
    }

    func testCurrenciesDifferBetweenLanguages() throws {
        var patterns: Set<String> = []
        for language in languages {
            guard let path = Bundle.main.path(forResource: language, ofType: "lproj")
                    ?? Bundle(for: Self.self).path(forResource: language, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { continue }
            patterns.insert(bundle.localizedString(forKey: "format.currencyPattern", value: nil, table: nil))
        }
        XCTAssertEqual(patterns.count, languages.count,
                       "Her dilin kendi para birimi olmalı, kalıplar aynı çıktı: \(patterns)")
    }

    private func loadShippedConfig() throws -> BalanceConfig {
        if let config = try? BalanceConfig.load(in: .main) { return config }
        return try BalanceConfig.load(in: Bundle(for: Self.self))
    }
}
