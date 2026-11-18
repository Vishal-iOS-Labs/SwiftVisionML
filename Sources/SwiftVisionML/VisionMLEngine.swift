import CoreGraphics
import CoreML
import CoreVideo
import Foundation
import ImageIO
import Vision

/// Swift 6 concurrency-safe actor wrapping Core ML + Vision inference
/// with built-in sub-millisecond `ContinuousClock` latency telemetry.
public actor VisionMLEngine {
    private let visionModel: VNCoreMLModel
    private let computeTarget: ComputeTarget
    private let imageCropAndScaleOption: VNImageCropAndScaleOption

    /// Initializes the engine from a compiled `.mlmodelc` URL with the requested compute target.
    public init(
        compiledModelURL: URL,
        computeTarget: ComputeTarget = .neuralEnginePreferred,
        imageCropAndScaleOption: VNImageCropAndScaleOption = .centerCrop
    ) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeTarget.mlComputeUnits

        let mlModel = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
        do {
            self.visionModel = try VNCoreMLModel(for: mlModel)
        } catch {
            throw VisionMLError.modelInitializationFailed(error.localizedDescription)
        }
        self.computeTarget = computeTarget
        self.imageCropAndScaleOption = imageCropAndScaleOption
    }

    /// Initializes the engine from an already-loaded `MLModel`.
    public init(
        model: MLModel,
        computeTarget: ComputeTarget = .neuralEnginePreferred,
        imageCropAndScaleOption: VNImageCropAndScaleOption = .centerCrop
    ) throws {
        do {
            self.visionModel = try VNCoreMLModel(for: model)
        } catch {
            throw VisionMLError.modelInitializationFailed(error.localizedDescription)
        }
        self.computeTarget = computeTarget
        self.imageCropAndScaleOption = imageCropAndScaleOption
    }

    /// Runs image classification on a `CGImage` and returns top-K classifications + timing telemetry.
    public func classify(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation = .up,
        topK: Int = 5,
        minimumConfidence: Double = 0.05
    ) throws -> VisionInferenceReport<[VisionClassification]> {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        return try executeClassification(
            handler: handler,
            topK: topK,
            minimumConfidence: minimumConfidence
        )
    }

    /// Runs image classification on a live camera `CVPixelBuffer`.
    public func classify(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .right,
        topK: Int = 5,
        minimumConfidence: Double = 0.05
    ) throws -> VisionInferenceReport<[VisionClassification]> {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return try executeClassification(
            handler: handler,
            topK: topK,
            minimumConfidence: minimumConfidence
        )
    }

    /// Runs object detection on a `CGImage` and returns normalized detections + timing telemetry.
    public func detect(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation = .up,
        minimumConfidence: Double = 0.25
    ) throws -> VisionInferenceReport<[VisionDetection]> {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        return try executeDetection(
            handler: handler,
            minimumConfidence: minimumConfidence
        )
    }

    /// Runs object detection on a live camera `CVPixelBuffer`.
    public func detect(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .right,
        minimumConfidence: Double = 0.25
    ) throws -> VisionInferenceReport<[VisionDetection]> {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return try executeDetection(
            handler: handler,
            minimumConfidence: minimumConfidence
        )
    }

    // MARK: - Private Execution Helpers

    private func executeClassification(
        handler: VNImageRequestHandler,
        topK: Int,
        minimumConfidence: Double
    ) throws -> VisionInferenceReport<[VisionClassification]> {
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = imageCropAndScaleOption

        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            try handler.perform([request])
        }

        guard let results = request.results else {
            throw VisionMLError.emptyResults
        }

        let observations = results.compactMap { $0 as? VNClassificationObservation }
        let classifications = observations
            .filter { Double($0.confidence) >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(max(topK, 1))
            .map { VisionClassification(identifier: $0.identifier, confidence: Double($0.confidence)) }

        let metrics = InferenceMetrics(
            latencyMilliseconds: elapsed.milliseconds,
            computeTarget: computeTarget
        )
        return VisionInferenceReport(output: Array(classifications), metrics: metrics)
    }

    private func executeDetection(
        handler: VNImageRequestHandler,
        minimumConfidence: Double
    ) throws -> VisionInferenceReport<[VisionDetection]> {
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = imageCropAndScaleOption

        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            try handler.perform([request])
        }

        guard let results = request.results else {
            throw VisionMLError.emptyResults
        }

        let observations = results.compactMap { $0 as? VNRecognizedObjectObservation }
        let detections: [VisionDetection] = observations.compactMap { observation in
            guard let topLabel = observation.labels.first,
                  Double(topLabel.confidence) >= minimumConfidence else {
                return nil
            }
            return VisionDetection(
                label: topLabel.identifier,
                confidence: Double(topLabel.confidence),
                normalizedBoundingBox: observation.boundingBox
            )
        }
        .sorted { $0.confidence > $1.confidence }

        let metrics = InferenceMetrics(
            latencyMilliseconds: elapsed.milliseconds,
            computeTarget: computeTarget
        )
        return VisionInferenceReport(output: detections, metrics: metrics)
    }
}

private extension Duration {
    var milliseconds: Double {
        let components = self.components
        return Double(components.seconds) * 1000.0 + Double(components.attoseconds) / 1e15
    }
}
