import FaceKit
import SwiftUI

struct SecuritySettings: View {
    let model: AppModel
    @State private var confirmingForget = false
    @State private var error: String?

    private static let inactivityChoices = [15, 30, 45, 60, 120, 240]

    var body: some View {
        @Bindable var preferences = model.preferences
        Form {
            Section {
                Picker("Match", selection: $preferences.sensitivity) {
                    Text("Relaxed").tag(MatchSensitivity.relaxed)
                    Text("Balanced").tag(MatchSensitivity.balanced)
                    Text("Strict").tag(MatchSensitivity.strict)
                }
                .pickerStyle(.segmented)
                Toggle("Ask for a blink", isOn: $preferences.requireBlink)
            } header: {
                Text("Recognition")
            } footer: {
                Text("Strict needs a clear, straight look; Relaxed unlocks more readily, for lookalikes too. A blink keeps out a printed photo, though not a video.")
            }

            Section {
                Picker("Ask for Touch ID after the Mac's been locked for", selection: $preferences.lockedInactivityMinutes) {
                    ForEach(Self.inactivityChoices, id: \.self) { minutes in
                        Text(Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))).tag(minutes)
                    }
                }
            } header: {
                Text("Guardrails")
            } footer: {
                Text("Face unlock also stops after five missed scans in a row, and two days after Touch ID last turned it on. Then you type your password once and use Touch ID to turn it back on, like face unlock on iPhone.")
            }

            Section {
                LabeledContent("Password") {
                    Text(model.vault.hasStoredPassword ? "Saved in your keychain" : "Not saved")
                        .foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Forget Password…", role: .destructive) { confirmingForget = true }
                    .disabled(!model.vault.hasStoredPassword)
            } header: {
                Text("Login password")
            } footer: {
                Text("Saved in your login keychain, readable only by WatchMyFace, and loaded into memory only after Touch ID. Changed your password? Forget it here and set up again.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.lockedInactivityMinutes) { model.unlock.disarm() }
        .confirmationDialog("Forget your password?", isPresented: $confirmingForget) {
            Button("Forget Password", role: .destructive) {
                do {
                    try model.vault.forget()
                    model.unlock.disarm()
                } catch {
                    self.error = error.localizedDescription
                }
            }
        } message: {
            Text("Face unlock stops until you set it up again.")
        }
    }
}
