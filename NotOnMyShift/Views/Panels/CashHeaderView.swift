import SwiftUI

/// Kasa sayacı. Sakin: tek büyük sayı, altında net oran, gerekirse brüt ve maaş.
struct CashHeaderView: View {

    let money: Double
    /// Maaş düşülmüş, kasaya giren.
    let netRate: Double
    let grossRate: Double
    let wageRate: Double
    let isAutomated: Bool
    /// Süren olay etkilerinin toplam çarpanı. 1 ise etki yok.
    let eventMultiplier: Double
    /// En uzun süren etkiye kalan oyun süresi.
    let eventRemaining: TimeInterval?
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

            if eventMultiplier != 1 {
                eventBadge
            }

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

    /// Süren olay etkisi. Hızlandıran fıstık yeşili, yavaşlatan mürekkep —
    /// renk tek başına iyi mi kötü mü olduğunu söyler.
    private var eventBadge: some View {
        HStack(spacing: 6) {
            Text(L.equipmentOutput(multiplierText(eventMultiplier)))
            if let remaining = eventRemaining, remaining > 0 {
                Text(L.eventRemaining(DurationText.text(remaining)))
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .font(Typography.label(13))
        .foregroundStyle(eventMultiplier > 1 ? Palette.pistachio : Palette.inkSoft)
        .padding(.top, 2)
    }

    private func multiplierText(_ value: Double) -> String {
        value.formatted(.number.locale(Money.current.numberLocale).precision(.fractionLength(0...2)))
    }
}
