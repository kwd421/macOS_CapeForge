import AppKit
import CoreGraphics
import Foundation

struct CursorFolderInspectionRow: Equatable {
    let role: CursorRole
    let sourceURL: URL
    let usesArrowFallback: Bool
    let frameCount: Int
    let frameDuration: TimeInterval
    let hotSpot: CGPoint
    let pointSize: CGSize
    let identifiers: [String]
}

struct CursorFolderInspectionReport: Equatable {
    let folderURL: URL
    let rows: [CursorFolderInspectionRow]

    var totalRegisteredIdentifierCount: Int {
        rows.reduce(0) { $0 + $1.identifiers.count }
    }

    var text: String {
        var lines = [
            "FOLDER\t\(folderURL.path)",
            "TOTAL_PRIMARY_ROLES\t\(rows.count)",
            "TOTAL_REGISTERED_IDENTIFIERS\t\(totalRegisteredIdentifierCount)",
            "role\tfile\tframes\tduration\thotspot\tpoints\tfallback\tidentifiers"
        ]
        lines.append(contentsOf: rows.map { row in
            [
                row.role.rawValue,
                row.sourceURL.lastPathComponent,
                "\(row.frameCount)",
                Self.format(row.frameDuration),
                "\(Self.format(row.hotSpot.x)),\(Self.format(row.hotSpot.y))",
                "\(Self.format(row.pointSize.width))x\(Self.format(row.pointSize.height))",
                row.usesArrowFallback ? "arrow-fallback" : "direct",
                row.identifiers.joined(separator: ",")
            ].joined(separator: "\t")
        })
        return lines.joined(separator: "\n")
    }

    func row(for role: CursorRole) -> CursorFolderInspectionRow? {
        rows.first { $0.role == role }
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.4f", value)
    }
}

struct CursorFolderInspector {
    private let resolver = ThemeResolver()
    private let parser = AniParser()
    private let renderer = CursorPayloadRenderer()

    @MainActor
    func inspect(folderURL: URL, sizeMultiplier: Double = 1.0) throws -> CursorFolderInspectionReport {
        let resolved = try resolver.resolveTheme(in: folderURL)
        var parsedAnimationsByURL: [URL: CursorAnimation] = [:]

        func animation(for url: URL) throws -> CursorAnimation {
            let normalizedURL = url.standardizedFileURL
            if let cached = parsedAnimationsByURL[normalizedURL] {
                return cached
            }
            let parsed = try parser.parseCursorFile(at: url)
            parsedAnimationsByURL[normalizedURL] = parsed
            return parsed
        }

        let rows = try CursorRole.allCases.map { role -> CursorFolderInspectionRow in
            guard let sourceURL = resolved.filesByRole[role] else {
                throw CursorError.missingTheme(role.displayName)
            }
            let payload = try renderer.render(animation(for: sourceURL), sizeMultiplier: sizeMultiplier)
            return CursorFolderInspectionRow(
                role: role,
                sourceURL: sourceURL,
                usesArrowFallback: resolved.fallbackRoles.contains(role),
                frameCount: payload.frameCount,
                frameDuration: payload.frameDuration,
                hotSpot: payload.hotSpot,
                pointSize: payload.pointSize,
                identifiers: CursorSlotCatalog.identifiers(for: role)
            )
        }

        return CursorFolderInspectionReport(folderURL: folderURL, rows: rows)
    }
}

struct SystemCursorNameDumpReport: Equatable {
    let names: [String]

    var text: String {
        var lines = [
            "TOTAL_SYSTEM_CURSOR_NAMES\t\(names.count)",
            "ARROW_SYNONYMS\t\(SystemCursorNameCatalog.arrowSynonyms(systemCursorNames: names).joined(separator: ","))",
            "IBEAM_SYNONYMS\t\(SystemCursorNameCatalog.iBeamSynonyms(systemCursorNames: names).joined(separator: ","))",
            "name"
        ]
        lines.append(contentsOf: names)
        return lines.joined(separator: "\n")
    }
}

struct SystemFrameCapProbeReport: Equatable {
    let identifier: String
    let requestedFrameCount: Int
    let renderedFrameCount: Int
    let registeredFrameCount: Int
    let frameDuration: TimeInterval

    var text: String {
        [
            "PROBE_SYSTEM_FRAME_CAP\t\(requestedFrameCount)",
            "IDENTIFIER\t\(identifier)",
            "RENDERED_FRAME_COUNT\t\(renderedFrameCount)",
            "REGISTERED_FRAME_COUNT\t\(registeredFrameCount)",
            "FRAME_DURATION\t\(Self.format(frameDuration))"
        ].joined(separator: "\n")
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.4f", value)
    }
}

struct SystemFrameCapProbe {
    private static let maximumProbeFrameCount = 60

    @MainActor
    func run(frameCount: Int) throws -> SystemFrameCapProbeReport {
        guard (1...Self.maximumProbeFrameCount).contains(frameCount) else {
            throw CursorError.systemCursorApplyFailed(
                "Probe frame count out of range [1...\(Self.maximumProbeFrameCount)]: \(frameCount)"
            )
        }

        let identifier = "local.capeforge.probe.framecap.\(frameCount).\(UUID().uuidString.lowercased())"
        let bridge = try PrivateSystemCursorBridge()
        let payload = try probePayload(frameCount: frameCount)
        try bridge.registerProbePayload(payload, identifier: identifier)
        defer { try? bridge.removeRegisteredCursor(named: identifier) }

        guard let registeredPayload = bridge.registeredPayload(for: identifier) else {
            throw CursorError.systemCursorApplyFailed("Could not read back probe cursor \(identifier)")
        }

        return SystemFrameCapProbeReport(
            identifier: identifier,
            requestedFrameCount: frameCount,
            renderedFrameCount: payload.frameCount,
            registeredFrameCount: registeredPayload.frameCount,
            frameDuration: registeredPayload.frameDuration
        )
    }

    @MainActor
    private func probePayload(frameCount: Int) throws -> RenderedCursorPayload {
        let frameDuration = 1.0 / Double(frameCount)
        let frames = (0..<frameCount).map { index in
            CursorFrame(image: probeImage(index: index), delay: frameDuration)
        }

        let frameSize = CGSize(width: 16, height: 16)
        guard
            let stacked = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(frameSize.width),
                pixelsHigh: Int(frameSize.height) * frameCount,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: stacked)
        else {
            throw CursorError.unsupportedCursorPayload
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.clear(
            CGRect(
                x: 0,
                y: 0,
                width: frameSize.width,
                height: frameSize.height * Double(frameCount)
            )
        )
        var currentY = 0.0
        for frame in frames.reversed() {
            frame.image.draw(in: NSRect(x: 0, y: currentY, width: frameSize.width, height: frameSize.height))
            currentY += frameSize.height
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let representation = stacked.representation(using: .png, properties: [:]) else {
            throw CursorError.unsupportedCursorPayload
        }

        return RenderedCursorPayload(
            frameCount: frameCount,
            frameDuration: frameDuration,
            hotSpot: CGPoint(x: 1, y: 1),
            pointSize: frameSize,
            representations: [representation]
        )
    }

    @MainActor
    private func probeImage(index: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor(
            calibratedHue: CGFloat(index % 60) / 60.0,
            saturation: 0.85,
            brightness: 0.95,
            alpha: 1.0
        ).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
        image.unlockFocus()
        return image
    }
}

enum CursorCommandLine {
    @MainActor
    static func run(arguments: [String] = CommandLine.arguments) -> Int32? {
        do {
            if arguments.contains("--dump-system-cursor-names") {
                let names = try PrivateSystemCursorBridge().systemDefinedCursorNames()
                print(SystemCursorNameDumpReport(names: names).text)
                return EXIT_SUCCESS
            }

            if let folderPath = value(after: "--verify-cursor-folder", in: arguments) {
                let report = try CursorFolderInspector().inspect(folderURL: URL(fileURLWithPath: folderPath, isDirectory: true))
                print(report.text)
                return EXIT_SUCCESS
            }

            if let frameCountValue = value(after: "--probe-system-frame-cap", in: arguments) {
                guard let frameCount = Int(frameCountValue) else {
                    throw CursorError.systemCursorApplyFailed("Invalid frame count: \(frameCountValue)")
                }
                let report = try SystemFrameCapProbe().run(frameCount: frameCount)
                print(report.text)
                return EXIT_SUCCESS
            }

            if let folderPath = value(after: "--apply-cursor-folder", in: arguments) {
                try applyCursorFolder(URL(fileURLWithPath: folderPath, isDirectory: true))
                print("APPLIED_SYSTEM_CURSORS\t\(folderPath)")
                return EXIT_SUCCESS
            }

            return nil
        } catch {
            fputs("Cursie command failed: \(error.localizedDescription)\n", stderr)
            return EXIT_FAILURE
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else {
            return nil
        }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return arguments[valueIndex]
    }

    @MainActor
    private static func applyCursorFolder(_ folderURL: URL) throws {
        let resolved = try ThemeResolver().resolveTheme(in: folderURL)
        let parser = AniParser()
        var animations: [CursorRole: CursorAnimation] = [:]
        var parsedAnimationsByURL: [URL: CursorAnimation] = [:]

        func animation(for url: URL) throws -> CursorAnimation {
            let normalizedURL = url.standardizedFileURL
            if let cached = parsedAnimationsByURL[normalizedURL] {
                return cached
            }
            let parsed = try parser.parseCursorFile(at: url)
            parsedAnimationsByURL[normalizedURL] = parsed
            return parsed
        }

        for role in CursorRole.allCases {
            guard let fileURL = resolved.filesByRole[role] else {
                continue
            }
            animations[role] = try animation(for: fileURL)
        }

        guard let executableURL = Bundle.main.executableURL else {
            throw CursorError.systemCursorApplyFailed(Localized.string("error.systemApplyExecutableMissing"))
        }

        try CursorSystemApplyService().apply(
            theme: CursorTheme(animations: animations),
            sizeMultiplier: 1.0,
            author: NSUserName(),
            bundleIdentifier: Bundle.main.bundleIdentifier,
            executableURL: executableURL
        )
    }
}
