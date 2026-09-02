import SwiftUI

/// Zemin katın sabit mimarisi. Figürler bu çizimin arasına giriyor:
/// arka katman → kadro → ön katman (tezgâh, makine).
///
/// Ölçüler `ShopGeometry` içinde; buradaki her sayı oradan geliyor ya da
/// oranın kendisi (motif payı, çıta sayısı gibi).
enum ShopScene {

    // Köşe yuvarlaklıkları — 390pt genişliğe göre oranlandı.
    private static let radiusShell = 0.018
    private static let radiusSign = 0.023
    private static let radiusPanel = 0.013
    private static let radiusSmall = 0.008
    private static let radiusTiny = 0.005
    private static let radiusChip = 0.010

    // MARK: - Arka katman

    static func drawBack(in context: inout GraphicsContext, geometry g: ShopGeometry, shopName: String) {
        drawShell(in: &context, g: g)
        drawSign(in: &context, g: g, shopName: shopName)
        drawAwning(in: &context, g: g)
        drawInterior(in: &context, g: g)
        drawTiles(in: &context, g: g)
        drawShelf(in: &context, g: g)
        drawChalkboard(in: &context, g: g)
        drawLamp(in: &context, g: g)
        drawFloor(in: &context, g: g)
        drawDoor(in: &context, g: g)
        drawPlant(in: &context, g: g)
    }

    // MARK: - Ön katman

    static func drawFront(in context: inout GraphicsContext, geometry g: ShopGeometry) {
        drawCounter(in: &context, g: g)
        drawMachine(in: &context, g: g)
        drawCup(in: &context, g: g)
        drawPavement(in: &context, g: g)
    }

    // MARK: - Parçalar

    private static func drawShell(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, ShopGeometry.shellLeft, ShopGeometry.shellTop,
             ShopGeometry.shellRight, ShopGeometry.shellBottom, Palette.enamel, radiusShell)
        fill(&context, g, ShopGeometry.shellLeft + 0.014, ShopGeometry.shellTop + 0.012,
             ShopGeometry.shellRight - 0.014, ShopGeometry.shellBottom - 0.012, Palette.enamelDeep, radiusPanel)
        fill(&context, g, ShopGeometry.interiorLeft - 0.008, ShopGeometry.interiorTop - 0.010,
             ShopGeometry.interiorRight + 0.008, ShopGeometry.interiorBottom + 0.008, Palette.plaster, radiusSmall)
    }

    private static func drawSign(in context: inout GraphicsContext, g: ShopGeometry, shopName: String) {
        fill(&context, g, 0.120, ShopGeometry.signTop, 0.880, ShopGeometry.signBottom, Palette.enamel, radiusSign)

        let keyline = g.rect(0.134, ShopGeometry.signTop + 0.010, 0.866, ShopGeometry.signBottom - 0.010)
        context.stroke(
            Path(roundedRect: keyline, cornerRadius: g.span(radiusPanel)),
            with: .color(Palette.plaster),
            lineWidth: g.span(0.005)
        )

        // Tabela adı sığmıyorsa küçült — dükkân adı balance.json'dan geliyor.
        let available = keyline.width * 0.88
        var pointSize = g.span(0.074)
        var resolved = context.resolve(signText(shopName, size: pointSize))
        let measured = resolved.measure(in: CGSize(width: 10_000, height: 10_000)).width
        if measured > available {
            pointSize *= available / measured
            resolved = context.resolve(signText(shopName, size: pointSize))
        }
        context.draw(resolved, at: CGPoint(x: keyline.midX, y: keyline.midY), anchor: .center)
    }

    private static func signText(_ value: String, size: CGFloat) -> Text {
        Text(value.uppercased(with: Locale(identifier: "tr_TR")))
            .font(Typography.signage(size))
            .foregroundColor(Palette.plaster)
    }

    private static func drawAwning(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, ShopGeometry.awningLeft, ShopGeometry.awningTop - 0.006,
             ShopGeometry.awningRight, ShopGeometry.awningTop + 0.005, Palette.enamelDeep, 0)

        let count = ShopGeometry.awningStripes
        let span = ShopGeometry.awningRight - ShopGeometry.awningLeft
        let scallopDepth = g.y(0.017)

        for index in 0..<count {
            let a = ShopGeometry.awningLeft + span * Double(index) / Double(count)
            let b = ShopGeometry.awningLeft + span * Double(index + 1) / Double(count)
            let color = index.isMultiple(of: 2) ? Palette.enamel : Palette.plaster

            context.fill(
                Path(g.rect(a, ShopGeometry.awningTop, b, ShopGeometry.awningBottom)),
                with: .color(color)
            )

            // fisto: alt kenarda yarım daire
            let bottom = g.y(ShopGeometry.awningBottom)
            var scallop = Path()
            scallop.move(to: CGPoint(x: g.x(a), y: bottom))
            scallop.addQuadCurve(
                to: CGPoint(x: g.x(b), y: bottom),
                control: CGPoint(x: g.x((a + b) / 2), y: bottom + scallopDepth * 2)
            )
            scallop.closeSubpath()
            context.fill(scallop, with: .color(color))
        }
    }

    private static func drawInterior(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, ShopGeometry.interiorLeft, ShopGeometry.interiorTop,
             ShopGeometry.interiorRight, ShopGeometry.interiorBottom, Palette.plaster, 0)
    }

    /// Çini lambri. Karanfil motifinin sadeleştirilmiş hâli: elmas + göbek.
    private static func drawTiles(in context: inout GraphicsContext, g: ShopGeometry) {
        let left = ShopGeometry.interiorLeft
        let right = ShopGeometry.interiorRight
        fill(&context, g, left, ShopGeometry.tileTop, right, ShopGeometry.tileBottom, Palette.tileField, 0)

        let tileWidth = (right - left) / Double(ShopGeometry.tileColumns)
        let tileHeight = (ShopGeometry.tileBottom - ShopGeometry.tileTop) / Double(ShopGeometry.tileRows)
        let hairline = g.span(0.0026)

        for row in 0..<ShopGeometry.tileRows {
            for column in 0..<ShopGeometry.tileColumns {
                let originX = left + Double(column) * tileWidth
                let originY = ShopGeometry.tileTop + Double(row) * tileHeight
                context.stroke(
                    Path(g.rect(originX, originY, originX + tileWidth, originY + tileHeight)),
                    with: .color(Palette.tileLine),
                    lineWidth: hairline
                )

                let midX = originX + tileWidth / 2
                let midY = originY + tileHeight / 2
                let arm = tileWidth * 0.26

                var diamond = Path()
                diamond.move(to: g.point(midX, midY - arm))
                diamond.addLine(to: g.point(midX + arm, midY))
                diamond.addLine(to: g.point(midX, midY + arm))
                diamond.addLine(to: g.point(midX - arm, midY))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(Palette.enamel))

                let dot = arm * 0.34
                context.fill(
                    Path(ellipseIn: g.rect(midX - dot, midY - dot, midX + dot, midY + dot)),
                    with: .color(Palette.plaster)
                )
            }
        }

        fill(&context, g, left, ShopGeometry.tileTop, right, ShopGeometry.tileTop + 0.006, Palette.pistachio, 0)
        fill(&context, g, left, ShopGeometry.tileBottom - 0.008, right, ShopGeometry.tileBottom, Palette.pistachio, 0)
    }

    private static func drawShelf(in context: inout GraphicsContext, g: ShopGeometry) {
        let shelf = ShopGeometry.shelfY
        fill(&context, g, 0.100, shelf, 0.392, shelf + 0.012, Palette.mustardDeep, radiusTiny)

        for index in 0..<4 {
            let originX = 0.118 + Double(index) * 0.068
            fill(&context, g, originX + 0.048, shelf - 0.042, originX + 0.060, shelf - 0.016, Palette.enamel, radiusChip)
            fill(&context, g, originX, shelf - 0.056, originX + 0.050, shelf, Palette.enamel, radiusSmall)
            fill(&context, g, originX + 0.005, shelf - 0.050, originX + 0.045, shelf - 0.040, Palette.plaster, radiusTiny)
        }
    }

    private static func drawChalkboard(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, 0.446, ShopGeometry.boardTop, 0.594, ShopGeometry.boardBottom, Palette.mustardDeep, radiusSmall)
        fill(&context, g, 0.456, ShopGeometry.boardTop + 0.010, 0.584, ShopGeometry.boardBottom - 0.010, Palette.slate, radiusTiny)

        for (index, width) in [0.070, 0.090, 0.056].enumerated() {
            let top = 0.326 + Double(index) * 0.030
            fill(&context, g, 0.468, top, 0.468 + width, top + 0.005, Palette.chalk, radiusTiny)
        }
    }

    private static func drawLamp(in context: inout GraphicsContext, g: ShopGeometry) {
        var cord = Path()
        cord.move(to: g.point(0.795, ShopGeometry.interiorTop))
        cord.addLine(to: g.point(0.795, 0.332))
        context.stroke(cord, with: .color(Palette.enamelDeep), lineWidth: g.span(0.005))

        var shade = Path()
        shade.move(to: g.point(0.747, 0.349))
        // Kuadratik eğri tepe noktasına uçların ortasında ulaşır:
        // tepe 0.310 olsun diye kontrol noktası 2*0.310 - 0.349 = 0.271.
        shade.addQuadCurve(to: g.point(0.843, 0.349), control: g.point(0.795, 0.271))
        shade.closeSubpath()
        context.fill(shade, with: .color(Palette.mustard))

        let bulb = g.span(0.010)
        context.fill(
            Path(ellipseIn: CGRect(
                x: g.x(0.795) - bulb, y: g.y(0.354) - bulb, width: bulb * 2, height: bulb * 2
            )),
            with: .color(Palette.mustard.opacity(0.55))
        )
    }

    private static func drawFloor(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, ShopGeometry.interiorLeft, ShopGeometry.floorY,
             ShopGeometry.interiorRight, ShopGeometry.interiorBottom, Palette.stone, 0)
        line(&context, g, ShopGeometry.interiorLeft, ShopGeometry.floorY, ShopGeometry.interiorRight)
    }

    private static func drawDoor(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, ShopGeometry.doorLeft, ShopGeometry.doorTop,
             ShopGeometry.doorRight, ShopGeometry.interiorBottom, Palette.stone, radiusSmall)
        fill(&context, g, ShopGeometry.doorLeft + 0.016, 0.452,
             ShopGeometry.doorRight - 0.016, ShopGeometry.interiorBottom, Palette.plaster, radiusTiny)

        let knob = g.span(0.009)
        context.fill(
            Path(ellipseIn: CGRect(
                x: g.x(ShopGeometry.doorLeft + 0.036) - knob, y: g.y(0.640) - knob,
                width: knob * 2, height: knob * 2
            )),
            with: .color(Palette.mustardDeep)
        )

        let plaque = g.rect(ShopGeometry.doorLeft + 0.028, 0.468, ShopGeometry.doorRight - 0.028, 0.492)
        context.fill(Path(roundedRect: plaque, cornerRadius: g.span(radiusSmall)), with: .color(Palette.enamel))
        context.draw(
            Text(L.open).font(Typography.signage(g.span(0.028))).foregroundColor(Palette.plaster),
            at: CGPoint(x: plaque.midX, y: plaque.midY),
            anchor: .center
        )
    }

    private static func drawPlant(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, 0.655, 0.748, 0.703, ShopGeometry.floorY, Palette.mustardDeep, radiusSmall)
        circle(&context, g, 0.679, 0.722, 0.029, Palette.pistachio)
        circle(&context, g, 0.663, 0.736, 0.018, Palette.pistachioDeep)
    }

    private static func drawCounter(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, ShopGeometry.counterLeft, ShopGeometry.counterTop,
             ShopGeometry.counterRight, ShopGeometry.floorY, Palette.mustard, 0)
        fill(&context, g, ShopGeometry.counterLeft - 0.006, ShopGeometry.counterTop - 0.020,
             ShopGeometry.counterRight + 0.008, ShopGeometry.counterTop, Palette.enamel, radiusSmall)

        for index in 0..<4 {
            let originX = 0.108 + Double(index) * 0.130
            fill(&context, g, originX, ShopGeometry.counterTop + 0.026,
                 originX + 0.096, ShopGeometry.floorY - 0.026, Palette.mustardDeep, radiusSmall)
        }
    }

    private static func drawMachine(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, 0.520, 0.556, 0.650, ShopGeometry.counterTop, Palette.steel, radiusPanel)
        fill(&context, g, 0.520, 0.556, 0.650, 0.582, Palette.enamelDeep, radiusSmall)
        circle(&context, g, 0.546, 0.610, 0.015, Palette.mustard)
        fill(&context, g, 0.588, 0.612, 0.624, ShopGeometry.counterTop, Palette.steelDeep, radiusTiny)
    }

    private static func drawCup(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, 0.140, 0.622, 0.186, ShopGeometry.counterTop, Palette.plaster, radiusSmall)
        fill(&context, g, 0.140, 0.622, 0.186, 0.632, Palette.mustard, radiusTiny)
    }

    private static func drawPavement(in context: inout GraphicsContext, g: ShopGeometry) {
        fill(&context, g, ShopGeometry.shellLeft, ShopGeometry.shellBottom,
             ShopGeometry.shellRight, ShopGeometry.shellBottom + 0.048, Palette.stone, radiusSmall)
        line(&context, g, ShopGeometry.shellLeft, ShopGeometry.shellBottom, ShopGeometry.shellRight)
    }

    // MARK: - Küçük yardımcılar

    private static func fill(
        _ context: inout GraphicsContext,
        _ g: ShopGeometry,
        _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double,
        _ color: Color,
        _ radius: Double
    ) {
        let rect = g.rect(x0, y0, x1, y1)
        let path = radius > 0 ? Path(roundedRect: rect, cornerRadius: g.span(radius)) : Path(rect)
        context.fill(path, with: .color(color))
    }

    private static func circle(
        _ context: inout GraphicsContext,
        _ g: ShopGeometry,
        _ centerX: Double, _ centerY: Double, _ radius: Double,
        _ color: Color
    ) {
        let r = g.span(radius)
        context.fill(
            Path(ellipseIn: CGRect(x: g.x(centerX) - r, y: g.y(centerY) - r, width: r * 2, height: r * 2)),
            with: .color(color)
        )
    }

    private static func line(
        _ context: inout GraphicsContext,
        _ g: ShopGeometry,
        _ x0: Double, _ y: Double, _ x1: Double
    ) {
        var path = Path()
        path.move(to: g.point(x0, y))
        path.addLine(to: g.point(x1, y))
        context.stroke(path, with: .color(Palette.shadow), lineWidth: g.span(0.005))
    }
}
