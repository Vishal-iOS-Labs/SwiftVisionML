import SwiftUI

/// Drop-in SwiftUI overlay that maps Vision object detections into screen coordinates
/// with smooth spring-animated bounding boxes and confidence badges.
public struct DetectionOverlayView: View {
    public let detections: [VisionDetection]
    public let contentSize: CGSize?
    public let contentMode: OverlayContentMode
    public let isMirrored: Bool
    public let accentColor: Color

    public init(
        detections: [VisionDetection],
        contentSize: CGSize? = nil,
        contentMode: OverlayContentMode = .aspectFill,
        isMirrored: Bool = false,
        accentColor: Color = .cyan
    ) {
        self.detections = detections
        self.contentSize = contentSize
        self.contentMode = contentMode
        self.isMirrored = isMirrored
        self.accentColor = accentColor
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(detections) { detection in
                    let rect = CoordinateMapper.swiftUIRect(
                        fromVisionRect: detection.normalizedBoundingBox,
                        in: proxy.size,
                        contentSize: contentSize,
                        contentMode: contentMode,
                        isMirrored: isMirrored
                    )

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(accentColor, lineWidth: 2.5)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(accentColor.opacity(0.12))
                            )
                            .frame(width: rect.width, height: rect.height)

                        Text("\(detection.label) · \(detection.formattedConfidence)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accentColor.gradient, in: Capsule())
                            .offset(y: -24)
                    }
                    .offset(x: rect.minX, y: rect.minY)
                    .animation(.spring(response: 0.22, dampingFraction: 0.85), value: rect)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
}

/// Compact glassmorphic SwiftUI telemetry pill displaying live on-device inference speed.
public struct InferenceMetricsHUD: View {
    public let metrics: InferenceMetrics

    public init(metrics: InferenceMetrics) {
        self.metrics = metrics
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(metrics.formattedLatency)
                .font(.caption.monospacedDigit().weight(.semibold))

            Text("·")
                .foregroundStyle(.secondary)

            Text("\(Int(metrics.estimatedFPS.rounded())) FPS")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(metrics.computeTarget.shortBadge)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch metrics.latencyMilliseconds {
        case ..<16.7:
            return .green
        case 16.7..<33.4:
            return .yellow
        default:
            return .orange
        }
    }
}
