import SwiftUI

/// Katın satışa ne kadar yaklaştığı.
///
/// Satış bir sürpriz olmamalı: oyuncu ilk günden neyin peşinde olduğunu
/// görsün. Çubuk dolduğunda alıcı kapıya gelir — dolmadan hiçbir metin
/// "yapamazsın" demez, sadece "daha büyüyor" der.
struct MaturityBarView: View {

    /// 0..1. Kadro, ekipman ve hücreler eşit ağırlıklı.
    let progress: Double

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L.sellSector)
                    .font(Typography.display(15))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(L.sectorGrowing(Percent.text(clamped)))
                    .font(Typography.money(14))
                    .foregroundStyle(Palette.inkSoft)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.stone)
                    Rectangle()
                        .fill(Palette.pistachio)
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L.sellSector), \(L.sectorGrowing(Percent.text(clamped)))")
    }
}
