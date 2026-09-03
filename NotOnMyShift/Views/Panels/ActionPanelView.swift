import SwiftUI

/// Binanın altındaki disiplinli şerit.
///
/// Faz 2'de üç katman birden var (kadro, ekipman, şube) — hepsini alt alta
/// dizmek binayı ezerdi. Üç şeride ayırdık: satış butonu hep görünür, altında
/// sekmeler. Kart estetiğinden kaçınıyoruz; ayrım emaye ince çizgiyle yapılıyor,
/// tabelanın diliyle aynı.
struct ActionPanelView: View {

    enum Tab: String, CaseIterable, Identifiable {
        case crew, equipment, branches, building

        var id: String { rawValue }

        var title: String {
            switch self {
            case .crew: L.tabCrew
            case .equipment: L.tabEquipment
            case .branches: L.tabBranches
            case .building: L.tabBuilding
            }
        }
    }

    @Bindable var store: GameStore
    @Binding var tab: Tab
    let onSell: () -> Void

    /// Şerit içeriğinin yüksekliği. Bina kalan yeri alır.
    private let contentHeight: CGFloat = 196

    var body: some View {
        VStack(spacing: 10) {
            sellButton
            tabBar

            ScrollView {
                VStack(spacing: 8) {
                    switch tab {
                    case .crew: crewTab
                    case .equipment: equipmentTab
                    case .branches: branchesTab
                    case .building: buildingTab
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(height: contentHeight)
            .scrollBounceBehavior(.basedOnSize)

            if store.lastActionError == .insufficientFunds {
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
                Text(L.sectorSell(store.currentFloor?.sectorID ?? ""))
                Spacer(minLength: 12)
                Text("+\(Money.text(store.manualRevenue))")
                    .foregroundStyle(Palette.mustard)
            }
            .font(Typography.display(store.state.isAutomated ? 18 : 21))
            .foregroundStyle(Palette.plaster)
            .padding(.horizontal, 18)
            // Çağ 0'da bu ekranın tek işi. Eleman gelince küçülür —
            // kimse söylemeden "artık asıl iş sende değil" der.
            .frame(maxWidth: .infinity, minHeight: store.state.isAutomated ? 50 : 64)
            .background(Palette.enamel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sekmeler

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 6) {
                        Text(item.title)
                            .font(Typography.display(15))
                            .foregroundStyle(tab == item ? Palette.ink : Palette.inkFaint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Rectangle()
                            .fill(tab == item ? Palette.enamel : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? [.isButton, .isSelected] : .isButton)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.enamel.opacity(0.12))
                .frame(height: 1)
        }
    }

    // MARK: - Kadro

    @ViewBuilder
    private var crewTab: some View {
        if let cost = store.hireCost, let next = store.nextStaffTemplate {
            row(
                title: L.hireStaff,
                subtitle: store.state.money >= cost ? L.staffName(next.id) : hireHint(fallback: L.staffName(next.id)),
                trailing: Money.text(cost),
                enabled: store.state.money >= cost,
                action: { store.hireStaff() }
            )
        } else {
            note(L.staffFull)
        }

        ForEach(store.state.staff) { member in
            VStack(alignment: .leading, spacing: 1) {
                Text(L.staffName(member.id))
                    .font(Typography.display(15))
                    .foregroundStyle(Palette.ink)
                Text(L.staffTrait(member.id))
                    .font(.system(.footnote))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
        }
    }

    /// Para yetmiyorsa hedefi somutlaştır: "38 more to go".
    /// Çağ 1'de elle satış artık hedef değil, sadece kimi tuttuğumuzu yazarız.
    private func hireHint(fallback: String) -> String {
        guard let remaining = store.manualSalesUntilHire else { return fallback }
        return L.coffeesToGo(remaining)
    }

    // MARK: - Ekipman

    @ViewBuilder
    private var equipmentTab: some View {
        ForEach(store.equipmentRows) { item in
            row(
                title: L.equipmentName(item.id),
                // Yeni parça kendini anlatsın; sahip olunan parça sayısını göstersin.
                subtitle: item.level == 0
                    ? L.equipmentNote(item.id)
                    : "\(L.equipmentLevel(item.level)) · \(L.equipmentOutput(multiplierText(item.multiplier)))",
                trailing: item.upgradeCost.map(Money.text) ?? L.equipmentMaxed,
                enabled: item.upgradeCost.map { store.state.money >= $0 } ?? false,
                action: { store.upgradeEquipment(item.id) }
            )
        }
    }

    /// Çarpan para değil: kısaltma yok, iki haneye kadar ondalık var.
    private func multiplierText(_ value: Double) -> String {
        value.formatted(
            .number.locale(Money.current.numberLocale).precision(.fractionLength(0...2))
        )
    }

    // MARK: - Şubeler

    @ViewBuilder
    private var branchesTab: some View {
        if let cost = store.branchCost {
            row(
                title: L.branchOpen,
                subtitle: L.branchesRunning(store.branchCount),
                trailing: Money.text(cost),
                enabled: store.state.money >= cost,
                action: { store.openBranch() }
            )
            note(L.branchInherits)
        } else if store.isBranchBlockedByMarket {
            // Rakip kapıyı kapatmadı, geciktirdi: yatırım payı geri getirir.
            note(L.marketBlocked)
            note(L.branchesRunning(store.branchCount))
        } else {
            note(L.branchesFull)
            note(L.branchesRunning(store.branchCount))
        }
    }

    // MARK: - Bina

    @ViewBuilder
    private var buildingTab: some View {
        if let cost = store.nextFloorCost, let next = store.nextSector {
            row(
                title: L.openNextFloor,
                subtitle: L.floorOpensSector(L.sectorName(next.id)),
                trailing: Money.text(cost),
                enabled: store.state.money >= cost,
                action: { store.unlockNextFloor() }
            )
        } else {
            note(L.buildingFull)
        }

        // Depo bütün katların ortak kapasitesi, tek bir sektörün değil.
        row(
            title: L.upgradeWarehouse,
            subtitle: L.warehouseHolds(DurationText.text(store.offlineCapacitySeconds)),
            trailing: store.warehouseUpgradeCost.map(Money.text) ?? L.equipmentMaxed,
            enabled: store.warehouseUpgradeCost.map { store.state.money >= $0 } ?? false,
            action: { store.upgradeWarehouse() }
        )

        MarketShareView(
            share: store.marketShare,
            competitors: store.competitorShares,
            unlockedSlots: store.branchSlots,
            isBlocked: store.isBranchBlockedByMarket
        )
        .padding(.top, 2)

        ForEach(Array(store.floors.enumerated()), id: \.element.id) { entry in
            HStack(spacing: 10) {
                Text(entry.offset == 0 ? L.groundFloor : L.floorNumber(entry.offset))
                    .foregroundStyle(Palette.inkFaint)
                Text(L.sectorName(entry.element.sectorID))
                    .foregroundStyle(entry.offset == store.selectedFloor ? Palette.ink : Palette.inkSoft)
                Spacer(minLength: 8)
                Text(Money.preciseText(store.netRate(of: entry.offset)))
                    .foregroundStyle(Palette.pistachio)
            }
            .font(Typography.label(13))
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
        }
    }

    // MARK: - Ortak satır

    private func row(
        title: String,
        subtitle: String,
        trailing: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.display(17))
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(Typography.label(14))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Text(trailing)
                    .font(Typography.money(16))
                    .foregroundStyle(enabled ? Palette.mustardDeep : Palette.inkFaint)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(Palette.plaster, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Palette.enamel.opacity(enabled ? 0.55 : 0.16), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("\(title), \(trailing)")
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typography.label(14))
            .foregroundStyle(Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
    }
}
