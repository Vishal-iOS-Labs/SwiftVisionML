import CoreGraphics
import Testing
@testable import SwiftVisionML

@Suite("SwiftVisionML Core Geometry, Telemetry & Throttling Tests")
struct SwiftVisionMLTests {

    @Test("Vision bottom-left origin flips accurately to SwiftUI top-left")
    func visionToSwiftUIBasicFlip() {
        // Vision rect at bottom-left: x=0.1, y=0.2, w=0.4, h=0.3 -> top edge is 0.5 from bottom, so y=0.5 in top-left.
        let visionRect = CGRect(x: 0.1, y: 0.2, width: 0.4, height: 0.3)
        let container = CGSize(width: 400, height: 800)

        let swiftUIRect = CoordinateMapper.swiftUIRect(
            fromVisionRect: visionRect,
            in: container
        )

        #expect(abs(swiftUIRect.origin.x - 40.0) < 0.001)
        #expect(abs(swiftUIRect.origin.y - 400.0) < 0.001)
        #expect(abs(swiftUIRect.size.width - 160.0) < 0.001)
        #expect(abs(swiftUIRect.size.height - 240.0) < 0.001)
    }

    @Test("Front-camera mirroring flips horizontal axis accurately")
    func frontCameraMirroring() {
        let visionRect = CGRect(x: 0.1, y: 0.0, width: 0.2, height: 0.5)
        let container = CGSize(width: 100, height: 100)

        let mirrored = CoordinateMapper.swiftUIRect(
            fromVisionRect: visionRect,
            in: container,
            isMirrored: true
        )

        // Mirrored X = 1.0 - 0.1 - 0.2 = 0.7 -> 70pt
        #expect(abs(mirrored.origin.x - 70.0) < 0.001)
        #expect(abs(mirrored.origin.y - 50.0) < 0.001)
    }

    @Test("Aspect-fit letterboxing maps coordinates inside rendered image rect")
    func aspectFitLetterboxing() {
        // 200x100 landscape image inside 200x200 square container -> rendered at y=50, height=100
        let visionRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let rect = CoordinateMapper.swiftUIRect(
            fromVisionRect: visionRect,
            in: CGSize(width: 200, height: 200),
            contentSize: CGSize(width: 200, height: 100),
            contentMode: .aspectFit
        )

        #expect(abs(rect.origin.x - 0.0) < 0.001)
        #expect(abs(rect.origin.y - 50.0) < 0.001)
        #expect(abs(rect.size.width - 200.0) < 0.001)
        #expect(abs(rect.size.height - 100.0) < 0.001)
    }

    @Test("Vision -> SwiftUI -> Vision round-trip preserves rect")
    func roundTripCoordinateMapping() {
        let original = CGRect(x: 0.25, y: 0.15, width: 0.5, height: 0.35)
        let container = CGSize(width: 393, height: 852)

        let swiftUI = CoordinateMapper.swiftUIRect(fromVisionRect: original, in: container)
        let recovered = CoordinateMapper.visionRect(fromSwiftUIRect: swiftUI, in: container)

        #expect(abs(recovered.origin.x - original.origin.x) < 0.0001)
        #expect(abs(recovered.origin.y - original.origin.y) < 0.0001)
        #expect(abs(recovered.size.width - original.size.width) < 0.0001)
        #expect(abs(recovered.size.height - original.size.height) < 0.0001)
    }

    @Test("FrameRateThrottler accepts first frame and throttles immediate burst")
    func frameRateThrottling() async {
        let throttler = FrameRateThrottler(targetFPS: 10.0)

        let first = await throttler.shouldProcessNextFrame()
        let secondImmediate = await throttler.shouldProcessNextFrame()
        let processed = await throttler.processedFrameCount
        let dropped = await throttler.droppedFrameCount

        #expect(first == true)
        #expect(secondImmediate == false)
        #expect(processed == 1)
        #expect(dropped == 1)

        await throttler.reset()
        let afterReset = await throttler.processedFrameCount
        #expect(afterReset == 0)
    }

    @Test("InferenceMetrics calculates FPS and formats latency cleanly")
    func inferenceMetricsFormatting() {
        let metrics = InferenceMetrics(latencyMilliseconds: 10.0, computeTarget: .neuralEnginePreferred)
        #expect(abs(metrics.estimatedFPS - 100.0) < 0.001)
        #expect(metrics.formattedLatency == "10.0 ms")
        #expect(metrics.computeTarget.shortBadge == "ANE")
    }

    @Test("Classification confidence clamps out-of-range values and formats percentage")
    func classificationClampingAndFormatting() {
        let high = VisionClassification(identifier: "healthy_tissue", confidence: 1.42)
        let normal = VisionClassification(identifier: "stage_1", confidence: 0.946)
        let low = VisionClassification(identifier: "noise", confidence: -0.2)

        #expect(high.confidence == 1.0)
        #expect(high.formattedConfidence == "100.0%")
        #expect(normal.formattedConfidence == "94.6%")
        #expect(low.confidence == 0.0)
    }
}
