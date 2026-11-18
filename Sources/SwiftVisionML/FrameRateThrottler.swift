import Foundation

/// Thread-safe Swift 6 actor that caps camera frame processing to a target FPS
/// so on-device Core ML inference stays smooth without thermal throttling UI rendering.
public actor FrameRateThrottler {
    public private(set) var targetFPS: Double
    public private(set) var processedFrameCount: Int = 0
    public private(set) var droppedFrameCount: Int = 0

    private let clock = ContinuousClock()
    private var lastAcceptedInstant: ContinuousClock.Instant?

    /// Creates a new frame throttler.
    /// - Parameter targetFPS: Maximum inference passes per second (e.g., `30`, `60`, or `120`).
    public init(targetFPS: Double = 30.0) {
        self.targetFPS = max(targetFPS, 1.0)
    }

    /// Evaluates whether enough time has elapsed to accept the next incoming camera frame.
    public func shouldProcessNextFrame() -> Bool {
        let now = clock.now
        let minInterval = Duration.seconds(1.0 / targetFPS)

        if let last = lastAcceptedInstant, last.duration(to: now) < minInterval {
            droppedFrameCount += 1
            return false
        }

        lastAcceptedInstant = now
        processedFrameCount += 1
        return true
    }

    /// Updates the target inference frame rate dynamically (for instance, lowering FPS under thermal pressure).
    public func setTargetFPS(_ fps: Double) {
        targetFPS = max(fps, 1.0)
    }

    /// Resets frame counters and timing state.
    public func reset() {
        lastAcceptedInstant = nil
        processedFrameCount = 0
        droppedFrameCount = 0
    }
}
