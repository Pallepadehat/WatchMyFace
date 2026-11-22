import AVFoundation
import CoreVideo
import OSLog

/// One frame from the camera. Pixel buffers aren't `Sendable`, but each frame is only ever read, by one consumer.
nonisolated struct CameraFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let timestamp: CMTime
}

nonisolated enum CameraError: LocalizedError {
    case notAuthorized
    case noCamera
    case cannotUse(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "WatchMyFace isn't allowed to use the camera. Allow it in System Settings › Privacy & Security › Camera."
        case .noCamera: "No camera found."
        case .cannotUse(let reason): "The camera couldn't be started: \(reason)"
        }
    }
}

/// The camera, running only while something needs it: a scan at the lock screen, or setup.
///
/// Frames arrive on a queue of their own and go straight to ``onFrame``, which runs on that queue. A frame that
/// comes in while the last one is still being looked at is dropped, so analysis never falls behind the camera.
nonisolated final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.pallepadehat.WatchMyFace.camera", qos: .userInteractive)
    private let output = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput?
    private let lock = NSLock()
    private var frameHandler: (@Sendable (CameraFrame) -> Void)?

    /// Called on the camera's queue, for every frame while running.
    var onFrame: (@Sendable (CameraFrame) -> Void)? {
        get { lock.withLock { frameHandler } }
        set { lock.withLock { frameHandler = newValue } }
    }

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    static var isAuthorized: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }

    /// Asks for camera access if it hasn't been asked yet. True if it's allowed.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    /// Every camera that can see a face: the built-in one, Continuity Camera, anything plugged in.
    static func availableCameras() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video, position: .unspecified
        ).devices
    }

    /// The preferred camera if it's connected, else the built-in one, else whatever there is.
    static func camera(preferring uniqueID: String?) -> AVCaptureDevice? {
        let cameras = availableCameras()
        if let uniqueID, let preferred = cameras.first(where: { $0.uniqueID == uniqueID }) { return preferred }
        return cameras.first { $0.deviceType == .builtInWideAngleCamera } ?? cameras.first
    }

    /// Starts the camera. Waits until frames are flowing, which takes a few hundred milliseconds.
    func start(cameraID: String?) async throws {
        guard Self.isAuthorized else { throw CameraError.notAuthorized }
        guard let found = Self.camera(preferring: cameraID) else { throw CameraError.noCamera }
        // Devices aren't Sendable, but this one is only configured on the camera's queue from here on.
        nonisolated(unsafe) let device = found
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async { [self] in
                do {
                    try configure(with: device)
                    if !session.isRunning { session.startRunning() }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        Log.camera.info("Camera started: \(found.localizedName, privacy: .public)")
    }

    func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
            Log.camera.info("Camera stopped")
        }
    }

    private func configure(with device: AVCaptureDevice) throws {
        guard input?.device.uniqueID != device.uniqueID else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // 720p is plenty for a face at arm's length, and half the work of 1080p.
        session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high
        if let input { session.removeInput(input) }
        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.cannotUse(error.localizedDescription)
        }
        guard session.canAddInput(newInput) else { throw CameraError.cannotUse("it's in use by another app") }
        session.addInput(newInput)
        input = newInput
        if !session.outputs.contains(output), session.canAddOutput(output) { session.addOutput(output) }
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let handler = onFrame else { return }
        handler(CameraFrame(pixelBuffer: pixelBuffer, timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)))
    }
}
