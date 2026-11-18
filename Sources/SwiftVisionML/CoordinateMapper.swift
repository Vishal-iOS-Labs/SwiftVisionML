import CoreGraphics
import Foundation

/// How source camera/image content is scaled inside a SwiftUI container.
public enum OverlayContentMode: Sendable, Equatable {
    /// Scales content uniformly so it fills the entire container (cropping overflow, like `AVLayerVideoGravity.resizeAspectFill`).
    case aspectFill
    /// Scales content uniformly so the entire source remains visible inside the container (letterboxing, like `.aspectRatio(contentMode: .fit)`).
    case aspectFit
}

/// Deterministic geometry converter between Vision's normalized bottom-left coordinates
/// and SwiftUI's top-left point coordinate space.
public enum CoordinateMapper {

    /// Converts a normalized Vision bounding box (`origin` at bottom-left, values in `0...1`)
    /// into a SwiftUI `CGRect` (`origin` at top-left, in points).
    ///
    /// - Parameters:
    ///   - visionRect: Normalized `CGRect` from `VNRecognizedObjectObservation.boundingBox`.
    ///   - containerSize: Size of the SwiftUI overlay container in points.
    ///   - contentSize: Optional natural pixel/point size of the underlying image or camera buffer.
    ///     When omitted, the Vision rect maps directly across the full `containerSize`.
    ///   - contentMode: Aspect scaling behavior (`.aspectFill` for camera feeds, `.aspectFit` for photo previews).
    ///   - isMirrored: Pass `true` for front-facing camera previews to mirror horizontally.
    /// - Returns: Converted `CGRect` ready for SwiftUI `frame` / `position` / `Path`.
    public static func swiftUIRect(
        fromVisionRect visionRect: CGRect,
        in containerSize: CGSize,
        contentSize: CGSize? = nil,
        contentMode: OverlayContentMode = .aspectFill,
        isMirrored: Bool = false
    ) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let sourceRect: CGRect
        if let contentSize, contentSize.width > 0, contentSize.height > 0 {
            sourceRect = renderedContentRect(
                contentSize: contentSize,
                in: containerSize,
                mode: contentMode
            )
        } else {
            sourceRect = CGRect(origin: .zero, size: containerSize)
        }

        let normalizedX = isMirrored
            ? (1.0 - visionRect.origin.x - visionRect.size.width)
            : visionRect.origin.x
        let normalizedY = 1.0 - visionRect.origin.y - visionRect.size.height

        return CGRect(
            x: sourceRect.origin.x + normalizedX * sourceRect.size.width,
            y: sourceRect.origin.y + normalizedY * sourceRect.size.height,
            width: visionRect.size.width * sourceRect.size.width,
            height: visionRect.size.height * sourceRect.size.height
        )
    }

    /// Converts a SwiftUI `CGRect` (top-left origin in points) back into Vision's
    /// normalized bottom-left coordinate space (`0...1`).
    public static func visionRect(
        fromSwiftUIRect swiftUIRect: CGRect,
        in containerSize: CGSize
    ) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let normX = swiftUIRect.origin.x / containerSize.width
        let normWidth = swiftUIRect.size.width / containerSize.width
        let normHeight = swiftUIRect.size.height / containerSize.height
        let normY = 1.0 - (swiftUIRect.origin.y / containerSize.height) - normHeight

        return CGRect(x: normX, y: normY, width: normWidth, height: normHeight)
    }

    /// Computes the scaled content frame inside `containerSize` for aspect-fit or aspect-fill.
    public static func renderedContentRect(
        contentSize: CGSize,
        in containerSize: CGSize,
        mode: OverlayContentMode
    ) -> CGRect {
        guard contentSize.width > 0, contentSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let widthRatio = containerSize.width / contentSize.width
        let heightRatio = containerSize.height / contentSize.height

        let scale: CGFloat
        switch mode {
        case .aspectFill:
            scale = max(widthRatio, heightRatio)
        case .aspectFit:
            scale = min(widthRatio, heightRatio)
        }

        let renderedWidth = contentSize.width * scale
        let renderedHeight = contentSize.height * scale
        let originX = (containerSize.width - renderedWidth) / 2.0
        let originY = (containerSize.height - renderedHeight) / 2.0

        return CGRect(x: originX, y: originY, width: renderedWidth, height: renderedHeight)
    }
}
