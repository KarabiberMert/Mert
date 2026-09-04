import Foundation

/// Testlerde saati elle ileri almak için. Üretimde `Date()` kullanılıyor.
///
/// Ekonomi `lastSeenAt` ile şimdiki zamanın farkından türediği için, saati
/// enjekte etmek gerçek zaman beklemeden çevrimdışı kazancı ölçmeyi sağlıyor.
final class TestClock: @unchecked Sendable {

    private let lock = NSLock()
    private var storedDate: Date

    init(_ date: Date) {
        storedDate = date
    }

    var date: Date {
        get { lock.withLock { storedDate } }
        set { lock.withLock { storedDate = newValue } }
    }

    var provider: @Sendable () -> Date {
        { [self] in date }
    }
}
