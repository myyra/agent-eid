import SwiftUI

struct MenuBarView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let model: ReaderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.status.error {
                Text(error)
            } else if model.status.readers.isEmpty {
                Label(.menuReadersConnectTitle, systemSymbol: .reader)
                    .font(.headline)
                    .padding(.vertical, 8)
            } else {
                ForEach(model.status.readers) { reader in
                    MenuBarReaderView(reader: reader, model: model)
                }
            }
            Divider()
            MenuBarActions()
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
        .background {
            if contrast == .increased || reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            }
        }
        .onChange(of: model.menuBarStatus) { _, status in
            AccessibilityNotification.Announcement(status).post()
        }
    }
}

#Preview { MenuBarView(model: ReaderModel()) }

#Preview("Light appearance") {
    MenuBarView(model: ReaderModel())
        .preferredColorScheme(.light)
}

#Preview("Dark appearance") {
    MenuBarView(model: ReaderModel())
        .preferredColorScheme(.dark)
}
