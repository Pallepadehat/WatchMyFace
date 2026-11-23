import AppKit
import SwiftUI

/// The setup window. A plain AppKit window rather than a SwiftUI scene, so it can be opened from anywhere (the
/// menu, Settings, the first launch) and start fresh each time.
final class SetupWindowController: NSObject, NSWindowDelegate {
    private unowned let model: AppModel
    private var window: NSWindow?
    private var setup: SetupModel?

    init(model: AppModel) {
        self.model = model
    }

    func show(_ purpose: SetupModel.Purpose) {
        if let window, setup?.purpose == purpose {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        close()

        let setup = SetupModel(model: model, purpose: purpose)
        setup.onFinish = { [weak self] in self?.close() }
        self.setup = setup

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 460), styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title =
            switch purpose {
            case .setUp: "Set Up Face Unlock"
            case .addAppearance: "Add an Appearance"
            case .blockSomeone: "Block Someone"
            }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: SetupView(setup: setup))
        window.center()
        self.window = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        setup?.cancel()
        setup = nil
        window?.delegate = nil
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        setup?.cancel()
        setup = nil
        window = nil
    }
}
