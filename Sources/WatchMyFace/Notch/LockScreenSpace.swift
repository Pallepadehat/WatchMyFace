import AppKit
import OSLog

/// Puts a window on the lock screen, which no public API can.
///
/// The lock screen sits above every window level an app can ask for. This creates a window-server *space* at the
/// level Notification Center uses while locked, and moves the notch window into it, through private SkyLight
/// functions. Technique from Lakr233/SkyLightWindow (https://github.com/Lakr233/SkyLightWindow, MIT), by way of
/// glance (https://github.com/jonnyoo/glance, MIT).
///
/// Being private, these functions can change or vanish in any macOS update. Everything is looked up at runtime and
/// ``shared`` is `nil` when anything is missing: the notch then simply doesn't show on the lock screen, and face
/// unlock still works. Only move a window in while the screen is actually locked.
final class LockScreenSpace {
    static let shared: LockScreenSpace? = LockScreenSpace()

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias SpaceAddWindowsAndRemoveFromSpaces = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32
    private typealias RemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32

    /// Notification Center's level on the lock screen: above the lock screen's own windows.
    private static let lockScreenLevel: Int32 = 400

    private let connection: Int32
    private let space: Int32
    private let addWindows: SpaceAddWindowsAndRemoveFromSpaces
    private let removeWindows: RemoveWindowsFromSpaces

    private init?() {
        guard let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
            let mainConnectionID = dlsym(skyLight, "SLSMainConnectionID"),
            let spaceCreate = dlsym(skyLight, "SLSSpaceCreate"),
            let setLevel = dlsym(skyLight, "SLSSpaceSetAbsoluteLevel"),
            let showSpaces = dlsym(skyLight, "SLSShowSpaces"),
            let addWindows = dlsym(skyLight, "SLSSpaceAddWindowsAndRemoveFromSpaces"),
            let removeWindows = dlsym(skyLight, "SLSRemoveWindowsFromSpaces")
        else {
            Log.notch.notice("SkyLight isn't available; the notch won't show on the lock screen")
            return nil
        }
        self.addWindows = unsafeBitCast(addWindows, to: SpaceAddWindowsAndRemoveFromSpaces.self)
        self.removeWindows = unsafeBitCast(removeWindows, to: RemoveWindowsFromSpaces.self)
        connection = unsafeBitCast(mainConnectionID, to: MainConnectionID.self)()
        // The 1 matters: other values make Finder draw the desktop's icons into this space.
        space = unsafeBitCast(spaceCreate, to: SpaceCreate.self)(connection, 1, 0)
        _ = unsafeBitCast(setLevel, to: SpaceSetAbsoluteLevel.self)(connection, space, Self.lockScreenLevel)
        _ = unsafeBitCast(showSpaces, to: ShowSpaces.self)(connection, [space] as CFArray)
    }

    func add(_ window: NSWindow) {
        _ = addWindows(connection, space, [window.windowNumber] as CFArray, 7)
    }

    func remove(_ window: NSWindow) {
        _ = removeWindows(connection, [window.windowNumber] as CFArray, [space] as CFArray)
    }
}
