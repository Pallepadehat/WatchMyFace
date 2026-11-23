import FaceKit
import Foundation
import Observation

/// Scanning a face for a new profile: "move your head slowly to complete the circle".
///
/// Every frame lights the ticks the head points at (``EnrollmentCoverage``) and, a few at a time per direction
/// (``PoseBin``), keeps the face's embedding. Once the circle is complete and there are samples from straight ahead,
/// it's done, and ``makeProfile(named:)`` turns the samples into a ``FaceProfile``.
@Observable
final class Enrollment {
    enum Guidance: Equatable {
        case starting
        case noFace
        case tooFar
        case moveHead
        case almostDone
        case done

        var text: String {
            switch self {
            case .starting: "Getting the camera ready…"
            case .noFace: "Position your face in the frame"
            case .tooFar: "Move a little closer"
            case .moveHead: "Move your head slowly to complete the circle"
            case .almostDone: "Now look straight at the camera"
            case .done: "Face scan complete"
            }
        }
    }

    private(set) var coverage = EnrollmentCoverage()
    private(set) var guidance: Guidance = .starting
    private(set) var error: String?
    var isComplete: Bool { guidance == .done }

    @ObservationIgnored private let camera: CameraSession
    @ObservationIgnored private let recognizer: FaceRecognizer
    @ObservationIgnored private var samples: [PoseBin: [FaceEmbedding]] = [:]
    @ObservationIgnored private var poses = PoseEstimator()
    @ObservationIgnored private let reader = FrameGate()

    /// Samples kept per direction: most from straight ahead, how you'll usually look at the Mac, and a few from
    /// every angle. Enough for variety, few enough to stay quick to match against.
    private static func samplesWanted(in bin: PoseBin) -> Int { bin == .front ? 8 : 3 }
    private static let minimumFrontSamples = 4
    /// Closer than the least a scan accepts, so the samples are sharp.
    private static let minimumProminence = FaceAnalyzer.minimumProminence * 1.3

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
        samples = [:]
        guidance = .starting
        error = nil
    }

    func makeProfile(named name: String, role: FaceProfile.Role = .allowed) -> FaceProfile {
        FaceProfile(
            name: name, role: role, modelIdentifier: recognizer.embedder.modelIdentifier,
            samples: samples.values.flatMap { $0 })
    }

    private func record(_ reading: FrameReading?) {
        guard guidance != .done else { return }
        guard let reading else {
            guidance = .noFace
            return
        }
        guard reading.face.prominence >= Self.minimumProminence else {
            guidance = .tooFar
            return
        }
        guard let landmarks = reading.face.landmarks else { return }
        // The first frames teach the estimator what straight ahead is; it says nothing until then.
        guard let pose = poses.pose(leftEye: landmarks.leftEye, rightEye: landmarks.rightEye, nose: landmarks.nose) else {
            guidance = .moveHead
            return
        }
        coverage.record(pose)
        if let embedding = reading.embedding, let bin = PoseBin(pose),
            samples[bin, default: []].count < Self.samplesWanted(in: bin)
        {
            samples[bin, default: []].append(embedding)
        }

        let frontReady = (samples[.front]?.count ?? 0) >= Self.minimumFrontSamples
        if coverage.isComplete, frontReady {
            guidance = .done
            stop()
        } else if coverage.fraction >= 1 {
            guidance = .almostDone
        } else {
            guidance = .moveHead
        }
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
