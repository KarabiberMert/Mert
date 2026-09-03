import SwiftUI

/// Binanın tepesindeki yönetim katı.
///
/// Sektör katı değil: kimse tezgâh başında durmaz, hücre yoktur. Bu yüzden
/// alçak, sakin ve tamamen kurumsal paletle çizilir — oyuncu yukarı baktığında
/// binanın artık kendi kendini yönettiğini görür.
struct RoofBandView: View {

    /// Binanın planlanan kat sayısı. Palet en soğuk uca buradan gider.
    let plannedFloors: Int

    private var palette: FloorPalette {
        FloorPalette(floor: max(1, plannedFloors), plannedFloors: plannedFloors)
    }

    var body: some View {
        Canvas { context, size in
            let band = FloorGeometry(rect: CGRect(origin: .zero, size: size))
            draw(in: &context, band: band)
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.roofTitle)
    }

    private func draw(in context: inout GraphicsContext, band: FloorGeometry) {
        let tone = palette

        // Gövde
        context.fill(
            Path(band.box(
                RoofGeometry.interiorLeft, RoofGeometry.capBottom,
                RoofGeometry.interiorRight, RoofGeometry.baseBottom
            )),
            with: .color(tone.wall)
        )

        // Saçak ve döşeme — binanın tepesini kapatır.
        context.fill(
            Path(band.box(0, RoofGeometry.capTop, 1, RoofGeometry.capBottom)),
            with: .color(tone.frame)
        )
        context.fill(
            Path(band.box(0, RoofGeometry.baseTop, 1, RoofGeometry.baseBottom)),
            with: .color(tone.frameDeep)
        )

        drawGlass(in: &context, band: band, palette: tone)
        drawPlate(in: &context, band: band, palette: tone)
    }

    /// Şerit cam. Bölmeler eşit — kurumsal katman burada tekrarla anlatılır.
    private func drawGlass(in context: inout GraphicsContext, band: FloorGeometry, palette: FloorPalette) {
        let strip = band.box(
            RoofGeometry.glassLeft, RoofGeometry.glassTop,
            RoofGeometry.glassRight, RoofGeometry.glassBottom
        )
        context.fill(Path(strip), with: .color(palette.tileField))

        let panes = max(1, RoofGeometry.panes)
        let step = strip.width / CGFloat(panes)
        for index in 1..<panes {
            let x = strip.minX + step * CGFloat(index)
            context.fill(
                Path(CGRect(x: x - band.h(0.010), y: strip.minY, width: band.h(0.020), height: strip.height)),
                with: .color(palette.frame)
            )
        }
        context.stroke(Path(strip), with: .color(palette.frame), lineWidth: band.h(0.026))
    }

    /// Kapı levhası. Tabela gibi büyük harflidir — arayüz değil, binanın parçası.
    private func drawPlate(in context: inout GraphicsContext, band: FloorGeometry, palette: FloorPalette) {
        let plate = band.box(
            RoofGeometry.plateLeft, RoofGeometry.plateTop,
            RoofGeometry.plateRight, RoofGeometry.plateBottom
        )
        context.fill(
            Path(roundedRect: plate, cornerRadius: band.h(0.030)),
            with: .color(palette.sign)
        )

        let keyline = plate.insetBy(dx: band.h(0.030), dy: band.h(0.030))
        guard keyline.width > 0, keyline.height > 0 else { return }
        context.stroke(
            Path(roundedRect: keyline, cornerRadius: band.h(0.018)),
            with: .color(Palette.mustard),
            lineWidth: band.h(0.018)
        )

        // Metin dil dosyasından göründüğü hâliyle gelir; kod büyük harfe çevirmez.
        let available = keyline.width * 0.90
        var size = band.h(0.180)
        var resolved = context.resolve(
            Text(L.roofSign)
                .font(Typography.signage(size))
                .foregroundColor(palette.signText)
        )
        let measured = resolved.measure(in: CGSize(width: 10_000, height: 10_000)).width
        if measured > available, measured > 0 {
            size *= available / measured
            resolved = context.resolve(
                Text(L.roofSign)
                    .font(Typography.signage(size))
                    .foregroundColor(palette.signText)
            )
        }
        context.draw(resolved, at: CGPoint(x: keyline.midX, y: keyline.midY), anchor: .center)
    }
}
