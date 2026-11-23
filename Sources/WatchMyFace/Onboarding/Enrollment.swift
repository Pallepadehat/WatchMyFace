import FaceKit
import Foundation
import Observation

/// Scanning a face for a new profile, like Face ID setup: two slow circles with the head, close to the camera.
///
/// Every frame lights the ticks the head points at (``EnrollmentCoverage``) and offers its embedding to a
/// ``SampleCollector``, which keeps the sharpest few per direction. After the first circle there's a pause ("First
/// scan complete"), then a second circle, which adds as many samples again in slightly different light and angles.
/// Both scans must look like the same face, so nobody can take over halfway. ``makeProfile(named:role:)`` turns the
/// samples, minus any that agree with nothing, into a ``FaceProfile``.
@Observable
final class Enrollment {
    enum Guidance: Equatable {
        case starting
        case noFace
        case tooFar
        case tooClose
        case moveHead
        case almostDone
        case firstScanDone
        case done

        var text: String {
            switch self {
            case .starting: "Getting the camera ready…"
            case .noFace: "Position your face in the frame"
            case .tooFar: "Move a little closer"
            case .tooClose: "Move a little further away"
            case .moveHead: "Move your head slowly to complete the circle"
            case .almostDone: "Now look straight at the camera"
            case .firstScanDone: "First scan complete"
            case .done: "Face scan complete"
            }
        }
    }

    /// Circles with the head, like Face ID's two.
    static let passCount = 2

    private(set) var coverage = EnrollmentCoverage()
    private(set) var guidance: Guidance = .starting
    private(set) var error: String?
    /// Which circle this is, counting from 0.
    private(set) var pass = 0
    var isComplete: Bool { guidance == .done }
    /// The ring shows its tick after each circle.
    var showsCheck: Bool { guidance == .firstScanDone || guidance == .done }
    /// Samples kept so far, for the "sharpest frames" note.
    private(set) var sampleCount = 0

    @ObservationIgnored private let camera: CameraSession
    @ObservationIgnored private let recognizer: FaceRecognizer
    @ObservationIgnored private var collector = SampleCollector()
    @ObservationIgnored private var poses = PoseEstimator()
    @ObservationIgnored private let reader = FrameGate()

    /// Straight-ahead samples each circle needs before it's done.
    private static let minimumFrontSamples = 5
    /// The face must fill at least this much of the frame's width: about half a metre from a MacBook's camera, and
    /// two and a half times what a scan accepts. Closer means sharper samples, with the detail that tells relatives apart.
    static let minimumProminence = 0.2
    /// Any closer and turning the head takes it out of the frame.
    static let maximumProminence = 0.55

    init(camera: CameraSession, recognizer: FaceRecognizer) {
        self.camera = camera
        self.recognizer = recognizer
    }

    var session: CameraSession { camera }

    func start(cameraID: String?) async {
        reset()
        let recognizer = self.recognizer
        let gate = reader
        camera.onFrame = { [weak self] frame in
            guard gate.enter() else { return }
            let reading = recognizer.read(frame, for: .enrollment)
            Task { @MainActor in
                gate.leave()
                self?.record(reading)
            }
        }
        do {
            try await camera.start(cameraID: cameraID)
            if guidance == .starting { guidance = .noFace }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stop() {
        camera.onFrame = nil
        camera.stop()
    }

    func reset() {
        coverage.reset()
        poses.reset()
        collector.reset()
        pass = 0
        sampleCount = 0
        guidance = .starting
        error = nil
    }

    /// After "First scan complete": the second circle.
    func beginNextPass() {
        guard guidance == .firstScanDone else { return }
        collector.nextPass()
        pass = collector.pass
        coverage.reset()
        guidance = .moveHead
    }

    func makeProfile(named name: String, role: FaceProfile.Role = .allowed) -> FaceProfile {
        // Samples further from all the others than a stranger would be are slips, not this face.
        let minimum = recognizer.embedder.similarityFloor - 0.15
        return FaceProfile(
            name: name, role: role, modelIdentifier: recognizer.embedder.modelIdentifier,
            samples: collector.finalSamples(minimumSimilarity: minimum))
    }

    private func record(_ reading: FrameReading?) {
        guard guidance != .done, guidance != .firstScanDone else { return }
        guard let reading else {
            guidance = .noFace
            return
        }
        guard reading.face.prominence >= Self.minimumProminence else {
            guidance = .tooFar
            return
        }
        guard reading.face.prominence <= Self.maximumProminence else {
            guidance = .tooClose
            return
        }
        guard let landmarks = reading.face.landmarks else { return }
        // The first frames teach the estimator what straight ahead is; it says nothing until then.
        guard let pose = poses.pose(leftEye: landmarks.leftEye, rightEye: landmarks.rightEye, nose: landmarks.nose) else {
            guidance = .moveHead
            return
        }
        coverage.record(pose)
        if let embedding = reading.embedding, let bin = PoseBin(pose) {
            collector.offer(embedding, quality: reading.face.captureQuality ?? 0.5, in: bin)
            sampleCount = collector.totalCount
        }

        let frontReady = collector.count(in: .front, pass: pass) >= Self.minimumFrontSamples
        if coverage.isComplete, frontReady {
            finishPass()
        } else if coverage.fraction >= 1 {
            guidance = .almostDone
        } else {
            guidance = .moveHead
        }
    }

    private func finishPass() {
        guard pass + 1 >= Self.passCount else {
            error = nil
            guidance = .firstScanDone
            return
        }
        // Both circles must be the same face, comfortably above where relatives land.
        let needed = recognizer.embedder.similarityFloor + 0.1
        guard let agreement = collector.agreement(between: 0, and: pass), agreement >= needed else {
            reset()
            guidance = .noFace
            error = "The two scans didn't look like the same face. Let's start again."
            return
        }
        guidance = .done
        stop()
    }
}

/// Lets one frame through at a time: the camera drops the frames that arrive while one's still being read.
nonisolated final class FrameGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isBusy = false

    func enter() -> Bool {
        lock.withLock {
            guard !isBusy else { return false }
            isBusy = true
            return true
        }
    }

    func leave() {
        lock.withLock { isBusy = false }
    }
}
