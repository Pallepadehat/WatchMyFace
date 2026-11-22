import Foundation

/// `--demo-notch`: plays the notch through every state on a loop, no camera needed. For working on how it looks
/// and moves; take a screenshot or a recording while it runs.
struct NotchDemo {
    let notch: NotchController

    func start() {
        Task { @MainActor in
            while !Task.isCancelled {
                notch.show(.scanning)
                try? await Task.sleep(for: .seconds(2.2))
                notch.show(.success)
                try? await Task.sleep(for: .seconds(1.6))
                await notch.close()
                try? await Task.sleep(for: .seconds(1))

                notch.show(.scanning)
                try? await Task.sleep(for: .seconds(2))
                notch.show(.failure)
                try? await Task.sleep(for: .seconds(1.2))
                notch.show(.notice(.tryAgain))
                try? await Task.sleep(for: .seconds(2))
                notch.show(.notice(.touchIDNeeded))
                try? await Task.sleep(for: .seconds(2))
                await notch.close()
                try? await Task.sleep(for: .seconds(1.2))
            }
        }
    }
}
