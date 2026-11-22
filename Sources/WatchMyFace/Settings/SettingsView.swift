import SwiftUI

/// Settings: a tab per topic.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings(model: model) }
            Tab("Faces", systemImage: "faceid") { FacesSettings(model: model) }
            Tab("Security", systemImage: "lock.shield") { SecuritySettings(model: model) }
            Tab("Updates", systemImage: "arrow.down.circle") { UpdatesSettings(updater: model.updater) }
            Tab("About", systemImage: "info.circle") { AboutSettings() }
        }
        .frame(width: 520)
        .frame(minHeight: 380)
    }
}
