import Foundation

/// Kayıt/yükleme. Diske senkron yazar — kayıt birkaç kilobayt, ve uygulama
/// arka plana giderken async bir görevin bitmesini bekleyemeyiz.
///
/// Üç kural:
/// 1. Yazma `.atomic` — yarım dosya diye bir şey olmayacak.
/// 2. Her yazmadan önce eldeki kayıt yedeklenir.
/// 3. Ana dosya bozuksa yedekten dönülür.
///
/// Oyuncunun üç haftalık ilerlemesini kaybetmek bu türde tek affedilmez hatadır.
struct SaveStore: Sendable {

    enum Outcome: Sendable, Equatable {
        /// Ana dosyadan okundu.
        case loaded(GameState)
        /// Ana dosya bozuktu, yedekten dönüldü.
        case recovered(GameState)
        /// Kayıt yok — ilk açılış.
        case empty
    }

    private let directory: URL
    private let saveURL: URL
    private let backupURL: URL

    /// `FileManager` `Sendable` değil, o yüzden örnek saklamıyoruz;
    /// `FileManager.default` zaten paylaşılan ve iş parçacığı güvenli örnek.
    private var fileManager: FileManager { .default }

    /// - Parameter containerDirectory: Kayıtların yazılacağı kök klasör.
    ///   Üretimde Application Support, testlerde geçici klasör.
    init(containerDirectory: URL) {
        let folder = containerDirectory.appending(path: "NotOnMyShift", directoryHint: .isDirectory)
        self.directory = folder
        self.saveURL = folder.appending(path: "save.json", directoryHint: .notDirectory)
        self.backupURL = folder.appending(path: "save.backup.json", directoryHint: .notDirectory)
    }

    /// Üretim yolu: Application Support.
    static func applicationSupport() throws -> SaveStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return SaveStore(containerDirectory: base)
    }

    // MARK: - Kodlayıcılar

    /// Tarihler unix saniyesi olarak yazılır: kayıpsız ve okunur.
    /// (ISO8601 saniye altını yuvarlar; `lastSeenAt` için bunu istemiyoruz.)
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    // MARK: - Yazma

    func save(_ state: GameState) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.makeEncoder().encode(state)

        // Elimizdeki kaydı yedekle. Başarısız olursa yazmayı yine de sürdürürüz —
        // yedeksiz kaydetmek, hiç kaydetmemekten iyidir.
        if fileManager.fileExists(atPath: saveURL.path(percentEncoded: false)) {
            try? fileManager.removeItem(at: backupURL)
            try? fileManager.copyItem(at: saveURL, to: backupURL)
        }

        try data.write(to: saveURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: - Okuma

    func load() -> Outcome {
        if let state = decode(at: saveURL) {
            return .loaded(state)
        }
        if let state = decode(at: backupURL) {
            return .recovered(state)
        }
        return .empty
    }

    private func decode(at url: URL) -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.makeDecoder().decode(GameState.self, from: data)
    }

    // MARK: - Silme

    /// Kaydı ve yedeğini siler. "Baştan başla" ve testler için.
    func deleteAll() {
        try? fileManager.removeItem(at: saveURL)
        try? fileManager.removeItem(at: backupURL)
    }
}
