import SwiftUI

/// "Sponsor arası" — oyunun kendi çizdiği ara sahne.
///
/// Bu sürümde gerçek bir reklam SDK'sı yok (proje kuralı: sıfır bağımlılık).
/// Sahne dürüst davranır: burada reklam olmadığını söyler, geri sayımı işletir
/// ve ödülü gerçekten verir. Oyuncu istediği an geçebilir — geçerse ödül yok,
/// ama hiçbir şey de kaybetmez.
struct AdBreakView: View {

    let seconds: TimeInterval
    let onFinish: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var remaining: TimeInterval
    @State private var settled = false

    init(seconds: TimeInterval, onFinish: @escaping (Bool) -> Void) {
        self.seconds = max(1, seconds)
        self.onFinish = onFinish
        _remaining = State(initialValue: max(1, seconds))
    }

    private var isDone: Bool { remaining <= 0 }

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.55)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text(L.adBreakTitle)
                    .font(Typography.display(24))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L.adBreakBody)
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                board

                Button {
                    onFinish(isDone)
                } label: {
                    Text(isDone ? L.adBreakClaim : L.adBreakSkip)
                        .font(Typography.display(18))
                        .foregroundStyle(isDone ? Palette.plaster : Palette.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            isDone ? Palette.enamel : Palette.stone,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 340, alignment: .leading)
            .background(Palette.wall, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.mustard, lineWidth: 2)
            }
            .padding(.horizontal, 24)
            .scaleEffect(settled ? 1 : 0.94)
            .opacity(settled ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { settled = true }
        }
        // Ekonomiye değil sahneye ait bir sayaç: kısa, sınırlı, kendi kendine biter.
        .task {
            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remaining = max(0, remaining - 1)
            }
        }
    }

    /// Boş bir tabela ve geri sayım. Emaye dil bozulmuyor.
    private var board: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.enamel.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.enamel.opacity(0.35), lineWidth: 1.5)
                }
                .frame(height: 96)
                .overlay {
                    Text(L.adBreakCountdown(Int(remaining.rounded(.up))))
                        .font(Typography.money(22))
                        .foregroundStyle(isDone ? Palette.pistachio : Palette.inkSoft)
                        .contentTransition(.numericText())
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L.adBreakTitle), \(L.adBreakCountdown(Int(remaining.rounded(.up))))")
    }
}

/// Sponsor arasını doğru katmana yerleştirir.
///
/// Bir sayfa (`.sheet`) açıkken kök görünümün üstüne çizilen katman onun
/// **altında** kalır — oyuncu ödülü isteyip hiçbir şey görmez. Bu yüzden
/// ödülün istendiği her yer sahneyi kendi katmanında taşır; aynı anda yalnızca
/// biri takılı olur.
struct AdBreakLayer: ViewModifier {

    let store: GameStore
    /// Sahneyi çizmek bu katmanın işi mi? Üstte bir sayfa varsa kök katman
    /// devreden çıkar, sahneyi sayfanınki taşır.
    let isActive: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isActive, let house = store.houseAds, house.isPresenting {
                AdBreakView(seconds: house.seconds) { rewarded in
                    house.finish(rewarded: rewarded)
                }
                .transition(.opacity)
            }
        }
    }
}

extension View {
    /// Sponsor arası sahnesini bu katmana ekler.
    func adBreak(_ store: GameStore, isActive: Bool = true) -> some View {
        modifier(AdBreakLayer(store: store, isActive: isActive))
    }
}
