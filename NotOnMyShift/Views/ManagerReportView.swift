import SwiftUI

/// Müdürlerin sen yokken yaptıkları.
///
/// `MomentBannerView` ile aynı emaye dili, ama tek gövde yerine bir liste:
/// burada anlatılacak şey bir an değil, bir vardiya. Rapor bir ödül metnidir —
/// oyuncuya "senin kurduğun süreç çalıştı" der, hiçbir satırı kayıp anlatmaz.
struct ManagerReportView: View {

    let actions: [GameEngine.AutomatedAction]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    /// Liste uzasa da pano büyümesin; gerisi kaydırılır.
    private let listHeight: CGFloat = 190

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 14) {
                Text(L.managerReportTitle)
                    .font(Typography.display(26))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(actions.enumerated()), id: \.offset) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Rectangle()
                                    .fill(Palette.pistachio)
                                    .frame(width: 3, height: 14)
                                Text(line(for: entry.element))
                                    .font(Typography.label(15))
                                    .foregroundStyle(Palette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: listHeight)
                .scrollBounceBehavior(.basedOnSize)

                Button(action: onDismiss) {
                    Text(L.managerReportAction)
                        .font(Typography.display(18))
                        .foregroundStyle(Palette.plaster)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Palette.enamel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 340, alignment: .leading)
            .background(Palette.wall, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.mustard, lineWidth: 2)
            }
            .padding(.horizontal, 24)
            .scaleEffect(settled ? 1 : 0.92)
            .opacity(settled ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { settled = true }
        }
    }

    /// Kimlikleri dile çevirir. Kayıtta kimlik durur, metin dilden gelir.
    private func line(for action: GameEngine.AutomatedAction) -> String {
        let sector = L.sectorName(action.sectorID)
        switch action.rule {
        case "hire":
            return L.managerHiredLine(sector, L.staffName(action.detail))
        case "equip":
            return L.managerUpgradedLine(sector, L.equipmentName(action.detail))
        case "branch":
            return L.managerOpenedLine(sector, Int(action.detail) ?? 0)
        case "event":
            let parts = action.detail.split(separator: ".", maxSplits: 1)
            guard let eventID = parts.first, let choiceID = parts.last, parts.count == 2 else {
                return L.managerDidSomething
            }
            return L.managerHandledLine(L.eventTitle(String(eventID)), L.eventChoice(String(eventID), String(choiceID)))
        default:
            return L.managerDidSomething
        }
    }
}
