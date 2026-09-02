import SwiftUI

/// "Sen yokken şunlar oldu." Kısa seans oyuncusunun geri dönüş sebebi bu ekran.
struct OfflineReportView: View {

    let report: OfflineReport
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.welcomeBack)
                .font(Typography.display(30))
                .foregroundStyle(Palette.ink)

            Text(L.youWereAway(DurationText.text(report.awaySeconds)))
                .font(Typography.label(16))
                .foregroundStyle(Palette.inkSoft)

            Text(Money.text(report.earned))
                .font(Typography.money(52))
                .foregroundStyle(Palette.mustardDeep)
                .padding(.vertical, 2)

            if report.didFillWarehouse {
                Text(L.warehouseFilled)
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.enamel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Text(L.continueAction)
                    .font(Typography.display(18))
                    .foregroundStyle(Palette.plaster)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Palette.enamel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.wall.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
