import XCTest
@testable import NotOnMyShift

/// Kayıt katmanı. Buradaki bir hata oyuncunun haftalarını siler;
/// o yüzden mutlu yolun yanında bozuk dosya ve eksik alan da test ediliyor.
final class PersistenceTests: XCTestCase {

    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())
    private var store = SaveStore(containerDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "nomstest-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = SaveStore(containerDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    // MARK: - Gidiş-dönüş

    func testSaveThenLoadReturnsTheSameState() throws {
        let config = BalanceFixture.config()
        var original = BalanceFixture.state(money: 1_234.5, staffCount: 2, warehouseLevel: 1, config: config)
        original = GameEngine.advance(original, by: 90, config: config)
        original.stats.manualSales = 17

        try store.save(original)

        guard case .loaded(let restored) = store.load() else {
            return XCTFail("Kayıt ana dosyadan okunamadı")
        }
        assertSameState(restored, original)
    }

    func testLoadWithoutAnySaveIsEmpty() {
        XCTAssertEqual(store.load(), .empty)
    }

    func testDeleteAllRemovesSaveAndBackup() throws {
        try store.save(BalanceFixture.state(money: 10))
        try store.save(BalanceFixture.state(money: 20))   // ikinci yazma yedeği oluşturur

        store.deleteAll()

        XCTAssertEqual(store.load(), .empty)
    }

    // MARK: - Bozuk kayıt

    func testCorruptedSaveFallsBackToBackup() throws {
        let first = BalanceFixture.state(money: 111)
        let second = BalanceFixture.state(money: 222)

        try store.save(first)          // save.json = 111
        try store.save(second)         // save.json = 222, save.backup.json = 111

        // Ana dosyayı boz.
        let saveURL = directory
            .appending(path: "NotOnMyShift", directoryHint: .isDirectory)
            .appending(path: "save.json", directoryHint: .notDirectory)
        try Data("bu bir JSON değil".utf8).write(to: saveURL)

        guard case .recovered(let restored) = store.load() else {
            return XCTFail("Bozuk kayıt yedeğe düşmeliydi")
        }
        XCTAssertEqual(restored.money, 111, accuracy: 1e-6)
    }

    func testBothFilesCorruptedIsReportedAsEmptyRatherThanCrashing() throws {
        try store.save(BalanceFixture.state(money: 111))
        try store.save(BalanceFixture.state(money: 222))

        let folder = directory.appending(path: "NotOnMyShift", directoryHint: .isDirectory)
        for name in ["save.json", "save.backup.json"] {
            try Data("çöp".utf8).write(to: folder.appending(path: name, directoryHint: .notDirectory))
        }

        XCTAssertEqual(store.load(), .empty)
    }

    // MARK: - Şema esnekliği

    func testOldSaveMissingNewFieldsStillLoads() throws {
        // Şema büyüdükçe eski kayıt açılmaya devam etmeli: eksik alanlar
        // varsayılana düşer, kayıt çöpe gitmez.
        let json = """
        {
          "money": 500.0,
          "lastSeenAt": 1700000000.0
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let state = try decoder.decode(GameState.self, from: Data(json.utf8))

        XCTAssertEqual(state.money, 500, accuracy: 1e-9)
        XCTAssertEqual(state.lastSeenAt.timeIntervalSince1970, 1_700_000_000, accuracy: 1e-6)
        XCTAssertEqual(state.schemaVersion, 1)
        XCTAssertEqual(state.characterID, "kahveci")
        XCTAssertTrue(state.staff.isEmpty)
        XCTAssertEqual(state.warehouseLevel, 0)
        XCTAssertEqual(state.stats.manualSales, 0)
        XCTAssertFalse(state.hasCelebratedFirstHire)
    }

    func testSchemaOneSaveWithStaffDoesNotReplayTheFirstHireMoment() throws {
        // Şema 1'de `hasCelebratedFirstHire` yoktu. Kadrosu olan eski bir kayıt
        // açıldığında Çağ 1 kutlaması yeniden oynatılmamalı — o an bir kez yaşanır.
        let json = """
        {
          "schemaVersion": 1,
          "money": 40.0,
          "lastSeenAt": 1700000000.0,
          "staff": [
            {
              "id": "sevim",
              "name": "Sevim Abla",
              "trait": "Hızlıdır",
              "rateMultiplier": 1.15,
              "hiredAtGameSeconds": 12.0
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let state = try decoder.decode(GameState.self, from: Data(json.utf8))

        XCTAssertEqual(state.staff.count, 1)
        XCTAssertTrue(state.hasCelebratedFirstHire)
        XCTAssertTrue(state.isAutomated)
    }

    // MARK: - Yardımcı

    private func assertSameState(
        _ actual: GameState,
        _ expected: GameState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.schemaVersion, expected.schemaVersion, file: file, line: line)
        XCTAssertEqual(actual.characterID, expected.characterID, file: file, line: line)
        XCTAssertEqual(actual.money, expected.money, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(actual.lifetimeEarnings, expected.lifetimeEarnings, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(actual.elapsedGameSeconds, expected.elapsedGameSeconds, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(actual.warehouseLevel, expected.warehouseLevel, file: file, line: line)
        XCTAssertEqual(actual.hasCelebratedFirstHire, expected.hasCelebratedFirstHire, file: file, line: line)
        XCTAssertEqual(actual.staff.map(\.id), expected.staff.map(\.id), file: file, line: line)
        XCTAssertEqual(actual.stats, expected.stats, file: file, line: line)
        XCTAssertEqual(
            actual.lastSeenAt.timeIntervalSince1970,
            expected.lastSeenAt.timeIntervalSince1970,
            accuracy: 1e-3,
            file: file,
            line: line
        )
    }
}
