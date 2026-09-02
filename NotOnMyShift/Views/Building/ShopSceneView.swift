import SwiftUI

/// Ekranın kahramanı: zemin katın kesiti.
///
/// Cesaret buraya harcanıyor; kasa sayacı ve alt panel sakin duruyor.
/// Katmanlar: arka mimari → kadro → tezgâh ve makine.
///
/// Hareket kuralı: sahne kendiliğinden kıpırdamaz. Sadece oyuncunun eylemine
/// cevap verir — dokununca süzülen rakam, eleman gelince kata yerleşme.
struct ShopSceneView: View {

    let staff: [StaffMember]
    let shopName: String
    /// Dokunma başına yazılan miktarın hazır metni ("+4 ₺").
    let gainText: String
    let onSell: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gains: [Gain] = []

    private struct Gain: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    var body: some View {
        GeometryReader { proxy in
            let geometry = ShopGeometry(size: proxy.size)

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    ShopScene.drawBack(
                        in: &context,
                        geometry: ShopGeometry(size: size),
                        shopName: shopName
                    )
                }

                crew(in: geometry)

                Canvas { context, size in
                    ShopScene.drawFront(in: &context, geometry: ShopGeometry(size: size))
                }
                .allowsHitTesting(false)

                ForEach(gains) { gain in
                    FloatingGainView(text: gain.text, fontSize: geometry.span(0.058))
                        .position(geometry.point(0.163, 0.600))
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { sell() }
        }
        .aspectRatio(ShopGeometry.designAspectRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.shopAccessibility)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { sell() }
    }

    // MARK: - Kadro

    @ViewBuilder
    private func crew(in geometry: ShopGeometry) -> some View {
        let count = staff.count
        let scale = ShopGeometry.slotScale(count: count)

        ZStack(alignment: .topLeading) {
            ForEach(Array(staff.enumerated()), id: \.element.id) { entry in
                figure(
                    in: geometry,
                    centerX: ShopGeometry.slotCenter(index: entry.offset, count: count),
                    scale: scale,
                    apron: entry.offset.isMultiple(of: 2) ? Palette.pistachio : Palette.pistachioDeep,
                    skin: Palette.skinTones[entry.offset % Palette.skinTones.count],
                    standing: false
                )
                .transition(
                    .asymmetric(
                        insertion: .offset(y: -geometry.y(0.05)).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            }

            // Patron: tek başınayken tezgâhta, kadro varken salonda gözlüyor.
            figure(
                in: geometry,
                centerX: staff.isEmpty ? ShopGeometry.ownerWorkingX : ShopGeometry.ownerStandingX,
                scale: staff.isEmpty ? 1.0 : 0.92,
                apron: Palette.mustard,
                skin: Palette.skinTones[0],
                standing: !staff.isEmpty
            )
        }
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.72), value: count)
    }

    private func figure(
        in geometry: ShopGeometry,
        centerX: Double,
        scale: Double,
        apron: Color,
        skin: Color,
        standing: Bool
    ) -> some View {
        let width = geometry.span(ShopGeometry.figureWidth * scale)
        let bodyHeight = geometry.y(ShopGeometry.figureHeight * scale)
        let headRadius = geometry.span(ShopGeometry.figureHeadRadius * scale)
        let totalHeight = bodyHeight + headRadius * 2.2

        return ShopFigureView(
            width: width,
            bodyHeight: bodyHeight,
            headRadius: headRadius,
            apron: apron,
            skin: skin,
            standing: standing
        )
        .position(
            x: geometry.x(centerX),
            y: geometry.y(ShopGeometry.floorY) - totalHeight / 2
        )
    }

    // MARK: - Satış

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
            .font(Typography.money(fontSize))
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
