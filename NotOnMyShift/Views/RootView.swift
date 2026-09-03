import SwiftUI

/// Faz 2 ekranı: üstte sakin kasa, ortada bina, altta sekmeli eylem şeridi.
///
/// Cesaret tek yere harcandı — bina. Sayaç ve butonlar onu bastırmıyor.
struct RootView: View {

    @Bindable var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cashBumped = false
    @State private var tab: ActionPanelView.Tab = .crew

    var body: some View {
        ZStack {
            Palette.wall.ignoresSafeArea()

            VStack(spacing: 0) {
                CashHeaderView(
                    money: store.state.money,
                    netRate: store.productionRate,
                    grossRate: store.grossRate,
                    wageRate: store.wageRate,
                    isAutomated: store.state.isAutomated,
                    eventMultiplier: store.eventMultiplier,
                    eventRemaining: store.modifiers.map { store.remainingSeconds(of: $0) }.max(),
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

                BuildingView(
                    floors: store.floors,
                    selectedFloor: store.selectedFloor,
                    plannedFloors: store.plannedFloors,
                    unitCounts: store.unitCounts,
                    hasRoof: store.hasRoof,
                    gainText: "+\(Money.text(store.manualRevenue))",
                    onSelect: { store.selectFloor($0) },
                    onSell: { sell() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                ActionPanelView(store: store, tab: $tab, onSell: { sell() })
                    .padding(.horizontal, 22)
                    .padding(.bottom, 4)

                notices
                    .padding(.horizontal, 22)

                #if DEBUG
                diagnostics
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                #endif
            }
        }
        .sheet(item: $store.offlineReport) { report in
            OfflineReportView(report: report) { store.dismissOfflineReport() }
        }
        .overlay {
            // Final her şeyin üstünde: sahne bittiğinde başka bir kart çıkmasın.
            if let finale = store.finale {
                FinaleView(summary: finale) { store.dismissFinale() }
                    .transition(.opacity)
            } else if let event = store.pendingEvent {
                EventCardView(
                    event: event,
                    instantAmount: { store.eventInstantAmount($0) },
                    onChoose: { store.resolveEvent(event.id, choice: $0) },
                    onDismiss: { store.dismissEvent() }
                )
                .transition(.opacity)
            } else if let member = store.firstHireCelebration {
                MomentBannerView(
                    title: L.startedWork(L.staffName(member.id)),
                    highlight: L.staffTrait(member.id),
                    body: L.firstHireBody,
                    actionTitle: L.firstHireAction
                ) {
                    store.dismissFirstHireCelebration()
                }
                .transition(.opacity)
            } else if !store.managerReport.isEmpty {
                ManagerReportView(actions: store.managerReport) {
                    store.dismissManagerReport()
                }
                .transition(.opacity)
            } else if let sold = store.sectorSaleCelebration {
                MomentBannerView(
                    title: L.soldTitle(L.sectorName(sold)),
                    highlight: L.keepsEarning(Money.preciseText(store.netRate(of: soldFloorIndex(sold)))),
                    body: L.soldBody,
                    actionTitle: L.soldAction
                ) {
                    store.dismissSectorSaleCelebration()
                }
                .transition(.opacity)
            } else if let sector = store.newFloorCelebration {
                MomentBannerView(
                    title: L.newFloorTitle(L.sectorName(sector)),
                    highlight: L.floorNumber(max(1, store.floors.count - 1)),
                    body: L.newFloorBody,
                    actionTitle: L.newFloorAction
                ) {
                    store.dismissNewFloorCelebration()
                }
                .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: store.firstHireCelebration?.id
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: store.newFloorCelebration
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: store.pendingEvent?.id
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: store.managerReport.count
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: store.sectorSaleCelebration
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.25),
            value: store.finale?.id
        )
    }

    // MARK: - Uyarılar

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

    /// Satılan katın sırası. Kutlama metni oradan kalan kirayı yazar.
    private func soldFloorIndex(_ sectorID: String) -> Int {
        store.floors.firstIndex { $0.sectorID == sectorID } ?? store.selectedFloor
    }

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
