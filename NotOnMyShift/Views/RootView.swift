import SwiftUI

/// Faz 1 ekranı: üstte sakin kasa, ortada bina, altta disiplinli eylem şeridi.
///
/// Cesaret tek yere harcandı — bina. Sayaç ve butonlar onu bastırmıyor.
struct RootView: View {

    @Bindable var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cashBumped = false

    var body: some View {
        ZStack {
            Palette.wall.ignoresSafeArea()

            VStack(spacing: 0) {
                CashHeaderView(
                    money: store.state.money,
                    productionRate: store.productionRate,
                    isAutomated: store.state.isAutomated,
                    bumped: cashBumped
                )
                .padding(.horizontal, 22)
                .padding(.top, 6)

                if !store.state.isAutomated {
                    Text(L.tapToSell)
                        .font(Typography.label(13))
                        .foregroundStyle(Palette.inkFaint)
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ShopSceneView(
                    staff: store.state.staff,
                    gainText: "+\(Money.text(store.config.manual.revenuePerSale))",
                    onSell: { sell() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                crewLine
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)

                actionPanel
                    .padding(.horizontal, 22)
                    .padding(.bottom, 4)

                notices
                    .padding(.horizontal, 22)

                #if DEBUG
                diagnostics
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                #endif
            }
        }
        .sheet(item: $store.offlineReport) { report in
            OfflineReportView(report: report) { store.dismissOfflineReport() }
        }
        .overlay {
            if let member = store.firstHireCelebration {
                FirstHireBannerView(member: member) {
                    store.dismissFirstHireCelebration()
                }
                .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: store.firstHireCelebration?.id
        )
    }

    /// Kadro tek satırda. Elemanların isimleri oyunun tonunu taşıyor;
    /// listeye çevirmeden görünür kalsınlar.
    @ViewBuilder
    private var crewLine: some View {
        if !store.state.staff.isEmpty {
            HStack(spacing: 6) {
                Text(L.crew)
                    .foregroundStyle(Palette.inkFaint)
                Text(store.state.staff.map { L.staffName($0.id) }.joined(separator: ", "))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(Typography.label(13))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Alt şerit

    private var actionPanel: some View {
        ActionPanelView(
            sellTitle: L.sellCoffee,
            gainText: "+\(Money.text(store.config.manual.revenuePerSale))",
            isAutomated: store.state.isAutomated,
            hireCost: store.hireCost,
            nextStaff: store.nextStaffTemplate,
            canAffordHire: store.hireCost.map { store.state.money >= $0 } ?? false,
            manualSalesUntilHire: store.manualSalesUntilHire,
            warehouseCapacity: store.offlineCapacitySeconds,
            warehouseCost: store.warehouseUpgradeCost,
            canAffordWarehouse: store.warehouseUpgradeCost.map { store.state.money >= $0 } ?? false,
            showsFundsWarning: store.lastActionError == .insufficientFunds,
            onSell: { sell() },
            onHire: { store.hireStaff() },
            onUpgradeWarehouse: { store.upgradeWarehouse() }
        )
    }

    @ViewBuilder
    private var notices: some View {
        if store.didRecoverFromBackup {
            notice(L.saveRecovered)
        }
        if store.didFailToSave {
            notice(L.saveFailed)
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(Typography.label(13))
            .foregroundStyle(Palette.mustardDeep)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    // MARK: - Eylem

    private func sell() {
        store.sellManually()
        guard !reduceMotion else { return }
        withAnimation(.spring(duration: 0.16)) { cashBumped = true }
        withAnimation(.spring(duration: 0.16).delay(0.08)) { cashBumped = false }
    }

    // MARK: - Geliştirme

    #if DEBUG
    private var diagnostics: some View {
        DisclosureGroup(L.engine) {
            VStack(spacing: 4) {
                row(L.totalPlayed, DurationText.text(store.state.elapsedGameSeconds))
                row(L.manualSales, "\(store.state.stats.manualSales)")
                row(L.lifetime, Money.text(store.state.lifetimeEarnings))
                Button(L.startOver, role: .destructive) { store.startOver() }
                    .font(Typography.label(13))
                    .padding(.top, 4)
            }
            .padding(.top, 6)
        }
        .font(Typography.label(13))
        .tint(Palette.inkSoft)
        .foregroundStyle(Palette.inkSoft)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
        }
        .font(Typography.label(13))
        .foregroundStyle(Palette.inkSoft)
    }
    #endif
}
