import SwiftUI

/// Kısa seansın yakıtı: bir ya da iki dokunuşluk bir karar.
///
/// Metin kısa ve atlanabilir — mizah zorunlu okuma hâline gelmemeli.
/// "Şimdi değil" her zaman açık.
struct EventCardView: View {

    let event: BalanceConfig.EventSpec
    /// Bir seçeneğin anında getirisi/gideri — mevcut üretime göre hesaplanmış.
    let instantAmount: (BalanceConfig.EventChoice) -> Double
    let onChoose: (String) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 12) {
                Text(L.eventTitle(event.id))
                    .font(Typography.display(26))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L.eventBody(event.id))
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(event.choices) { choice in
                    Button {
                        onChoose(choice.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.eventChoice(event.id, choice.id))
                                .font(Typography.display(17))
                                .foregroundStyle(Palette.ink)
                            Text(effect(of: choice))
                                .font(Typography.label(14))
                                .foregroundStyle(tint(of: choice))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Palette.plaster, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Palette.enamel.opacity(0.45), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onDismiss) {
                    Text(L.eventDismiss)
                        .font(Typography.label(15))
                        .foregroundStyle(Palette.inkFaint)
                        .frame(maxWidth: .infinity, minHeight: 36)
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

    /// Seçeneğin ne yapacağını tek satırda söyle. Buton ne yapacağını söyler.
    private func effect(of choice: BalanceConfig.EventChoice) -> String {
        var parts: [String] = []
        if choice.durationSeconds > 0, choice.multiplier != 1 {
            parts.append(L.equipmentOutput(multiplierText(choice.multiplier)))
            parts.append(L.eventLasting(DurationText.text(choice.durationSeconds)))
        }
        if choice.instantSeconds != 0 {
            parts.append(L.eventNow(Money.text(instantAmount(choice))))
        }
        return parts.joined(separator: " · ")
    }

    private func tint(of choice: BalanceConfig.EventChoice) -> Color {
        let isCost = choice.instantSeconds < 0 || (choice.durationSeconds > 0 && choice.multiplier < 1)
        return isCost ? Palette.inkSoft : Palette.pistachio
    }

    private func multiplierText(_ value: Double) -> String {
        value.formatted(.number.locale(Money.current.numberLocale).precision(.fractionLength(0...2)))
    }
}
