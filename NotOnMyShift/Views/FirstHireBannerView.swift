import SwiftUI

/// Çağ 0 → Çağ 1. Oyunun ilk büyük ödül anı, bir kez görünür.
///
/// Faz 1'in test ettiği tek soru bu ekranda: ilk elemanı tutmak tatmin edici mi?
struct FirstHireBannerView: View {

    let member: StaffMember
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 14) {
                Text(L.startedWork(member.name))
                    .font(Typography.display(28))
                    .foregroundStyle(Palette.ink)

                Text(member.trait)
                    .font(Typography.label(16))
                    .foregroundStyle(Palette.pistachio)

                Text(L.firstHireBody)
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onDismiss) {
                    Text(L.firstHireAction)
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
