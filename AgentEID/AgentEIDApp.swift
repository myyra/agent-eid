import SwiftUI

@main
struct AgentEIDApp: App {
    @State private var model = ReaderModel()
    @State private var isInserted = true

    var body: some Scene {
        MenuBarExtra(isInserted: $isInserted) {
            MenuBarView(model: model)
        } label: {
            Label(.appDisplayName, systemSymbol: model.menuBarSymbol)
                .accessibilityValue(model.menuBarStatus)
                .task { await model.monitor() }
        }
        .menuBarExtraStyle(.window)
        Settings { AuthenticationSettingsView() }
    }
}
