import FaceKit
import Foundation
import OSLog

/// How a scan ended.
enum ScanResult {
    case matched(FaceScore)
    /// Someone was there, but not an enrolled face (or not for long enough). Their closest score, for Settings.
    case noMatch(closest: FaceScore?)
    /// Nobody looked at the camera.
    case noFace
    case failed(any Error)
    case cancelled
}

/// What a scan is looking for.
struct ScanRequest: Sendable {
    var profiles: [FaceProfile]
    var matcher: FaceMatcher
    /// Frames in a row that must match the same profile.
    var requiredStreak = 2
    var requireBlink = false
    var timeout: Duration = .seconds(5)
}

/// Looks for an enrolled face: starts the camera, reads frames until one profile has matched a few in a row (and,
/// if asked, the person has blinked), and stops the camera again.
final class FaceScanner {
    let camera: CameraSession
    let recognizer: FaceRecognizer
    private var session: ScanSession?

    init(camera: CameraSession, recognizer: FaceRecognizer) {
        self.camera = camera
        self.recognizer = recognizer
    }

    var isScanning: Bool { session != nil }

    /// Scans until a match, the timeout or ``cancel()``. `onFrame` gets every frame's closest score, on the main actor.
    func scan(_ request: ScanRequest, cameraID: String?, onFrame: (@MainActor (FaceScore?) -> Void)? = nil) async -> ScanResult {
        cancel()
        let session = ScanSession(request: request, recognizer: recognizer)
        self.session = session
        defer {
            if self.session === session {
                self.session = nil
                camera.onFrame = nil
                camera.stop()
            }
        }

        do {
            try await camera.start(cameraID: cameraID)
        } catch {
            return .failed(error)
        }
        return await withCheckedContinuation { continuation in
            session.begin(continuation) { score in
                Task { @MainActor in onFrame?(score) }
            }
            camera.onFrame = { frame in session.read(frame) }
            Task { @MainActor in
                try? await Task.sleep(for: request.timeout)
                session.finishWithTimeout()
            }
        }
    }

    func cancel() {
        session?.finish(.cancelled)
        session = nil
    }
}

/// One scan's progress. Fed frames on the camera's queue, finished from anywhere, so it keeps its state behind a lock.
nonisolated private final class ScanSession: @unchecked Sendable {
    private let request: ScanRequest
    private let recognizer: FaceRecognizer
    private let modelIdentifier: String
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ScanResult, Never>?
    private var onScore: (@Sendable (FaceScore?) -> Void)?
    private var streak: MatchStreak
    private var blinks = BlinkDetector()
    private var closest: FaceScore?
    private var sawFace = false
    private var isBusy = false

    init(request: ScanRequest, recognizer: FaceRecognizer) {
        self.request = request
        self.recognizer = recognizer
        modelIdentifier = recognizer.embedder.modelIdentifier
        streak = MatchStreak(required: request.requiredStreak)
    }

    func begin(_ continuation: CheckedContinuation<ScanResult, Never>, onScore: @escaping @Sendable (FaceScore?) -> Void) {
        lock.withLock {
            self.continuation = continuation
            self.onScore = onScore
        }
    }

    func read(_ frame: CameraFrame) {
        // One frame at a time; the camera drops the ones that arrive meanwhile.
        let claimed = lock.withLock {
            guard continuation != nil, !isBusy else { return false }
            isBusy = true
            return true
        }
        guard claimed else { return }
        let reading = recognizer.read(frame)
        let score = reading?.embedding.flatMap {
            request.matcher.scores(for: $0, against: request.profiles, modelIdentifier: modelIdentifier).first
        }

        let result: ScanResult? = lock.withLock {
            isBusy = false
            if reading != nil { sawFace = true }
            if let score, score.margin > closest?.margin ?? -.infinity { closest = score }
            if let openness = reading?.face.eyeOpenness { blinks.record(openness: openness) }
            streak.record(score?.passes == true ? score?.profileID : nil)
            let blinkSatisfied = !request.requireBlink || blinks.blinks > 0
            guard streak.isSatisfied, blinkSatisfied, let score else { return nil }
            return .matched(score)
        }
        onScore?(score)
        if let result { finish(result) }
    }

    func finishWithTimeout() {
        let result: ScanResult = lock.withLock { sawFace ? .noMatch(closest: closest) : .noFace }
        if case .noMatch(let closest?) = result {
            Log.recognition.info(
                "No match: closest \(closest.similarity, format: .fixed(precision: 3)), needed \(closest.threshold, format: .fixed(precision: 3))"
            )
        } else {
            Log.recognition.info("No face seen")
        }
        finish(result)
    }

    func finish(_ result: ScanResult) {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(returning: result)
    }
}
