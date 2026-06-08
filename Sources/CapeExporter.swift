import AppKit
import Foundation

struct CapeExporter {
    static let cursorRepresentationScales = [2.0, 5.0, 10.0]

    struct ExportMetrics: Equatable {
        let baseScale: Double
        let targetPixelWidth: Int
        let targetPixelHeight: Int
        let pointsWidth: Double
        let pointsHeight: Double
        let hotspotX: Double
        let hotspotY: Double
    }

    func exportCape(
        name: String,
        author: String,
        identifier: String,
        theme: CursorTheme,
        sizeMultiplier: Double = 1.0,
        to url: URL
    ) throws {
        let cape = try CursorCapeBuilder().makeCape(
            name: name,
            author: author,
            identifier: identifier,
            theme: theme,
            sizeMultiplier: sizeMultiplier
        )
        let data = try PropertyListSerialization.data(fromPropertyList: cape, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }

    static func previewDisplaySize(for animation: CursorAnimation, sizeMultiplier: Double) -> CGSize {
        let metrics = previewMetrics(for: animation, sizeMultiplier: sizeMultiplier)
        return CGSize(width: metrics.pointsWidth, height: metrics.pointsHeight)
    }

    static func previewHotspot(for animation: CursorAnimation, sizeMultiplier: Double) -> CGPoint {
        let metrics = previewMetrics(for: animation, sizeMultiplier: sizeMultiplier)
        return CGPoint(x: metrics.hotspotX, y: metrics.hotspotY)
    }

    private static func previewMetrics(for animation: CursorAnimation, sizeMultiplier: Double) -> ExportMetrics {
        let metrics = exportMetrics(
            basePixelWidth: max(Int(animation.canvasSize.width.rounded(.up)), 1),
            basePixelHeight: max(Int(animation.canvasSize.height.rounded(.up)), 1),
            hotspot: animation.hotspot,
            sizeMultiplier: sizeMultiplier
        )
        return metrics
    }

    static func exportMetrics(
        basePixelWidth: Int,
        basePixelHeight: Int,
        hotspot: CGPoint,
        sizeMultiplier: Double
    ) -> ExportMetrics {
        exportMetrics(
            basePixelWidth: basePixelWidth,
            basePixelHeight: basePixelHeight,
            hotspot: hotspot,
            sizeMultiplier: sizeMultiplier,
            outputScale: max(suggestedScale(for: CGSize(width: basePixelWidth, height: basePixelHeight)), 2.0)
        )
    }

    static func exportMetrics(
        basePixelWidth: Int,
        basePixelHeight: Int,
        hotspot: CGPoint,
        sizeMultiplier: Double,
        outputScale: Double
    ) -> ExportMetrics {
        let multiplier = min(max(sizeMultiplier, 1.0), 3.0)
        let sourceScale = suggestedScale(for: CGSize(width: basePixelWidth, height: basePixelHeight))
        let outputScale = max(outputScale, 1.0)
        let logicalWidth = Double(basePixelWidth) / sourceScale
        let logicalHeight = Double(basePixelHeight) / sourceScale
        let targetPixelWidth = max(Int((logicalWidth * multiplier * outputScale).rounded(.up)), 1)
        let targetPixelHeight = max(Int((logicalHeight * multiplier * outputScale).rounded(.up)), 1)
        let logicalHotspotX = Double(hotspot.x) / sourceScale
        let logicalHotspotY = Double(hotspot.y) / sourceScale
        return ExportMetrics(
            baseScale: outputScale,
            targetPixelWidth: targetPixelWidth,
            targetPixelHeight: targetPixelHeight,
            pointsWidth: Double(targetPixelWidth) / outputScale,
            pointsHeight: Double(targetPixelHeight) / outputScale,
            hotspotX: logicalHotspotX * multiplier,
            hotspotY: logicalHotspotY * multiplier
        )
    }

    private static func suggestedScale(for pixelSize: CGSize) -> Double {
        pixelSize.width >= 64 || pixelSize.height >= 64 ? 2.0 : 1.0
    }
}
