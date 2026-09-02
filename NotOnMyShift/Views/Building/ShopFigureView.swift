import SwiftUI

/// Kadrodaki bir kişi — yandan, sade siluet.
///
/// Tezgâhın arkasındakiler bel hizasından kesilir (tezgâh önlerinde çizilir);
/// salonda duran patronun bacakları görünür, yoksa sarı bir sütun gibi okunuyor.
struct ShopFigureView: View {

    let width: CGFloat
    let bodyHeight: CGFloat
    let headRadius: CGFloat
    let apron: Color
    let skin: Color
    /// Tezgâhın önünde, salonda mı duruyor?
    let standing: Bool

    /// Kafanın üstünden ayak ucuna kadar.
    var totalHeight: CGFloat { bodyHeight + headRadius * 2.2 }

    var body: some View {
        Canvas { context, size in
            let bodyTop = headRadius * 2.2
            let bottom = size.height
            let hem = standing ? bottom - bodyHeight * 0.26 : bottom
            let corner = width * 0.26

            if standing {
                let legTop = hem - bodyHeight * 0.03
                let legWidth = width * 0.36
                for originX in [width * 0.08, width * 0.56] {
                    context.fill(
                        Path(
                            roundedRect: CGRect(x: originX, y: legTop, width: legWidth, height: bottom - legTop),
                            cornerRadius: corner * 0.5
                        ),
                        with: .color(Palette.enamelDeep)
                    )
                }
            }

            // önlük
            context.fill(
                Path(roundedRect: CGRect(x: 0, y: bodyTop, width: width, height: hem - bodyTop), cornerRadius: corner),
                with: .color(apron)
            )
            // gömlek / omuz
            context.fill(
                Path(roundedRect: CGRect(x: 0, y: bodyTop, width: width, height: bodyHeight * 0.19), cornerRadius: corner),
                with: .color(Palette.enamel)
            )
            // boyun
            context.fill(
                Path(CGRect(x: width * 0.34, y: bodyTop - headRadius * 0.45, width: width * 0.32, height: headRadius * 0.85)),
                with: .color(skin)
            )
            // önlük bağı
            context.fill(
                Path(CGRect(x: 0, y: bodyTop + bodyHeight * 0.27, width: width, height: bodyHeight * 0.042)),
                with: .color(Palette.plaster)
            )
            // baş
            context.fill(
                Path(ellipseIn: CGRect(
                    x: width / 2 - headRadius,
                    y: bodyTop - headRadius * 2.2,
                    width: headRadius * 2,
                    height: headRadius * 2
                )),
                with: .color(skin)
            )
        }
        .frame(width: width, height: totalHeight)
        .accessibilityHidden(true)
    }
}
