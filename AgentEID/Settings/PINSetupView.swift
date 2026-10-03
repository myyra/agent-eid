import SwiftUI

/// The active method changes only after PIN verification and a successful card-bound save.
struct PINSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var error: String?
    @State private var isSaving = false
    @FocusState private var pinFocused: Bool
    let onSaved: (PINSettings) -> Void

    private var canSave: Bool {
        (try? SavedPIN.validate(Data(pin.utf8))) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(.settingsAuthenticationMethodsSavedPinTitle).font(.headline).accessibilityAddTraits(.isHeader)
            Text(.settingsPinSetupDescription)
            SecureField(.settingsPinSetupInputLabel, text: $pin)
                .accessibilityLabel(.settingsPinSetupInputLabel)
                .focused($pinFocused)
                .onSubmit { if canSave { save() } }
            Text(.settingsPinSetupInputHint).font(.caption)
            if let error { Text(error) }
            if isSaving { ProgressView(.settingsPinSetupSaveProgress).controlSize(.small) }
            HStack {
                Spacer()
                Button(.commonActionsCancelTitle, role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(.settingsPinSetupSaveTitle, action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 360)
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
        .onAppear { pinFocused = true }
        .onDisappear { pin = "" }
        .onChange(of: error) { _, error in
            if let error {
                pinFocused = true
                AccessibilityNotification.Announcement(error).post()
            }
        }
    }

    private func save() {
        guard canSave, !isSaving else { return }
        let enteredPIN = pin
        pin = ""
        error = nil
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let cardID = try await ReaderService.verifyPIN(enteredPIN)
                try await PINProvider.savePIN(enteredPIN, cardID: cardID)
                let settings = try await PINProvider.loadSettings()
                onSaved(settings)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview { PINSetupView { _ in } }
