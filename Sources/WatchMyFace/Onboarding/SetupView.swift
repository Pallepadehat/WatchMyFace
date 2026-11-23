import SwiftUI

/// The setup window: welcome, permissions, the face scan, the password, done. Black, like Face ID setup on a Mac.
struct SetupView: View {
    @Bindable var setup: SetupModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                switch setup.step {
                case .welcome: WelcomeStep(setup: setup)
                case .permissions: PermissionsStep(setup: setup)
                case .faceScan: FaceScanStep(setup: setup)
                case .password: PasswordStep(setup: setup)
                case .done: DoneStep(setup: setup)
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 30)), removal: .opacity.combined(with: .offset(x: -30))))
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
        }
        .animation(.smooth(duration: 0.35), value: setup.step)
        .frame(width: 700, height: 460)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    let setup: SetupModel

    var body: some View {
        VStack(spacing: 18) {
            FaceIDDemo(size: 84)
                .padding(.bottom, 4)
            Text("Unlock your Mac with a glance").font(.system(size: 28, weight: .bold))
            Text("When your Mac wakes up locked, WatchMyFace looks for you in the notch and unlocks it when it's you. Everything happens on this Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 460)
            Label {
                Text(
                    "A Mac camera sees in 2D, so this isn't as secure as Touch ID or your password. A lookalike or a video of you could fool it. Use it for convenience, not protection."
                )
            } icon: {
                Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.orange)
            }
            .font(.callout)
            .padding(12)
            .frame(maxWidth: 500)
            .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
            Spacer(minLength: 0)
            PrimaryButton("Continue") { setup.next() }
        }
    }
}

private struct PermissionsStep: View {
    let setup: SetupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepHeader(title: "Two permissions", subtitle: "WatchMyFace needs to see you, and to type your password at the lock screen.")
            PermissionRow(
                symbol: "camera.fill", title: "Camera",
                detail: "To look for your face. Frames are read in memory and thrown away; nothing is recorded.",
                isGranted: setup.hasCamera, action: setup.requestCamera)
            PermissionRow(
                symbol: "keyboard.fill", title: "Accessibility",
                detail: "To type your password into the lock screen. macOS has no other way for an app to unlock it.",
                isGranted: setup.hasAccessibility, action: setup.requestAccessibility)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                PrimaryButton("Continue", isEnabled: setup.permissionsGranted) { setup.next() }
            }
        }
    }
}

private struct FaceScanStep: View {
    @Bindable var setup: SetupModel

    var body: some View {
        HStack(spacing: 40) {
            EnrollmentRing(enrollment: setup.enrollment)
            VStack(alignment: .leading, spacing: 16) {
                Text(setup.enrollment.guidance.text)
                    .font(.system(size: 20, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(.smooth, value: setup.enrollment.guidance)
                if let error = setup.enrollment.error {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
                if setup.isBlocking, !setup.enrollment.isComplete {
                    Label("Ask the person you're blocking to sit in front of the camera.", systemImage: "hand.raised.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if setup.enrollment.isComplete {
                    TextField(
                        "Name", text: $setup.appearanceName,
                        prompt: Text(setup.isBlocking ? "Who is this? (Dad, a sibling…)" : "Name this appearance")
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                    PrimaryButton("Continue") { setup.next() }
                } else {
                    Text("Keep your face in the circle and roll your head around, like drawing a circle with your nose.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.smooth, value: setup.enrollment.isComplete)
        }
    }
}

private struct PasswordStep: View {
    @Bindable var setup: SetupModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 84, height: 84)
                .background(.white.opacity(0.08), in: .circle)
            Text("Your Mac's login password").font(.system(size: 24, weight: .bold))
            Text("WatchMyFace types it into the lock screen when it sees you. It's checked now, kept in your keychain, and only loaded after Touch ID.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 460)
            SecureField("Password", text: $setup.password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .focused($isFocused)
                .onSubmit { if !setup.password.isEmpty { setup.next() } }
            if let error = setup.passwordError {
                Text(error).foregroundStyle(.red).font(.callout)
            }
            Spacer(minLength: 0)
            PrimaryButton(setup.isSavingPassword ? "Checking…" : "Continue", isEnabled: !setup.password.isEmpty && !setup.isSavingPassword) {
                setup.next()
            }
        }
        .onAppear { isFocused = true }
    }
}

private struct DoneStep: View {
    let setup: SetupModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: setup.step)
            Text(doneTitle).font(.system(size: 28, weight: .bold))
            Text(
                setup.isBlocking
                    ? "Face unlock now turns away anyone who looks more like them than like you."
                    : "Lock your Mac with ⌃⌘Q, wake it, and look at it. WatchMyFace lives in the menu bar if you need it."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 440)
            Spacer(minLength: 0)
            PrimaryButton("Done") { setup.finish() }
        }
    }

    private var doneTitle: String {
        switch setup.purpose {
        case .setUp: "You're all set"
        case .addAppearance: "Appearance added"
        case .blockSomeone: "Blocked"
        }
    }
}

// MARK: - Pieces

/// The Face ID glyph going round its whole story on a loop: face, scan, tick.
private struct FaceIDDemo: View {
    let size: CGFloat
    @State private var phase = FaceIDGlyph.Phase.idle

    var body: some View {
        FaceIDGlyph(phase: phase, size: size)
            .task {
                let steps: [(FaceIDGlyph.Phase, Duration)] = [(.idle, .seconds(1.4)), (.scanning, .seconds(1.6)), (.success, .seconds(2))]
                while !Task.isCancelled {
                    for (step, duration) in steps {
                        phase = step
                        try? await Task.sleep(for: duration)
                    }
                }
            }
    }
}

private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).foregroundStyle(.secondary)
        }
    }
}

private struct PermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button("Allow…", action: action).buttonStyle(.glass)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isGranted)
    }
}

private struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title).frame(minWidth: 120)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .disabled(!isEnabled)
    }
}
