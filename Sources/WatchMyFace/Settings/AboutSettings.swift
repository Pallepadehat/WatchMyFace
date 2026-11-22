import SwiftUI

struct AboutSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("WatchMyFace").font(.title.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Face unlock for your Mac, in the notch. Free and open source.")
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/Pallepadehat/WatchMyFace")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/Pallepadehat/WatchMyFace/issues/new/choose")!)
            }
            Text("Notch animation ideas from glance by Jonathan Zhou. Lock screen window technique from SkyLightWindow by Lakr233. Both MIT.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
