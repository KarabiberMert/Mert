import SwiftUI

/// Binanın altındaki disiplinli şerit: sat, tut, büyüt.
///
/// Kart estetiğinden kaçınıyoruz — gri gölge yok, her şey aynı yuvarlaklıkta
/// değil. Ayrım emaye ince çizgiyle yapılıyor, tabelanın diliyle aynı.
struct ActionPanelView: View {

    let sellTitle: String
    let gainText: String
    let isAutomated: Bool

    let hireCost: Double?
    let nextStaff: BalanceConfig.StaffTemplate?
    let canAffordHire: Bool
    let manualSalesUntilHire: Int?

    let warehouseCapacity: TimeInterval
    let warehouseCost: Double?
    let canAffordWarehouse: Bool

    let showsFundsWarning: Bool

    let onSell: () -> Void
    let onHire: () -> Void
    let onUpgradeWarehouse: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            sellButton
            hireRow
            warehouseRow

            if showsFundsWarning {
                Text(L.notEnoughMoney)
                    .font(Typography.label(13))
                    .foregroundStyle(Palette.mustardDeep)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Sat

    private var sellButton: some View {
        Button(action: onSell) {
            HStack {
                Text(sellTitle)
                Spacer(minLength: 12)
                Text(gainText)
                    .foregroundStyle(Palette.mustard)
            }
            .font(Typography.display(isAutomated ? 18 : 21))
            .foregroundStyle(Palette.plaster)
            .padding(.horizontal, 18)
            // Çağ 0'da bu ekranın tek işi. Eleman gelince küçülür —
            // kimse söylemeden "artık asıl iş sende değil" der.
            .frame(maxWidth: .infinity, minHeight: isAutomated ? 50 : 64)
            .background(Palette.enamel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Eleman tut

    @ViewBuilder
    private var hireRow: some View {
        if let cost = hireCost, let next = nextStaff {
            Button(action: onHire) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.hireStaff)
                            .font(Typography.display(17))
                            .foregroundStyle(Palette.ink)
                        Text(canAffordHire ? next.name : hireHint(fallback: next.name))
                            .font(Typography.label(14))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 8)
                    Text(Money.text(cost))
                        .font(Typography.money(17))
                        .foregroundStyle(canAffordHire ? Palette.mustardDeep : Palette.inkFaint)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(Palette.plaster, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.enamel.opacity(canAffordHire ? 0.55 : 0.16), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canAffordHire)
        } else {
            note(L.staffFull)
        }
    }

    /// Para yetmiyorsa hedefi somutlaştır: "38 kahve daha".
    /// Çağ 1'de elle satış artık hedef değil, sadece kimi tuttuğumuzu yazarız.
    private func hireHint(fallback: String) -> String {
        guard let remaining = manualSalesUntilHire else { return fallback }
        return L.coffeesToGo(remaining)
    }

    // MARK: - Depo

    @ViewBuilder
    private var warehouseRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.warehouse)
                    .font(Typography.display(17))
                    .foregroundStyle(Palette.ink)
                Text(L.warehouseHolds(DurationText.text(warehouseCapacity)))
                    .font(Typography.label(14))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 8)

            if let cost = warehouseCost {
                Button(action: onUpgradeWarehouse) {
                    Text(Money.text(cost))
                        .font(Typography.money(16))
                        .foregroundStyle(canAffordWarehouse ? Palette.plaster : Palette.inkFaint)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(
                            canAffordWarehouse ? Palette.pistachio : Palette.stone,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canAffordWarehouse)
                .accessibilityLabel("\(L.upgradeWarehouse), \(Money.text(cost))")
            } else {
                Text(L.warehouseMaxed)
                    .font(Typography.label(14))
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(Palette.plaster, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Palette.enamel.opacity(0.16), lineWidth: 1.5)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typography.label(14))
            .foregroundStyle(Palette.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
