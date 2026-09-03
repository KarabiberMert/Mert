import SwiftUI

/// Ekranın kahramanı: kat kat yükselen bina.
///
/// Her kat bir sektör, kat içindeki hücreler o sektörün şubeleri. Zemin kat
/// sokağa bakar — tentesi ve kaldırımı var. Yukarı çıktıkça palet soğur ve
/// camlaşır; oyuncu bunu kimse söylemeden hisseder.
///
/// Etkileşim: başka bir kata dokunmak onu seçer, seçili kata dokunmak satış yapar.
struct BuildingView: View {

    let floors: [FloorState]
    let selectedFloor: Int
    let plannedFloors: Int
    /// Kat başına hücre (şube) sayısı.
    let unitCounts: [Int]
    /// Çatı katı açıldı mı — açıldıysa bina tepesinde ofis bandını taşır.
    let hasRoof: Bool
    /// Dokunma başına yazılan miktarın hazır metni ("+$4").
    let gainText: String
    let onSelect: (Int) -> Void
    let onSell: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gains: [Gain] = []

    private struct Gain: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = BuildingLayout(floorCount: floors.count, available: proxy.size, hasRoof: hasRoof)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Palette.stone)
                    .frame(width: layout.pavementFrame.width, height: layout.pavementFrame.height)
                    .position(x: layout.pavementFrame.midX, y: layout.pavementFrame.midY)

                if let roof = layout.roofFrame {
                    RoofBandView(plannedFloors: plannedFloors)
                        .frame(width: roof.width, height: roof.height)
                        .position(x: roof.midX, y: roof.midY)
                        .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .bottom)))
                        .allowsHitTesting(false)
                }

                ForEach(Array(floors.enumerated()), id: \.element.id) { entry in
                    let index = entry.offset
                    let frame = layout.frame(of: index)

                    FloorBandView(
                        floor: entry.element,
                        palette: FloorPalette(floor: index, plannedFloors: plannedFloors),
                        unitCount: unitCounts.indices.contains(index) ? unitCounts[index] : 1,
                        isGround: index == 0,
                        showsOwner: index == selectedFloor
                    )
                    .frame(width: frame.width, height: frame.height)
                    .overlay {
                        // Seçili kat: hardal bir keyline. Para ile aynı renk —
                        // "şu an burayı yönetiyorsun".
                        if index == selectedFloor, floors.count > 1 {
                            Rectangle()
                                .stroke(Palette.mustard, lineWidth: 2)
                        }
                    }
                    .opacity(index == selectedFloor || floors.count == 1 ? 1 : 0.78)
                    .position(x: frame.midX, y: frame.midY)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Yatırım katında tezgâh yok: dokunmak sahte bir rakam
                        // uçurmasın. Kat yine de seçilebilir.
                        if index == selectedFloor {
                            if !entry.element.isInvestment { sell() }
                        } else {
                            onSelect(index)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .bottom)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L.sectorName(entry.element.sectorID))
                    .accessibilityAddTraits(index == selectedFloor ? [.isButton, .isSelected] : .isButton)
                    .accessibilityHint(index == selectedFloor && !entry.element.isInvestment ? L.shopAccessibility : "")
                    .accessibilityAction {
                        if index == selectedFloor {
                            if !entry.element.isInvestment { sell() }
                        } else {
                            onSelect(index)
                        }
                    }
                }

                ForEach(gains) { gain in
                    let frame = layout.frame(of: min(selectedFloor, max(0, floors.count - 1)))
                    FloatingGainView(text: gain.text, fontSize: frame.height * 0.22)
                        .position(
                            x: frame.minX + frame.width * 0.16,
                            y: frame.minY + frame.height * FloorGeometry.counterTop
                        )
                }
                .allowsHitTesting(false)
            }
            .animation(
                reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.78),
                value: floors.count
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.78),
                value: hasRoof
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.22),
                value: selectedFloor
            )
        }
    }

    private func sell() {
        onSell()

        let gain = Gain(text: gainText)
        gains.append(gain)
        // Hızlı dokunuşta ekran rakam çöplüğüne dönmesin.
        if gains.count > 5 {
            gains.removeFirst(gains.count - 5)
        }

        Task {
            try? await Task.sleep(for: .milliseconds(850))
            gains.removeAll { $0.id == gain.id }
        }
    }
}

/// Kazanılan paranın tezgâhtan yukarı süzülmesi.
/// Hareket azaltma açıkken rakam yerinde durur, sadece görünüp kaybolur.
private struct FloatingGainView: View {

    let text: String
    let fontSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    var body: some View {
        Text(text)
            .font(Typography.money(max(11, fontSize)))
            .foregroundStyle(Palette.mustard)
            .shadow(color: Palette.plaster.opacity(0.9), radius: 1)
            .offset(y: lifted ? -fontSize * 1.6 : 0)
            .opacity(lifted ? 0 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.85)) { lifted = true }
            }
            .accessibilityHidden(true)
    }
}
