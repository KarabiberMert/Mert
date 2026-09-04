import SwiftUI

/// Tek seferlik "Reklamsız" alımı.
///
/// Rapor §8'in kritik detayı burada metne de dönüşüyor: satın alan oyuncu
/// reklam ödüllerini zaten alır. Para veren, reklam izleyenden yavaş kalmaz.
struct SupportView: View {

    @Bindable var store: GameStore
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.support)
                .font(Typography.display(30))
                .foregroundStyle(Palette.ink)

            Text(L.supportBody)
                .font(.system(.subheadline))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if store.hasRemovedAds {
                Text(L.supportOwned)
                    .font(Typography.label(15))
                    .foregroundStyle(Palette.pistachio)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    store.buyRemoveAds()
                } label: {
                    HStack {
                        Text(L.supportBuy)
                        Spacer(minLength: 12)
                        Text(store.purchases.priceText ?? L.priceUnavailable)
                            .foregroundStyle(Palette.mustard)
                    }
                    .font(Typography.display(18))
                    .foregroundStyle(Palette.plaster)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Palette.enamel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(store.purchases.isBusy)
                .opacity(store.purchases.isBusy ? 0.6 : 1)

                // App Review geri yüklemeyi şart koşuyor; ayrıca cihaz
                // değiştiren oyuncunun tek yolu bu.
                Button(action: { store.restorePurchases() }) {
                    Text(L.supportRestore)
                        .font(Typography.label(15))
                        .foregroundStyle(Palette.enamel)
                }
                .buttonStyle(.plain)
                .disabled(store.purchases.isBusy)
            }

            if let failure = store.purchases.failureText {
                Text(failure)
                    .font(Typography.label(13))
                    .foregroundStyle(Palette.mustardDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onClose) {
                Text(L.supportClose)
                    .font(Typography.display(17))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 46)
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
