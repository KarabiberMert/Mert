import SwiftUI

@main
struct NotOnMyShiftApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @State private var bootstrap = Bootstrap.start()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .ready(let store):
                RootView(store: store)
            case .failed(let message):
                BootFailureView(message: message)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard case .ready(let store) = bootstrap else { return }
            switch phase {
            case .active:
                store.handleBecameActive()
            case .inactive, .background:
                // `.inactive` de dahil: kontrol merkezi / uygulama değiştirici
                // gibi anlık kesintilerde de saati damgalayıp kaydediyoruz.
                store.handleWillResignActive()
            @unknown default:
                break
            }
        }
    }
}

/// Açılış. `balance.json` okunamazsa çökmek yerine hatayı ekranda gösteriyoruz.
enum Bootstrap {
    case ready(GameStore)
    case failed(String)

    @MainActor
    static func start() -> Bootstrap {
        do {
            let config = try BalanceConfig.load()
            let saves = try SaveStore.applicationSupport()
            return .ready(GameStore(config: config, saves: saves))
        } catch {
            return .failed(String(describing: error))
        }
    }
}
