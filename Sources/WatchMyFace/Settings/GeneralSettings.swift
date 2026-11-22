import AVFoundation
import SwiftUI

struct GeneralSettings: View {
    let model: AppModel
    @State private var opensAtLogin = LaunchAtLogin.isEnabled
    @State private var cameras: [AVCaptureDevice] = []

    var body: some View {
        @Bindable var preferences = model.preferences
        Form {
            Section {
                Toggle("Open at login", isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) { _, enabled in LaunchAtLogin.set(enabled) }
            }
            Section("Look for my face") {
                Toggle("When my Mac wakes up", isOn: $preferences.scanOnWake)
                Toggle("As soon as the screen locks", isOn: $preferences.scanOnLock)
                Text("Missed it? Move the pointer onto the notch to look again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Camera") {
                Picker("Camera", selection: $preferences.cameraID) {
                    Text("Built-in").tag(String?.none)
                    ForEach(cameras, id: \.uniqueID) { camera in
                        Text(camera.localizedName).tag(Optional(camera.uniqueID))
                    }
                }
            }
            Section("Feedback") {
                Toggle("Trackpad taps when the notch opens and unlocks", isOn: $preferences.hapticsEnabled)
            }
        }
        .formStyle(.grouped)
        .onAppear { cameras = CameraSession.availableCameras() }
    }
}
