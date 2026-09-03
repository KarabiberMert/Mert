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
        var original = BalanceFixture.state(
            money: 1_234.5,
            staffCount: 2,
            warehouseLevel: 1,
            equipmentLevels: ["grinder": 2],
            branchCount: 3,
            extraFloors: [BalanceFixture.upperFloor(staffCount: 1, config: config)],
            selectedFloor: 1,
            config: config
        )
        original = GameEngine.advance(original, by: 90, config: config)
        original.stats.manualSales = 17
        original.stats.eventsResolved = 4
        original.modifiers = [
            ActiveModifier(eventID: "viral", choiceID: "ride", multiplier: 3, endsAtGameSeconds: 500)
        ]

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
        XCTAssertEqual(state.floors.count, 1)
        XCTAssertTrue(state.floors[0].equipmentLevels.isEmpty)
        XCTAssertEqual(state.floors[0].branchCount, 1, "Eldeki dükkân birinci şubedir")
    }

    func testSchemaTwoSaveGetsOneBranchAndNoEquipment() throws {
        // Faz 1 kaydında şube ve ekipman alanları yok. Açılışta oyuncu tek
        // şubeyle ve ekipmansız devam etmeli, kayıt çöpe gitmemeli.
        let json = """
        {
          "schemaVersion": 2,
          "money": 900.0,
          "warehouseLevel": 2,
          "hasCelebratedFirstHire": true,
          "lastSeenAt": 1700000000.0
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let state = try decoder.decode(GameState.self, from: Data(json.utf8))

        XCTAssertEqual(state.money, 900, accuracy: 1e-9)
        XCTAssertEqual(state.warehouseLevel, 2)
        XCTAssertTrue(state.hasCelebratedFirstHire)
        XCTAssertEqual(state.floors[0].branchCount, 1)
        XCTAssertEqual(state.floors[0].equipmentLevel("grinder"), 0)
    }

    func testSchemaThreeSaveBecomesTheGroundFloor() throws {
        // Faz 2 kaydında kat yoktu: kadro, ekipman ve şube düz alanlardaydı.
        // Hepsi zemin kata taşınmalı, oyuncu hiçbir şey kaybetmemeli.
        let json = """
        {
          "schemaVersion": 3,
          "money": 4200.0,
          "warehouseLevel": 3,
          "hasCelebratedFirstHire": true,
          "branchCount": 2,
          "equipmentLevels": { "grinder": 2, "machine": 1 },
          "staff": [
            { "id": "quick", "rateMultiplier": 1.15, "hiredAtGameSeconds": 12.0 },
            { "id": "opener", "rateMultiplier": 1.0, "hiredAtGameSeconds": 300.0 }
          ],
          "lastSeenAt": 1700000000.0
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let state = try decoder.decode(GameState.self, from: Data(json.utf8))

        XCTAssertEqual(state.floors.count, 1)
        XCTAssertEqual(state.floors[0].sectorID, GameState.groundSectorID)
        XCTAssertEqual(state.floors[0].staff.map(\.id), ["quick", "opener"])
        XCTAssertEqual(state.floors[0].equipmentLevel("grinder"), 2)
        XCTAssertEqual(state.floors[0].equipmentLevel("machine"), 1)
        XCTAssertEqual(state.floors[0].branchCount, 2)
        XCTAssertEqual(state.warehouseLevel, 3)
        XCTAssertEqual(state.money, 4200, accuracy: 1e-9)
        XCTAssertEqual(state.selectedFloor, 0)
    }

    func testSchemaFourSaveGetsAMarketAndAnEventClock() throws {
        // Faz 3 kaydında olay ve pazar yoktu. Eksik alanlar `unset` kalır ve
        // motorun ilk normalleştirmesinde dengeden dolar.
        let json = """
        {
          "schemaVersion": 4,
          "money": 800.0,
          "lastSeenAt": 1700000000.0,
          "floors": [ { "sectorID": "coffee", "branchCount": 1 } ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let state = try decoder.decode(GameState.self, from: Data(json.utf8))
        XCTAssertEqual(state.marketShare, GameState.unset)
        XCTAssertEqual(state.nextEventAtGameSeconds, GameState.unset)
        XCTAssertTrue(state.modifiers.isEmpty)
        XCTAssertNotEqual(state.eventSeed, 0, "Tohum sıfır olmamalı")

        let config = BalanceFixture.config()
        let ready = GameEngine.normalised(state, config: config)
        XCTAssertEqual(ready.marketShare, config.market.startShare, accuracy: 1e-9)
        XCTAssertEqual(
            ready.nextEventAtGameSeconds,
            state.elapsedGameSeconds + config.events.firstAfterSeconds, accuracy: 1e-9
        )
        // Eski kayıt açılır açılmaz olayla karşılaşmasın.
        XCTAssertNil(GameEngine.pendingEvent(for: ready, config: config))
    }

    func testSavesAreWrittenWithTheCurrentSchemaOnly() throws {
        // Göç alanları geri yazılmamalı; kayıt her zaman güncel şemayla çıkar.
        let original = BalanceFixture.state(money: 10, staffCount: 1)
        try store.save(original)

        let folder = directory.appending(path: "NotOnMyShift", directoryHint: .isDirectory)
        let data = try Data(contentsOf: folder.appending(path: "save.json", directoryHint: .notDirectory))
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertNotNil(object["floors"])
        XCTAssertEqual(object["schemaVersion"] as? Int, GameState.currentSchemaVersion)
        XCTAssertNotNil(object["marketShare"])
        XCTAssertNotNil(object["eventSeed"])
        XCTAssertNotNil(object["holdingPoints"])
        XCTAssertNotNil(object["cityNumber"])
        // Şema 3'ün düz alanları kök seviyede kalmamalı — kat içinde yaşıyorlar.
        for legacy in ["staff", "equipmentLevels", "branchCount"] {
            XCTAssertNil(object[legacy], "'\(legacy)' kök seviyede yazılmamalı")
        }
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
              "id": "quick",
              "name": "Rosa",
              "trait": "eski sürümden kalma alan",
              "rateMultiplier": 1.15,
              "hiredAtGameSeconds": 12.0
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let state = try decoder.decode(GameState.self, from: Data(json.utf8))

        XCTAssertEqual(state.floors.count, 1)
        XCTAssertEqual(state.floors[0].staff.count, 1)
        XCTAssertEqual(state.floors[0].staff[0].id, "quick")
        XCTAssertEqual(state.floors[0].staff[0].rateMultiplier, 1.15, accuracy: 1e-9)
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
        XCTAssertEqual(actual.floors.count, expected.floors.count, file: file, line: line)
        for (left, right) in zip(actual.floors, expected.floors) {
            XCTAssertEqual(left.sectorID, right.sectorID, file: file, line: line)
            XCTAssertEqual(left.staff.map(\.id), right.staff.map(\.id), file: file, line: line)
            XCTAssertEqual(left.equipmentLevels, right.equipmentLevels, file: file, line: line)
            XCTAssertEqual(left.branchCount, right.branchCount, file: file, line: line)
        }
        XCTAssertEqual(actual.selectedFloor, expected.selectedFloor, file: file, line: line)
        XCTAssertEqual(actual.marketShare, expected.marketShare, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(actual.eventSeed, expected.eventSeed, file: file, line: line)
        XCTAssertEqual(
            actual.nextEventAtGameSeconds, expected.nextEventAtGameSeconds,
            accuracy: 1e-6, file: file, line: line
        )
        XCTAssertEqual(actual.modifiers, expected.modifiers, file: file, line: line)
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
