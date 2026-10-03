import SwiftUI

struct MenuBarReaderView: View {
    let reader: ReaderSnapshot
    let model: ReaderModel

    var body: some View {
        let holderName = model.holderName(for: reader)
        let status = model.localizedDescription(for: reader)
        HStack(alignment: .top, spacing: 12) {
            Image(systemSymbol: reader.hasCard ? .identityCard : .reader)
                .font(.system(size: 26))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(model.isReady(for: reader) ? Color.accentColor : .secondary)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Group {
                    if let holderName {
                        Text(holderName)
                    } else {
                        Text(status)
                    }
                }
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                if holderName != nil {
                    Label {
                        Text(status)
                    } icon: {
                        Image(systemSymbol: .statusDot)
                            .font(.system(size: 5))
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                }
                Text(reader.name).font(.caption)
                if let error = model.error(for: reader) {
                    Text(error).font(.caption)
                    Button(.menuCardPrepareRetryTitle) { model.retry(reader) }
                }
            }
        }
    }
}
