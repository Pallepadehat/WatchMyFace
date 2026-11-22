import FaceKit
import SwiftUI

/// The menu bar icon: the Face ID glyph, dimmed while face unlock is off.
struct MenuBarIcon: View {
    let status: UnlockCoordinator.Status

    var body: some View {
        Image(systemName: "faceid")
            .symbolRenderingMode(.hierarchical)
            .opacity(status == .ready || status == .scanning ? 1 : 0.5)
            .accessibilityLabel("WatchMyFace, \(status.title)")
    }
}

/// The menu bar panel: whether face unlock is on, and the few things you'd want from here.
struct MenuBarView: View {
    let model: AppModel
    @State private var error: String?

    private var status: UnlockCoordinator.Status { model.unlock.status }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let error {
                Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            actions
            if let version = model.updater.availableVersion {
                Button {
                    model.updater.installUpdate()
                } label: {
                    Label("Update to \(version)…", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(MenuRowStyle(tint: .accentColor))
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 280)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: status.symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(status.tint)
                .frame(width: 40, height: 40)
                .background(status.tint.opacity(0.15), in: .circle)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text("Face Unlock").font(.headline)
                Text(status.title).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 2) {
            switch status {
            case .needsSetup:
                Button {
                    model.showSetup()
                } label: {
                    Label("Set Up Face Unlock…", systemImage: "faceid")
                }
                .buttonStyle(MenuRowStyle())
            case .paused:
                Button {
                    Task {
                        do {
                            try await model.unlock.arm()
                            error = nil
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Turn On with Touch ID", systemImage: "touchid")
                }
                .buttonStyle(MenuRowStyle())
            case .ready, .scanning:
                Button {
                    model.unlock.tryFaceUnlock()
                } label: {
                    Label("Try Face Unlock", systemImage: "viewfinder")
                }
                .buttonStyle(MenuRowStyle())
                .disabled(status == .scanning)
                Button {
                    model.unlock.disarm()
                } label: {
                    Label("Turn Off Until Next Touch ID", systemImage: "pause.circle")
                }
                .buttonStyle(MenuRowStyle())
            }
        }
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Text("Settings…")
            }
            .buttonStyle(MenuRowStyle(compact: true))
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(MenuRowStyle(compact: true))
                .keyboardShortcut("q")
        }
    }
}

extension UnlockCoordinator.Status {
    var title: String {
        switch self {
        case .needsSetup: "Not set up"
        case .ready: "On"
        case .scanning: "Looking…"
        case .paused(let block):
            switch block {
            case .notArmed: "Off — Touch ID turns it on"
            case .lockedTooLong: "Paused after a long time locked"
            case .armedTooLong: "Paused after two days"
            case .tooManyFailures: "Paused after too many tries"
            }
        }
    }

    var symbol: String {
        switch self {
        case .needsSetup: "faceid"
        case .ready: "checkmark.circle.fill"
        case .scanning: "viewfinder"
        case .paused: "touchid"
        }
    }

    var tint: Color {
        switch self {
        case .needsSetup: .secondary
        case .ready, .scanning: .green
        case .paused: .orange
        }
    }
}

/// A full-width row that highlights on hover, like a menu item.
struct MenuRowStyle: ButtonStyle {
    var tint: Color = .primary
    var compact = false
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(MenuRowLabelStyle())
            .foregroundStyle(tint)
            .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, compact ? 4 : 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering && isEnabled ? Color.primary.opacity(0.1) : .clear)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }
}

private struct MenuRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.frame(width: 18)
            configuration.title
        }
    }
}
