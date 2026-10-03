import SwiftUI

struct MenuBarActions: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack {
            Button {
                NSApp.activate()
                openSettings()
            } label: {
                Label(.menuActionsSettingsTitle, systemSymbol: .settings)
            }
            Spacer()
            Button(.menuActionsQuitTitle) { NSApp.terminate(nil) }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
