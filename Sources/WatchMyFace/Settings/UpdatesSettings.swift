import SwiftUI

struct UpdatesSettings: View {
    @Bindable var updater: Updater

    var body: some View {
        Form {
            Section {
                Toggle("Check for updates automatically", isOn: $updater.checksAutomatically)
                Toggle("Download and install updates automatically", isOn: $updater.downloadsAutomatically)
                    .disabled(!updater.checksAutomatically)
            }
            Section {
                LabeledContent("Version", value: updater.currentVersion)
                HStack {
                    Text(stateText).foregroundStyle(.secondary)
                    Spacer()
                    if let version = updater.availableVersion {
                        Button("Install \(version)…") { updater.installUpdate() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Check Now") { updater.checkNow() }
                            .disabled(!updater.canCheckForUpdates || updater.checkState == .checking)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var stateText: String {
        switch updater.checkState {
        case .checking: return "Checking…"
        case .upToDate: return "You're up to date."
        case .available(let version): return "Version \(version) is available."
        case .failed(let message): return message
        case .idle:
            guard let lastCheck = updater.lastCheck else { return "Not checked yet." }
            return "Last checked \(lastCheck.formatted(.relative(presentation: .named)))."
        }
    }
}
