import SwiftUI

/// Faz 0 ekranı: çıplak. Tasarım Faz 1'de gelecek — şimdilik motorun döndüğünü
/// gözle görebilmek istiyoruz. Renk olarak sadece arka planı ve vurguyu
/// kullanıyoruz ki açılışta beyaz flaş olmasın.
struct RootView: View {

    @Bindable var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cashBump = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                cashHeader
                sellSection
                hireSection
                warehouseSection
                crewSection
                engineSection
                footer
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.wall.ignoresSafeArea())
        .tint(Palette.enamel)
        .sheet(item: $store.offlineReport) { report in
            OfflineReportView(report: report) {
                store.dismissOfflineReport()
            }
        }
    }

    // MARK: - Kasa

    private var cashHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.cash)
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)

            Text(Money.text(store.state.money))
                .font(.system(size: 44, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .scaleEffect(cashBump ? 1.05 : 1)
                .accessibilityLabel("\(L.cash): \(Money.text(store.state.money))")

            if store.state.isAutomated {
                Text("\(L.perSecond) \(Money.preciseText(store.productionRate))")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(Palette.pistachio)
            } else {
                Text(L.workingByHand)
                    .font(.callout)
                    .foregroundStyle(Palette.inkSoft)
            }

            if store.didRecoverFromBackup {
                notice(L.saveRecovered)
            }
            if store.didFailToSave {
                notice(L.saveFailed)
            }
        }
    }

    // MARK: - Elle satış

    private var sellSection: some View {
        Button {
            store.sellManually()
            bumpCash()
        } label: {
            Text("\(L.sellCoffee)  +\(Money.text(store.config.manual.revenuePerSale))")
                .font(.headline)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Eleman

    private var hireSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cost = store.hireCost, let next = store.nextStaffTemplate {
                Button {
                    store.hireStaff()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(L.hireStaff) — \(Money.text(cost))")
                            .font(.headline)
                            .monospacedDigit()
                        Text(next.name)
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(store.state.money < cost)
            } else {
                Text(L.staffFull)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            }

            if store.lastActionError == .insufficientFunds {
                notice(L.notEnoughMoney)
            }
        }
    }

    // MARK: - Depo

    private var warehouseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.warehouse)
                .font(.headline)
                .foregroundStyle(Palette.ink)

            Text("\(L.warehouseExplainer) \(DurationText.text(store.offlineCapacitySeconds))")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)

            if let cost = store.warehouseUpgradeCost {
                Button {
                    store.upgradeWarehouse()
                } label: {
                    Text("\(L.upgradeWarehouse) — \(Money.text(cost))")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(store.state.money < cost)
            } else {
                Text(L.warehouseMaxed)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    // MARK: - Kadro

    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.crew)
                .font(.headline)
                .foregroundStyle(Palette.ink)

            if store.state.staff.isEmpty {
                Text(L.crewEmpty)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(store.state.staff) { member in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text(member.trait)
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Motor (Faz 0 tanılama)

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.engine)
                .font(.headline)
                .foregroundStyle(Palette.ink)

            row(L.totalPlayed, DurationText.text(store.state.elapsedGameSeconds))
            row(L.manualSales, "\(store.state.stats.manualSales)")
            row(L.lifetime, Money.text(store.state.lifetimeEarnings))
        }
    }

    private var footer: some View {
        Button("Baştan başla", role: .destructive) {
            store.startOver()
        }
        .font(.footnote)
    }

    // MARK: - Küçük parçalar

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Palette.inkSoft)
            Spacer(minLength: 12)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .font(.subheadline)
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Palette.mustard)
    }

    /// Tek animasyon: kasa sayacının kısa bir nefes alması. Oyuncunun eylemine
    /// cevaptır, kendiliğinden dönmez. Hareket azaltma açıksa hiç olmaz.
    private func bumpCash() {
        guard !reduceMotion else { return }
        withAnimation(.spring(duration: 0.18)) { cashBump = true }
        withAnimation(.spring(duration: 0.18).delay(0.09)) { cashBump = false }
    }
}
