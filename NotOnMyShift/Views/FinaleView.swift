import SwiftUI

/// Final: holding halka arz oldu.
///
/// Oyun biter ama uygulama silinmez (rapor §5). Bu sahne biten şehri anlatır,
/// yeni başlayanı değil — özet halka arzdan **önce** alınır. Kapanışın tonu
/// veda değil devir teslim: sokağın öbür ucunda boş bir dükkân bekliyor.
struct FinaleView: View {

    let summary: FinaleSummary
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.45)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text(L.cityNumber(summary.cityNumber))
                    .font(Typography.label(14))
                    .foregroundStyle(Palette.mustardDeep)

                Text(L.finaleTitle)
                    .font(Typography.display(30))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L.finaleBody)
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 6) {
                    stat(L.finaleEarned, Money.text(summary.lifetimeEarnings))
                    stat(L.finalePlayed, DurationText.text(summary.playedSeconds))
                    stat(L.finaleSold, "\(summary.sectorsSold)")
                    stat(L.finaleByHand, "\(summary.manualSales)")
                    stat(L.holdingPoints(summary.holdingPoints), "")
                }
                .padding(.vertical, 4)

                Text(L.newCityNote)
                    .font(Typography.label(13))
                    .foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onContinue) {
                    Text(L.newCity)
                        .font(Typography.display(18))
                        .foregroundStyle(Palette.plaster)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Palette.enamel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .scaleEffect(settled ? 1 : 0.92)
            .opacity(settled ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { settled = true }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.label(14))
                .foregroundStyle(Palette.inkSoft)
            Spacer(minLength: 12)
            Text(value)
                .font(Typography.money(15))
                .foregroundStyle(Palette.mustardDeep)
        }
    }
}
