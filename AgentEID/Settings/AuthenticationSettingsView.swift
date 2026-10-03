import SwiftUI

struct AuthenticationSettingsView: View {
    @State private var model = AuthenticationSettingsModel()

    var body: some View {
        @Bindable var model = model
        Form {
            Picker(.settingsAuthenticationMethodLabel, selection: $model.mode) {
                ForEach(PINMode.allCases) { mode in
                    Text(mode.localizedDescription).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .disabled(!model.loaded)
            if model.settings.savedCardID != nil {
                HStack {
                    Button(.settingsAuthenticationSavedPinChangeTitle) { model.isSettingUpPIN = true }
                    Button(.settingsAuthenticationSavedPinForgetTitle, role: .destructive, action: model.forgetPIN)
                }
            }
            if model.busy { ProgressView(.settingsAuthenticationUpdateProgress).controlSize(.small) }
            if let error = model.error { Text(error) }
            if !model.loaded, model.error != nil {
                Button(.settingsAuthenticationLoadRetryTitle) { model.loadAttempt += 1 }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 360)
        .disabled(model.busy)
        .sheet(isPresented: $model.isSettingUpPIN) {
            PINSetupView(onSaved: model.didSavePIN)
        }
        .task(id: model.loadAttempt) { await model.load() }
        .onChange(of: model.error) { _, error in
            if let error { AccessibilityNotification.Announcement(error).post() }
        }
    }
}
