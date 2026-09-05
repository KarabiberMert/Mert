import SwiftUI

/// Oyunun büyük anları: ilk eleman, açılan kat. İkisi de bir kez görünür.
///
/// Aynı kalıbı paylaşıyorlar çünkü ikisi de aynı şeyi söylüyor: "artık bu da
/// sensiz yürüyor."
struct MomentBannerView: View {

    let title: String
    /// Başlığın altındaki tek satırlık renkli not — huy ya da sektör adı.
    let highlight: String
    /// Gövde metni. Çağrı yerinde `body:` diye geçer; saklı adı ayrı, çünkü
    /// `body` SwiftUI'ın `var body: some View`'uyla çakışıyor.
    let message: String
    let actionTitle: String
    let onDismiss: () -> Void

    init(
        title: String,
        highlight: String,
        body: String,
        actionTitle: String,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.highlight = highlight
        self.message = body
        self.actionTitle = actionTitle
        self.onDismiss = onDismiss
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(Typography.display(28))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(highlight)
                    .font(Typography.label(16))
                    .foregroundStyle(Palette.pistachio)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onDismiss) {
                    Text(actionTitle)
                        .font(Typography.display(18))
                        .foregroundStyle(Palette.plaster)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Palette.enamel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(22)
            .frame(maxWidth: 340, alignment: .leading)
            .background(Palette.wall, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.mustard, lineWidth: 2)
            }
            .padding(.horizontal, 24)
            .scaleEffect(settled ? 1 : 0.92)
            .opacity(settled ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { settled = true }
        }
    }
}
