import SwiftUI

/// Faz 2 ekranı: üstte sakin kasa, ortada bina, altta sekmeli eylem şeridi.
///
/// Cesaret tek yere harcandı — bina. Sayaç ve butonlar onu bastırmıyor.
struct RootView: View {

    @Bindable var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cashBumped = false
    @State private var tab: ActionPanelView.Tab = .crew
    @State private var showsSupport = false

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
                .overlay(alignment: .topTrailing) {
                    if !store.hasRemovedAds {
                        Button { showsSupport = true } label: {
                            Text(L.supportOpen)
                                .font(Typography.label(12))
                                .foregroundStyle(Palette.enamel)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().stroke(Palette.enamel.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                rewardStrip
                    .padding(.horizontal, 22)

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
        .sheet(isPresented: $showsSupport) {
            SupportView(store: store) { showsSupport = false }
        }
        .sheet(item: $store.offlineReport) { report in
            OfflineReportView(
                report: report,
                doubledEarnings: store.canDoubleOffline ? report.earned * store.offlineMultiplier : nil,
                onDouble: { store.claimOfflineDouble() },
                onDismiss: { store.dismissOfflineReport() }
            )
            // Katlama buradan isteniyor; sahne de burada görünmeli.
            .adBreak(store)
        }
        .overlay {
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
        // Sahne en üstte: sıra kartların üstünde olmalı, altında değil.
        // Dönüş özeti açıkken sahneyi onun katmanı taşır — iki kopya olmasın.
        .adBreak(store, isActive: store.offlineReport == nil)
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

    // MARK: - Ödül şeridi

    /// Vardiya patlaması teklifi. İsteğe bağlı: alınmazsa hiçbir şey eksilmez,
    /// alındığında da yalnızca hızlandırır. Seans başına bir kez.
    @ViewBuilder
    private var rewardStrip: some View {
        if let remaining = store.boostRemaining {
            Text(L.eventRemaining(DurationText.text(remaining)))
                .font(Typography.label(13))
                .foregroundStyle(Palette.pistachio)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        } else if store.canBoost {
            Button { store.claimBoost() } label: {
                HStack(spacing: 8) {
                    Text(L.boostOffer(
                        DurationText.text(store.boostSeconds),
                        multiplierText(store.boostMultiplier)
                    ))
                    .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Text(store.hasRemovedAds ? L.boostTake : L.boostWatch)
                        .foregroundStyle(Palette.mustardDeep)
                }
                .font(Typography.label(14))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Palette.mustard.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private func multiplierText(_ value: Double) -> String {
        value.formatted(.number.locale(Money.current.numberLocale).precision(.fractionLength(0...2)))
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
