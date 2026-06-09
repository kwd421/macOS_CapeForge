import AppKit
import Foundation
import Testing
@testable import Cursie

struct CursorCommandLineTests {
    @Test
    func systemCursorNameDumpShowsDiscoveredSynonymGroups() {
        let report = SystemCursorNameDumpReport(names: [
            "com.apple.tahoe.cursor.Arrow",
            "com.apple.tahoe.cursor.IBeam",
            "com.apple.cursor.unrelated"
        ])

        #expect(report.text.contains("TOTAL_SYSTEM_CURSOR_NAMES\t3"))
        #expect(report.text.contains("ARROW_SYNONYMS\tcom.apple.coregraphics.Arrow,com.apple.coregraphics.ArrowCtx,com.apple.tahoe.cursor.Arrow"))
        #expect(report.text.contains("IBEAM_SYNONYMS\tcom.apple.coregraphics.IBeam,com.apple.coregraphics.IBeamXOR,com.apple.tahoe.cursor.IBeam"))
    }

    @Test
    func systemFrameCapProbeReportShowsRenderedAndRegisteredFrameCounts() {
        let report = SystemFrameCapProbeReport(
            identifier: "local.capeforge.probe.framecap.24.test",
            requestedFrameCount: 24,
            renderedFrameCount: 24,
            registeredFrameCount: 24,
            frameDuration: 1.0 / 24.0
        )

        #expect(report.text.contains("PROBE_SYSTEM_FRAME_CAP\t24"))
        #expect(report.text.contains("RENDERED_FRAME_COUNT\t24"))
        #expect(report.text.contains("REGISTERED_FRAME_COUNT\t24"))
    }

    @MainActor
    @Test
    func folderInspectionReportsEveryPrimaryRoleAndRegistrationIdentifier() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let folder = tempDirectory.appendingPathComponent("Theme", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try makeCursorFile(color: .white, size: 16, at: folder.appendingPathComponent("Normal.cur"))
        try makeCursorFile(color: .red, size: 17, at: folder.appendingPathComponent("Text.cur"))
        try makeCursorFile(color: .blue, size: 18, at: folder.appendingPathComponent("Diagonal1.cur"))
        try makeCursorFile(color: .green, size: 19, at: folder.appendingPathComponent("Diagonal2.cur"))

        let report = try CursorFolderInspector().inspect(folderURL: folder)

        #expect(report.rows.map(\.role) == CursorRole.allCases)
        #expect(report.totalRegisteredIdentifierCount == 35)
        #expect(report.row(for: .arrow)?.sourceURL.lastPathComponent == "Normal.cur")
        #expect(report.row(for: .text)?.sourceURL.lastPathComponent == "Text.cur")
        #expect(report.row(for: .diagonalResizeNWSE)?.identifiers == [
            "com.apple.cursor.33",
            "com.apple.cursor.34",
            "com.apple.cursor.35"
        ])
        #expect(report.row(for: .diagonalResizeNESW)?.identifiers == [
            "com.apple.cursor.29",
            "com.apple.cursor.30",
            "com.apple.cursor.37"
        ])
        #expect(report.text.contains("TOTAL_PRIMARY_ROLES\t17"))
        #expect(report.text.contains("TOTAL_REGISTERED_IDENTIFIERS\t35"))
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeCursorFile(color: NSColor, size: Int, at url: URL) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    color.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw CursorError.unsupportedCursorPayload
    }

    var data = Data()
    data.append(contentsOf: [0x00, 0x00])
    data.append(contentsOf: [0x02, 0x00])
    data.append(contentsOf: [0x01, 0x00])
    data.append(UInt8(size == 256 ? 0 : size))
    data.append(UInt8(size == 256 ? 0 : size))
    data.append(0x00)
    data.append(0x00)
    data.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: UInt32(pngData.count).littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: UInt32(22).littleEndian, Array.init))
    data.append(pngData)
    try data.write(to: url)
}
