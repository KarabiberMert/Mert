import SwiftUI

/// Katın demirbaşları. Bina her katta aynı — kabuk, tezgâh, fayans, kadro
/// ortak. Katı birbirinden ayıran şey duvardaki ve tezgâhtaki iki parça.
///
/// Yeni bir sektör eklemek buraya iki çizim eklemekten ibaret olmalı.
enum SectorFittings {

    private static let radiusTiny = 0.018
    private static let radiusSmall = 0.035

    // MARK: - Duvar demirbaşı

    static func drawWallFitting(
        in context: inout GraphicsContext,
        unit: UnitGeometry,
        palette: FloorPalette,
        sector: String,
        detail: FloorDetail
    ) {
        switch sector {
        case "bakery":
            drawDeckOven(in: &context, unit: unit, palette: palette, detail: detail)
        default:
            drawCupShelf(in: &context, unit: unit, palette: palette, detail: detail)
        }
    }

    /// Kahve: duvarda fincan rafı.
    private static func drawCupShelf(
        in context: inout GraphicsContext,
        unit: UnitGeometry,
        palette: FloorPalette,
        detail: FloorDetail
    ) {
        let shelfY = 0.405
        context.fill(
            Path(unit.box(UnitGeometry.fittingLeft, shelfY, UnitGeometry.fittingRight, shelfY + 0.030)),
            with: .color(palette.counterShade)
        )
        guard detail.showsFineDetail else { return }

        let span = UnitGeometry.fittingRight - UnitGeometry.fittingLeft
        for index in 0..<2 {
            let a = UnitGeometry.fittingLeft + span * (Double(index) + 0.10) / 2
            let b = UnitGeometry.fittingLeft + span * (Double(index) + 0.80) / 2
            context.fill(
                Path(roundedRect: unit.box(a, shelfY - 0.105, b, shelfY), cornerRadius: unit.h(radiusTiny)),
                with: .color(palette.counterTop)
            )
            context.fill(
                Path(unit.box(a, shelfY - 0.095, b, shelfY - 0.070)),
                with: .color(palette.wall)
            )
        }
    }

    /// Fırın: duvarda üç katlı taş fırın.
    private static func drawDeckOven(
        in context: inout GraphicsContext,
        unit: UnitGeometry,
        palette: FloorPalette,
        detail: FloorDetail
    ) {
        let body = unit.box(UnitGeometry.fittingLeft, 0.355, UnitGeometry.fittingRight, FloorGeometry.counterTop)
        context.fill(
            Path(roundedRect: body, cornerRadius: unit.h(radiusSmall)),
            with: .color(palette.fixture)
        )
        guard detail.showsFineDetail else { return }

        let span = UnitGeometry.fittingRight - UnitGeometry.fittingLeft
        for deck in 0..<3 {
            let top = 0.385 + Double(deck) * 0.075
            context.fill(
                Path(roundedRect: unit.box(
                    UnitGeometry.fittingLeft + span * 0.12, top,
                    UnitGeometry.fittingRight - span * 0.12, top + 0.048
                ), cornerRadius: unit.h(radiusTiny)),
                with: .color(palette.fixtureDeep)
            )
        }
        // Ateşin turuncusu değil, hardalın kendisi — para ile aynı vurgu ailesi.
        context.fill(
            Path(unit.box(
                UnitGeometry.fittingLeft + span * 0.16, 0.397,
                UnitGeometry.fittingRight - span * 0.16, 0.414
            )),
            with: .color(Palette.mustard.opacity(0.75))
        )
    }

    // MARK: - Tezgâh demirbaşı

    static func drawCounterFitting(
        in context: inout GraphicsContext,
        unit: UnitGeometry,
        palette: FloorPalette,
        sector: String,
        detail: FloorDetail
    ) {
        switch sector {
        case "bakery":
            drawLoaves(in: &context, unit: unit, palette: palette, detail: detail)
        default:
            drawEspressoMachine(in: &context, unit: unit, palette: palette, detail: detail)
        }
    }

    /// Kahve: tezgâhın sağ ucunda espresso makinesi.
    private static func drawEspressoMachine(
        in context: inout GraphicsContext,
        unit: UnitGeometry,
        palette: FloorPalette,
        detail: FloorDetail
    ) {
        let body = unit.box(0.50, 0.470, 0.74, FloorGeometry.counterTop)
        context.fill(
            Path(roundedRect: body, cornerRadius: unit.h(radiusSmall)),
            with: .color(palette.fixture)
        )
        context.fill(
            Path(roundedRect: unit.box(0.50, 0.470, 0.74, 0.512), cornerRadius: unit.h(radiusTiny)),
            with: .color(palette.counterTop)
        )
        guard detail.showsFineDetail else { return }

        let dial = unit.h(0.030)
        context.fill(
            Path(ellipseIn: CGRect(
                x: unit.x(0.555) - dial, y: unit.y(0.560) - dial, width: dial * 2, height: dial * 2
            )),
            with: .color(Palette.mustard)
        )
        context.fill(
            Path(roundedRect: unit.box(0.655, 0.560, 0.715, FloorGeometry.counterTop), cornerRadius: unit.h(radiusTiny)),
            with: .color(palette.fixtureDeep)
        )
    }

    /// Fırın: tezgâhta ekmek sırası.
    private static func drawLoaves(
        in context: inout GraphicsContext,
        unit: UnitGeometry,
        palette: FloorPalette,
        detail: FloorDetail
    ) {
        let count = detail.showsFineDetail ? 3 : 2
        let left = 0.46
        let right = 0.74
        let span = (right - left) / Double(count)

        for index in 0..<count {
            let a = left + span * Double(index) + span * 0.10
            let b = left + span * Double(index) + span * 0.90
            let loaf = unit.box(a, 0.535, b, FloorGeometry.counterTop)
            context.fill(
                Path(roundedRect: loaf, cornerRadius: unit.h(0.045)),
                with: .color(Palette.mustardDeep)
            )
            guard detail.showsFineDetail else { continue }
            // Ekmeğin sırtındaki kesik.
            context.fill(
                Path(unit.box(a + (b - a) * 0.25, 0.552, b - (b - a) * 0.25, 0.566)),
                with: .color(Palette.mustard)
            )
        }
    }
}
