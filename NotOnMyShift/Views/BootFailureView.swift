import SwiftUI

/// `balance.json` pakete girmemişse ya da bozuksa burası görünür.
/// Çökmek yerine ne olduğunu söylüyoruz.
struct BootFailureView: View {

    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text(L.bootFailed)
                .font(Typography.display(24))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.system(.footnote))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.wall.ignoresSafeArea())
    }
}
