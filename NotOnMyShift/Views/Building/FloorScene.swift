import SwiftUI

/// Bir kat bandının çizimi.
///
/// Katmanlar: arka yapı (döşeme, duvar, fayans, tabela, zemin, duvar demirbaşı)
/// → kadro (görünüm olarak üstüne biner) → ön yapı (tezgâh ve üstündekiler).
enum FloorScene {

    // Köşe yuvarlaklıkları — bandın yüksekliğine oranlı.
    private static let radiusPanel = 0.06
    private static let radiusSmall = 0.035
    private static let radiusTiny = 0.018

    // MARK: - Arka katman

    static func drawBack(
        in context: inout GraphicsContext,
        band: FloorGeometry,
        palette: FloorPalette,
        sector: String,
        unitCount: Int,
        isGround: Bool,
        detail: FloorDetail
    ) {
        drawWall(in: &context, band: band, palette: palette)
        if isGround {
            drawAwning(in: &context, band: band, palette: palette)
        } else {
            drawSlab(in: &context, band: band, palette: palette)
        }
        drawTiles(in: &context, band: band, palette: palette, detail: detail)
        drawSign(in: &context, band: band, palette: palette, sector: sector, detail: detail)
        drawGround(in: &context, band: band, palette: palette)

        for index in 0..<max(1, unitCount) {
            let unit = band.unit(index, of: unitCount)
            if index > 0 {
                drawPartition(in: &context, unit: unit, palette: palette)
            }
            SectorFittings.drawWallFitting(
                in: &context, unit: unit, palette: palette, sector: sector, detail: detail
            )
        }
    }

    // MARK: - Ön katman

    static func drawFront(
        in context: inout GraphicsContext,
        band: FloorGeometry,
        palette: FloorPalette,
        sector: String,
        unitCount: Int,
        detail: FloorDetail
    ) {
        for index in 0..<max(1, unitCount) {
            let unit = band.unit(index, of: unitCount)
            drawCounter(in: &context, unit: unit, palette: palette, detail: detail)
            SectorFittings.drawCounterFitting(
                in: &context, unit: unit, palette: palette, sector: sector, detail: detail
            )
        }
    }

    // MARK: - Parçalar

    private static func drawWall(in context: inout GraphicsContext, band: FloorGeometry, palette: FloorPalette) {
        context.fill(Path(band.box(0, 0, 1, 1)), with: .color(palette.frame))
        context.fill(
            Path(band.box(
                FloorGeometry.interiorLeft, FloorGeometry.slabBottom,
                FloorGeometry.interiorRight, FloorGeometry.bandBottom
            )),
            with: .color(palette.wall)
        )
    }

    private static func drawSlab(in context: inout GraphicsContext, band: FloorGeometry, palette: FloorPalette) {
        context.fill(
            Path(band.box(0, FloorGeometry.slabTop, 1, FloorGeometry.slabBottom)),
            with: .color(palette.frameDeep)
        )
    }

    /// Zemin katın tentesi. Döşemenin yerine geçer — sokağa bakan tek kat o.
    private static func drawAwning(in context: inout GraphicsContext, band: FloorGeometry, palette: FloorPalette) {
        context.fill(
            Path(band.box(0, FloorGeometry.slabTop, 1, FloorGeometry.slabBottom)),
            with: .color(palette.frameDeep)
        )

        let count = FloorGeometry.awningStripes
        let top = FloorGeometry.slabBottom
        let bottom = FloorGeometry.awningBottom
        let depth = band.h((bottom - top) * 0.45)

        for index in 0..<count {
            let a = Double(index) / Double(count)
            let b = Double(index + 1) / Double(count)
            let color = index.isMultiple(of: 2) ? palette.frame : palette.signText

            context.fill(Path(band.box(a, top, b, bottom)), with: .color(color))

            // fisto: alt kenarda yarım daire
            var scallop = Path()
            let baseline = band.y(bottom)
            scallop.move(to: CGPoint(x: band.x(a), y: baseline))
            scallop.addQuadCurve(
                to: CGPoint(x: band.x(b), y: baseline),
                control: CGPoint(x: band.x((a + b) / 2), y: baseline + depth * 2)
            )
            scallop.closeSubpath()
            context.fill(scallop, with: .color(color))
        }
    }

    /// Çini lambri. Karanfil motifinin sadeleştirilmiş hâli: elmas + göbek.
    private static func drawTiles(
        in context: inout GraphicsContext,
        band: FloorGeometry,
        palette: FloorPalette,
        detail: FloorDetail
    ) {
        let left = FloorGeometry.interiorLeft
        let right = FloorGeometry.interiorRight
        context.fill(
            Path(band.box(left, FloorGeometry.tileTop, right, FloorGeometry.tileBottom)),
            with: .color(palette.tileField)
        )

        if detail.showsFineDetail {
            let height = FloorGeometry.tileBottom - FloorGeometry.tileTop
            // Kare fayans: sütun sayısı bandın oranından çıkar.
            let columns = max(4, Int((band.w(right - left) / band.h(height)).rounded()))
            let tileWidth = (right - left) / Double(columns)

            for column in 0..<columns {
                let originX = left + Double(column) * tileWidth
                context.stroke(
                    Path(band.box(originX, FloorGeometry.tileTop, originX + tileWidth, FloorGeometry.tileBottom)),
                    with: .color(palette.tileLine),
                    lineWidth: band.h(0.008)
                )

                let midX = originX + tileWidth / 2
                let midY = (FloorGeometry.tileTop + FloorGeometry.tileBottom) / 2
                let armX = tileWidth * 0.26
                let armY = height * 0.26

                var diamond = Path()
                diamond.move(to: band.point(midX, midY - armY))
                diamond.addLine(to: band.point(midX + armX, midY))
                diamond.addLine(to: band.point(midX, midY + armY))
                diamond.addLine(to: band.point(midX - armX, midY))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(palette.tileMotif))

                context.fill(
                    Path(ellipseIn: band.box(
                        midX - armX * 0.34, midY - armY * 0.34,
                        midX + armX * 0.34, midY + armY * 0.34
                    )),
                    with: .color(palette.wall)
                )
            }
        }

        for edge in [FloorGeometry.tileTop, FloorGeometry.tileBottom - 0.020] {
            context.fill(
                Path(band.box(left, edge, right, edge + 0.020)),
                with: .color(palette.tileEdge)
            )
        }
    }

    /// Emaye tabela: katın hangi işe ayrıldığını söyleyen tek yazı.
    private static func drawSign(
        in context: inout GraphicsContext,
        band: FloorGeometry,
        palette: FloorPalette,
        sector: String,
        detail: FloorDetail
    ) {
        let plate = band.box(0.045, FloorGeometry.signTop, 0.46, FloorGeometry.signBottom)
        context.fill(
            Path(roundedRect: plate, cornerRadius: band.h(radiusSmall)),
            with: .color(palette.sign)
        )
        guard detail.showsFineDetail else { return }

        let keyline = plate.insetBy(dx: band.h(0.030), dy: band.h(0.030))
        context.stroke(
            Path(roundedRect: keyline, cornerRadius: band.h(radiusTiny)),
            with: .color(palette.signText),
            lineWidth: band.h(0.016)
        )

        // Tabela adı `balance.json`'dan değil dil dosyasından gelir ve
        // göründüğü hâliyle yazılır; kod büyük harfe çevirmez.
        let available = keyline.width * 0.90
        var size = band.h(0.135)
        var resolved = context.resolve(
            Text(L.sectorSign(sector))
                .font(Typography.signage(size))
                .foregroundColor(palette.signText)
        )
        let measured = resolved.measure(in: CGSize(width: 10_000, height: 10_000)).width
        if measured > available, measured > 0 {
            size *= available / measured
            resolved = context.resolve(
                Text(L.sectorSign(sector))
                    .font(Typography.signage(size))
                    .foregroundColor(palette.signText)
            )
        }
        context.draw(resolved, at: CGPoint(x: keyline.midX, y: keyline.midY), anchor: .center)
    }

    private static func drawGround(in context: inout GraphicsContext, band: FloorGeometry, palette: FloorPalette) {
        context.fill(
            Path(band.box(
                FloorGeometry.interiorLeft, FloorGeometry.floorY,
                FloorGeometry.interiorRight, FloorGeometry.bandBottom
            )),
            with: .color(palette.ground)
        )
    }

    /// Hücreleri ayıran ince bölme. "Kat içindeki hücreler" bunlarla okunur.
    private static func drawPartition(in context: inout GraphicsContext, unit: UnitGeometry, palette: FloorPalette) {
        context.fill(
            Path(unit.box(-0.012, FloorGeometry.tileTop, 0.012, FloorGeometry.bandBottom)),
            with: .color(palette.frameDeep.opacity(0.55))
        )
    }

    private static func drawCounter(
        in context: inout GraphicsContext,
        unit: UnitGeometry,
        palette: FloorPalette,
        detail: FloorDetail
    ) {
        context.fill(
            Path(unit.box(
                UnitGeometry.counterLeft, FloorGeometry.counterSlabBottom,
                UnitGeometry.counterRight, FloorGeometry.floorY
            )),
            with: .color(palette.counter)
        )
        context.fill(
            Path(roundedRect: unit.box(
                UnitGeometry.counterLeft - 0.02, FloorGeometry.counterTop,
                UnitGeometry.counterRight + 0.02, FloorGeometry.counterSlabBottom
            ), cornerRadius: unit.h(radiusTiny)),
            with: .color(palette.counterTop)
        )

        guard detail.showsFineDetail else { return }
        let slats = 3
        let span = UnitGeometry.counterRight - UnitGeometry.counterLeft
        for index in 0..<slats {
            let a = UnitGeometry.counterLeft + span * (Double(index) + 0.12) / Double(slats)
            let b = UnitGeometry.counterLeft + span * (Double(index) + 0.88) / Double(slats)
            context.fill(
                Path(roundedRect: unit.box(a, FloorGeometry.counterSlabBottom + 0.030, b, FloorGeometry.floorY - 0.030),
                     cornerRadius: unit.h(radiusTiny)),
                with: .color(palette.counterShade)
            )
        }
    }
}
