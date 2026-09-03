import SwiftUI

/// Pazar payı çubuğu ve isimli rakipler.
///
/// Tasarım raporunun cezalandırmama kuralı burada da geçerli: rakip mevcut
/// geliri düşürmez, sadece yeni hücre açma hakkını kısar. Metin bunu
/// "gecikme" olarak anlatır, "kayıp" olarak değil.
struct MarketShareView: View {

    let share: Double
    let competitors: [GameEngine.CompetitorShare]
    let unlockedSlots: Int
    let isBlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.marketTitle)
                    .font(Typography.display(15))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(percent(share))
                    .font(Typography.money(15))
                    .foregroundStyle(Palette.mustardDeep)
            }

            bar
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(L.marketTitle), \(L.marketYou) \(percent(share))")

            Text(L.marketSlots(unlockedSlots))
                .font(Typography.label(13))
                .foregroundStyle(Palette.inkFaint)

            if isBlocked {
                Text(L.marketBlocked)
                    .font(Typography.label(13))
                    .foregroundStyle(Palette.enamel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(competitors) { rival in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L.competitorName(rival.id))
                            .font(Typography.display(14))
                            .foregroundStyle(Palette.inkSoft)
                        Spacer(minLength: 8)
                        Text(percent(rival.share))
                            .font(Typography.money(13))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    Text(L.competitorQuip(rival.id))
                        .font(.system(.caption))
                        .foregroundStyle(Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 4)
    }

    /// Oyuncunun dilimi hardal — para ile aynı renk. Rakipler soğuk tonlarda.
    private var bar: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                Rectangle()
                    .fill(Palette.mustard)
                    .frame(width: max(2, proxy.size.width * share))
                ForEach(Array(competitors.enumerated()), id: \.element.id) { entry in
                    Rectangle()
                        .fill(entry.offset.isMultiple(of: 2) ? Palette.glassTone.color : Palette.concreteTone.color)
                        .frame(width: max(1, proxy.size.width * entry.element.share))
                }
                Rectangle().fill(Palette.stone)
            }
        }
    }

    private func percent(_ value: Double) -> String {
        (value * 100).formatted(
            .number.locale(Money.current.numberLocale).precision(.fractionLength(0))
        ) + "%"
    }
}
