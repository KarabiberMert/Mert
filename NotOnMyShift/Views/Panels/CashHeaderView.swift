import SwiftUI

/// Kasa sayacı. Sakin: tek sayı, tek satır açıklama, süs yok.
struct CashHeaderView: View {

    let money: Double
    let productionRate: Double
    let isAutomated: Bool
    /// Elle satışta kısa bir nefes. Oyuncunun eylemine cevap.
    let bumped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L.cash)
                .font(Typography.label(13))
                .foregroundStyle(Palette.inkSoft)

            Text(Money.text(money))
                .font(Typography.money(46))
                .foregroundStyle(Palette.ink)
                .scaleEffect(bumped ? 1.04 : 1, anchor: .leading)
                .accessibilityLabel("\(L.cash): \(Money.text(money))")

            Group {
                if isAutomated {
                    Text(L.perSecond(Money.preciseText(productionRate)))
                        .foregroundStyle(Palette.pistachio)
                } else {
                    Text(L.workingByHand)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .font(Typography.label(15))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
