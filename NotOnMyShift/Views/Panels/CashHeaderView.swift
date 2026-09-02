import SwiftUI

/// Kasa sayacı. Sakin: tek büyük sayı, altında net oran, gerekirse brüt ve maaş.
struct CashHeaderView: View {

    let money: Double
    /// Maaş düşülmüş, kasaya giren.
    let netRate: Double
    let grossRate: Double
    let wageRate: Double
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

            if isAutomated {
                Text(L.perSecond(Money.preciseText(netRate)))
                    .font(Typography.label(15))
                    .foregroundStyle(Palette.pistachio)

                // Maaş varken brütü de göster: makine yatırımıyla eleman maaşı
                // arasındaki seçim ancak iki sayı yan yana görünürse anlaşılır.
                if wageRate > 0 {
                    Text("\(L.grossAmount(Money.preciseText(grossRate))) · \(L.wagesAmount(Money.preciseText(wageRate)))")
                        .font(Typography.label(12))
                        .foregroundStyle(Palette.inkFaint)
                }
            } else {
                Text(L.workingByHand)
                    .font(Typography.label(15))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
