import FaceKit
import SwiftUI

struct FacesSettings: View {
    let model: AppModel
    @State private var confirmingRemoveAll = false

    private var embedder: any FaceEmbedder { model.unlock.embedder }
    private var allowed: [FaceProfile] { model.faces.profiles.filter { $0.role == .allowed } }
    private var blocked: [FaceProfile] { model.faces.profiles.filter { $0.role == .blocked } }

    var body: some View {
        Form {
            Section {
                if allowed.isEmpty {
                    ContentUnavailableView(
                        "No faces yet", systemImage: "faceid", description: Text("Set up face unlock to scan your face."))
                }
                ForEach(allowed) { profile in row(for: profile) }
            } header: {
                Text("Appearances")
            } footer: {
                Text("Add another appearance for glasses, a beard or different light, or for someone else you trust with this Mac.")
            }

            Section {
                HStack {
                    Button(model.faces.hasProfiles ? "Add an Appearance…" : "Set Up Face Unlock…") {
                        model.showSetup(model.faces.hasProfiles && model.vault.hasStoredPassword ? .addAppearance : .setUp)
                    }
                    Spacer()
                    Button("Try Face Unlock") { model.unlock.tryFaceUnlock() }
                        .disabled(!model.faces.hasProfiles)
                }
            }

            Section {
                ForEach(blocked) { profile in row(for: profile) }
                Button("Block Someone…") { model.showSetup(.blockSomeone) }
                    .disabled(!model.faces.hasProfiles)
            } header: {
                Text("Blocked")
            } footer: {
                Text(
                    "Someone who looks like you, such as a parent or a sibling? Scan their face here. Anyone who looks more like them than like you is turned away."
                )
            }

            Section("Recognition") {
                LabeledContent("Face model", value: embedder.displayName)
                if let result = model.unlock.lastResult {
                    LabeledContent("Last scan", value: result)
                }
            }

            Section {
                Button("Remove All Faces…", role: .destructive) { confirmingRemoveAll = true }
                    .disabled(model.faces.profiles.isEmpty)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Remove all faces?", isPresented: $confirmingRemoveAll) {
            Button("Remove All", role: .destructive) { model.faces.removeAll() }
        } message: {
            Text("Face unlock stops until you scan your face again.")
        }
    }

    private func row(for profile: FaceProfile) -> some View {
        ProfileRow(profile: profile, isCompatible: profile.isCompatible(with: embedder.modelIdentifier)) { updated in
            model.faces.update(updated)
        } remove: {
            model.faces.remove(profile.id)
        }
    }
}

private struct ProfileRow: View {
    let profile: FaceProfile
    let isCompatible: Bool
    let update: (FaceProfile) -> Void
    let remove: () -> Void

    private var isEnabled: Binding<Bool> {
        Binding {
            profile.isEnabled
        } set: { enabled in
            var changed = profile
            changed.isEnabled = enabled
            update(changed)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: profile.role == .blocked ? "person.crop.circle.badge.xmark" : "person.crop.circle.fill")
                .font(.title)
                .foregroundStyle(profile.isEnabled ? (profile.role == .blocked ? .red : .green) : .secondary)
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
            Toggle("Use", isOn: isEnabled)
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
