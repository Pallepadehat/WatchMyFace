import ApplicationServices
import CoreGraphics
import FaceKit
import Foundation

nonisolated enum PasswordTyperError: LocalizedError {
    case notTrusted
    case cannotCreateEvent

    var errorDescription: String? {
        switch self {
        case .notTrusted:
            "WatchMyFace needs Accessibility access to type your password. Allow it in System Settings › Privacy & Security › Accessibility."
        case .cannotCreateEvent: "The keystrokes couldn't be made."
        }
    }
}

/// Types the password into the lock screen and presses Return, as keystrokes from the keyboard itself (the HID
/// event tap), which is what the lock screen's password field listens to. Needs Accessibility access.
///
/// The text goes in as Unicode rather than key codes, so it comes out the same whatever the keyboard layout.
/// Technique from glance (https://github.com/jonnyoo/glance, MIT).
nonisolated enum PasswordTyper {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system's "allow Accessibility" prompt, which links to System Settings.
    @discardableResult
    static func requestTrust() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary)
    }

    /// Clears the field, types `password` and presses Return. Blocks for a few dozen milliseconds.
    static func type(_ password: SecretBytes) throws {
        guard isTrusted else { throw PasswordTyperError.notTrusted }
        let source = CGEventSource(stateID: .hidSystemState)
        try clearField(source)
        try password.withBytes { bytes in
            // UTF-16 for the events, in a buffer that's zeroed again right after.
            var utf16 = Array(String(decoding: bytes, as: UTF8.self).utf16)
            defer { utf16.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
            try typeUnicode(utf16, source)
        }
        try press(Key.returnKey, source)
    }

    private enum Key {
        static let returnKey: CGKeyCode = 0x24
        static let delete: CGKeyCode = 0x33
        static let rightArrow: CGKeyCode = 0x7C
        static let command: CGKeyCode = 0x37
    }

    /// Text events carry at most about 20 characters reliably; longer ones get cut short.
    private static let batchLength = 20

    /// ⌘→ then ⌘⌫: removes anything already typed, by key position, so it works on every layout.
    private static func clearField(_ source: CGEventSource?) throws {
        try press(Key.rightArrow, source, command: true)
        try press(Key.delete, source, command: true)
    }

    private static func typeUnicode(_ utf16: [UInt16], _ source: CGEventSource?) throws {
        var start = 0
        while start < utf16.count {
            var end = min(start + batchLength, utf16.count)
            // Never split a surrogate pair (emoji and the like) between two events.
            if end < utf16.count, (0xD800...0xDBFF).contains(utf16[end - 1]) { end -= 1 }
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { throw PasswordTyperError.cannotCreateEvent }
            utf16[start..<end].withUnsafeBufferPointer { chunk in
                down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk.baseAddress)
                up.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk.baseAddress)
            }
            post(down, up, pause: 0.004)
            start = end
        }
    }

    private static func press(_ key: CGKeyCode, _ source: CGEventSource?, command: Bool = false) throws {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        else { throw PasswordTyperError.cannotCreateEvent }
        guard command else {
            post(down, up, pause: 0.012)
            return
        }
        // Some fields ignore a bare flag; a real ⌘ down and up around the key works everywhere.
        guard let commandDown = CGEvent(keyboardEventSource: source, virtualKey: Key.command, keyDown: true),
            let commandUp = CGEvent(keyboardEventSource: source, virtualKey: Key.command, keyDown: false)
        else { throw PasswordTyperError.cannotCreateEvent }
        commandDown.flags = .maskCommand
        down.flags = .maskCommand
        up.flags = .maskCommand
        commandDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.012)
        post(down, up, pause: 0.012)
        commandUp.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.012)
    }

    private static func post(_ down: CGEvent, _ up: CGEvent, pause: TimeInterval) {
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: pause)
        up.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: pause)
    }
}
