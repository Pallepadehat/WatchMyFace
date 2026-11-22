import AppKit
import OSLog

/// A window-server space drawn above the lock screen. A window moved into it shows on the real macOS lock screen
/// (and, unlocked, above everything else too).
///
/// macOS has no public API for this. The window server stacks whole spaces by absolute level: the setup assistant at
/// 100, the security agent at 200, the lock screen at 300, notifications over the lock screen at 400. This creates a
/// space at 400 through private SkyLight functions, the way WatchMyFace's sibling WatchMyMusic puts lyrics on the
/// lock screen (and as Lakr233/SkyLightWindow, MIT, first showed).
///
/// Everything is looked up at runtime. If a macOS update removes a function, ``shared`` is `nil`: the notch then
/// just doesn't show on the lock screen, and face unlock still works.
final class LockScreenSpace {
    static let shared = LockScreenSpace()

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> UInt64
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias SpaceAddWindows = @convention(c) (Int32, UInt64, CFArray, Int32) -> Int32

    /// Notifications over the lock screen: above its wallpaper, clock and password field.
    private static let level: Int32 = 400

    private let connection: Int32
    private let space: UInt64
    private let addWindows: SpaceAddWindows

    private init?() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
        guard let library = dlopen(path, RTLD_LAZY),
            let mainConnectionID = Self.function("SLSMainConnectionID", in: library, as: MainConnectionID.self),
            let spaceCreate = Self.function("SLSSpaceCreate", in: library, as: SpaceCreate.self),
            let setLevel = Self.function("SLSSpaceSetAbsoluteLevel", in: library, as: SpaceSetAbsoluteLevel.self),
            let showSpaces = Self.function("SLSShowSpaces", in: library, as: ShowSpaces.self),
            let addWindows = Self.function("SLSSpaceAddWindowsAndRemoveFromSpaces", in: library, as: SpaceAddWindows.self)
        else {
            Log.notch.error("SkyLight isn't available; the notch won't show on the lock screen")
            return nil
        }
        self.addWindows = addWindows
        connection = mainConnectionID()
        // The 1 matters: other values make Finder draw the desktop's icons into this space.
        space = spaceCreate(connection, 1, 0)
        _ = setLevel(connection, space, Self.level)
        _ = showSpaces(connection, [NSNumber(value: space)] as CFArray)
        Log.notch.info("Created the lock screen space \(self.space)")
    }

    /// Moves `window` into the space. Call it before ordering the window front, every time: ordering a window out
    /// can drop it from the space.
    func add(_ window: NSWindow) {
        _ = addWindows(connection, space, [NSNumber(value: window.windowNumber)] as CFArray, 7)
    }

    private static func function<T>(_ name: String, in library: UnsafeMutableRawPointer, as type: T.Type) -> T? {
        dlsym(library, name).map { unsafeBitCast($0, to: type) }
    }
}
