import CoreGraphics
import CoreML
import Foundation

/// Compute-unit preference for Apple Silicon and Apple Neural Engine (ANE) execution.
public enum ComputeTarget: String, Sendable, CaseIterable, Codable {
    case neuralEnginePreferred = "ANE + GPU + CPU"
    case cpuAndNeuralEngine = "ANE + CPU"
    case cpuAndGPU = "GPU + CPU"
    case cpuOnly = "CPU Only"

    /// Maps the preset to Core ML's native `MLComputeUnits`.
    public var mlComputeUnits: MLComputeUnits {
        switch self {
        case .neuralEnginePreferred:
            return .all
        case .cpuAndNeuralEngine:
            return .cpuAndNeuralEngine
        case .cpuAndGPU:
            return .cpuAndGPU
        case .cpuOnly:
            return .cpuOnly
        }
    }

    /// Short display badge label for telemetry HUDs.
    public var shortBadge: String {
        switch self {
        case .neuralEnginePreferred, .cpuAndNeuralEngine:
            return "ANE"
        case .cpuAndGPU:
            return "GPU"
        case .cpuOnly:
            return "CPU"
        }
    }
}

/// A single image classification prediction returned by a Core ML Vision pipeline.
public struct VisionClassification: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let identifier: String
    public let confidence: Double

    public init(identifier: String, confidence: Double) {
        self.id = identifier
        self.identifier = identifier
        self.confidence = min(max(confidence, 0.0), 1.0)
    }

    /// Confidence formatted as a clean percentage string (e.g. `"98.4%"`).
    public var formattedConfidence: String {
        String(format: "%.1f%%", confidence * 100.0)
    }
}

/// A single object detection result with Vision's normalized bottom-left bounding box.
public struct VisionDetection: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let label: String
    public let confidence: Double
    /// Normalized `[0, 1]` bounding box in Vision's bottom-left coordinate space.
    public let normalizedBoundingBox: CGRect

    public init(
        id: UUID = UUID(),
        label: String,
        confidence: Double,
        normalizedBoundingBox: CGRect
    ) {
        self.id = id
        self.label = label
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.normalizedBoundingBox = normalizedBoundingBox
    }

    /// Confidence formatted as a clean percentage string (e.g. `"94.2%"`).
    public var formattedConfidence: String {
        String(format: "%.1f%%", confidence * 100.0)
    }
}

/// Sub-millisecond execution metrics captured during a single Vision + Core ML pass.
public struct InferenceMetrics: Equatable, Sendable {
    public let latencyMilliseconds: Double
    public let computeTarget: ComputeTarget
    public let timestamp: Date

    public init(
        latencyMilliseconds: Double,
        computeTarget: ComputeTarget,
        timestamp: Date = Date()
    ) {
        self.latencyMilliseconds = max(latencyMilliseconds, 0.0)
        self.computeTarget = computeTarget
        self.timestamp = timestamp
    }

    /// Theoretical maximum throughput in frames per second derived from inference latency.
    public var estimatedFPS: Double {
        guard latencyMilliseconds > 0 else { return 0 }
        return 1000.0 / latencyMilliseconds
    }

    /// Formatted latency text (e.g. `"8.4 ms"`).
    public var formattedLatency: String {
        String(format: "%.1f ms", latencyMilliseconds)
    }
}

/// Bundled output and timing telemetry from a single inference run.
public struct VisionInferenceReport<Output: Sendable>: Sendable {
    public let output: Output
    public let metrics: InferenceMetrics

    public init(output: Output, metrics: InferenceMetrics) {
        self.output = output
        self.metrics = metrics
    }
}

/// Errors thrown by `VisionMLEngine`.
public enum VisionMLError: LocalizedError, Sendable {
    case modelInitializationFailed(String)
    case emptyResults
    case unsupportedOutputType

    public var errorDescription: String? {
        switch self {
        case .modelInitializationFailed(let reason):
            return "Failed to initialize VNCoreMLModel: \(reason)"
        case .emptyResults:
            return "Vision returned no observations for the supplied image."
        case .unsupportedOutputType:
            return "The Core ML model output did not produce classification or object detection observations."
        }
    }
}
