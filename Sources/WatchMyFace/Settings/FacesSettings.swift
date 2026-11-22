import FaceKit
import SwiftUI

struct FacesSettings: View {
    let model: AppModel
    @State private var confirmingRemoveAll = false

    private var embedder: any FaceEmbedder { model.unlock.embedder }

    var body: some View {
        Form {
            Section {
                if model.faces.profiles.isEmpty {
                    ContentUnavailableView(
                        "No faces yet", systemImage: "faceid", description: Text("Set up face unlock to scan your face."))
                }
                ForEach(model.faces.profiles) { profile in
                    ProfileRow(profile: profile, isCompatible: profile.isCompatible(with: embedder.modelIdentifier)) { updated in
                        model.faces.update(updated)
                    } remove: {
                        model.faces.remove(profile.id)
                    }
                }
            } header: {
                Text("Appearances")
            } footer: {
                Text("Add another appearance for glasses, a beard or different light, or for someone else you trust with this Mac.")
            }

            Section {
                HStack {
                    Button(model.faces.hasProfiles ? "Add an Appearance…" : "Set Up Face Unlock…") {
                        model.showSetup(addingAppearance: model.faces.hasProfiles && model.vault.hasStoredPassword)
                    }
                    Spacer()
                    Button("Try Face Unlock") { model.unlock.tryFaceUnlock() }
                        .disabled(!model.faces.hasProfiles)
                }
            }

            Section("Recognition") {
                LabeledContent("Face model", value: embedder.displayName)
                if let result = model.unlock.lastResult {
                    LabeledContent("Last scan", value: result)
                }
            }

            Section {
                Button("Remove All Faces…", role: .destructive) { confirmingRemoveAll = true }
                    .disabled(!model.faces.hasProfiles)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Remove all faces?", isPresented: $confirmingRemoveAll) {
            Button("Remove All", role: .destructive) { model.faces.removeAll() }
        } message: {
            Text("Face unlock stops until you scan your face again.")
        }
    }
}

private struct ProfileRow: View {
    let profile: FaceProfile
    let isCompatible: Bool
    let update: (FaceProfile) -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title)
                .foregroundStyle(profile.isEnabled ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                Group {
                    if isCompatible {
                        Text("Added \(profile.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(profile.samples.count) samples")
                    } else {
                        Text("Made with another face model. Scan it again to use it.").foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(
                "Use", isOn: Binding(get: { profile.isEnabled }, set: { var copy = profile; copy.isEnabled = $0; update(copy) })
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            Button(role: .destructive, action: remove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove \(profile.name)")
        }
    }
}
