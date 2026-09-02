import SwiftUI

/// `balance.json` pakete girmemişse ya da bozuksa burası görünür.
/// Çökmek yerine ne olduğunu söylüyoruz.
struct BootFailureView: View {

    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(L.bootFailed)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.wall.ignoresSafeArea())
    }
}
