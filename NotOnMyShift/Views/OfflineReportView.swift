import SwiftUI

/// "Sen yokken şunlar oldu." Kısa seans oyuncusunun geri dönüş sebebi bu ekran.
struct OfflineReportView: View {

    let report: OfflineReport
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L.welcomeBack)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.ink)

            Text("\(DurationText.text(report.awaySeconds)) uzaktaydın.")
                .font(.body)
                .foregroundStyle(Palette.inkSoft)

            Text(Money.text(report.earned))
                .font(.system(size: 40, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.mustard)

            if report.didFillWarehouse {
                Text(L.warehouseFull)
                    .font(.subheadline)
                    .foregroundStyle(Palette.enamel)
            }

            Spacer()

            Button(L.continueAction) {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.wall.ignoresSafeArea())
        .tint(Palette.enamel)
        .presentationDetents([.medium])
    }
}
