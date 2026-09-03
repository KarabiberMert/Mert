import SwiftUI

/// Tek bir kat bandı: yapı, kadro, tezgâh.
struct FloorBandView: View {

    let floor: FloorState
    let palette: FloorPalette
    let unitCount: Int
    let isGround: Bool
    /// Patron bu kattaysa mustard önlüğüyle görünür.
    let showsOwner: Bool

    var body: some View {
        GeometryReader { proxy in
            let band = FloorGeometry(rect: CGRect(origin: .zero, size: proxy.size))
            let detail = band.detail(unitCount: unitCount)

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    FloorScene.drawBack(
                        in: &context,
                        band: FloorGeometry(rect: CGRect(origin: .zero, size: size)),
                        palette: palette,
                        sector: floor.sectorID,
                        unitCount: unitCount,
                        isGround: isGround,
                        detail: detail
                    )
                }

                crew(in: band, detail: detail)

                Canvas { context, size in
                    FloorScene.drawFront(
                        in: &context,
                        band: FloorGeometry(rect: CGRect(origin: .zero, size: size)),
                        palette: palette,
                        sector: floor.sectorID,
                        unitCount: unitCount,
                        detail: detail
                    )
                }
                .allowsHitTesting(false)
            }
        }
        .clipped()
    }

    // MARK: - Kadro

    /// Her hücre aynı kadroyla çalışır — şube açmak kopyalamaktır.
    /// Patron bir tane: yalnızca ilk hücrede durur.
    @ViewBuilder
    private func crew(in band: FloorGeometry, detail: FloorDetail) -> some View {
        let capacity = band.visibleFigures(unitCount: unitCount)
        let visible = min(floor.staff.count, capacity)
        let ownerInRow = showsOwner && (visible < capacity || floor.staff.isEmpty)
        let total = max(1, visible + (ownerInRow ? 1 : 0))

        ZStack(alignment: .topLeading) {
            ForEach(Array(0..<max(1, unitCount)), id: \.self) { unitIndex in
                let unit = band.unit(unitIndex, of: unitCount)

                ForEach(Array(floor.staff.prefix(visible).enumerated()), id: \.element.id) { entry in
                    figure(
                        in: band,
                        unit: unit,
                        centerX: UnitGeometry.slotCenter(index: entry.offset, count: total),
                        scale: 1,
                        apron: entry.offset.isMultiple(of: 2) ? palette.apron : palette.apronAlt,
                        skin: Palette.skinTones[entry.offset % Palette.skinTones.count]
                    )
                    .transition(.opacity.combined(with: .offset(y: -band.h(0.12))))
                }

                if ownerInRow, unitIndex == 0 {
                    figure(
                        in: band,
                        unit: unit,
                        centerX: UnitGeometry.slotCenter(index: visible, count: total),
                        scale: floor.staff.isEmpty ? 1 : 0.92,
                        apron: palette.ownerApron,
                        skin: Palette.skinTones[0]
                    )
                }
            }
        }
    }

    private func figure(
        in band: FloorGeometry,
        unit: UnitGeometry,
        centerX: Double,
        scale: Double,
        apron: Color,
        skin: Color
    ) -> some View {
        let bodyHeight = band.h(FloorGeometry.figureBodyHeight * scale)
        let width = bodyHeight * FloorGeometry.figureWidthRatio
        let headRadius = bodyHeight * FloorGeometry.figureHeadRatio
        let totalHeight = bodyHeight + headRadius * 2.2

        return ShopFigureView(
            width: width,
            bodyHeight: bodyHeight,
            headRadius: headRadius,
            apron: apron,
            skin: skin,
            standing: false
        )
        .position(
            x: unit.x(centerX),
            y: band.y(FloorGeometry.floorY) - totalHeight / 2
        )
    }
}
