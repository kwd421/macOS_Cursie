import AppKit
import Foundation
import ImageIO

struct AniParser {
    static let maximumFileSize = 32 * 1_024 * 1_024
    static let maximumSourceFrameCount = 512
    static let maximumCursorRepresentationCount = 64
    static let maximumFrameDimension = 512

    func parseCursorFile(at url: URL) throws -> CursorAnimation {
        switch url.pathExtension.lowercased() {
        case "ani":
            return try parseANI(at: url)
        case "cur":
            let data = try readCursorData(at: url)
            return try parseCUR(data: data)
        default:
            throw CursorError.invalidANI(Localized.string("error.unsupportedExtension", url.pathExtension))
        }
    }

    func parseANI(at url: URL) throws -> CursorAnimation {
        let data = try readCursorData(at: url)
        return try parseANI(data: data)
    }

    func parseANI(data: Data) throws -> CursorAnimation {
        try validateFileSize(data.count)
        guard data.count >= 12, data[0..<4] == Data("RIFF".utf8), data[8..<12] == Data("ACON".utf8) else {
            throw CursorError.invalidANI(Localized.string("error.invalidRiffAconHeader"))
        }

        var defaultJiffies = 6
        var rateJiffies: [Int] = []
        var sequence: [Int] = []
        var cursorChunks: [Data] = []
        var offset = 12

        while offset + 8 <= data.count {
            let chunkID = fourCC(data, offset)
            let chunkSize = Int(readUInt32LE(data, offset + 4))
            let chunkDataStart = offset + 8
            let chunkDataEnd = chunkDataStart + chunkSize
            guard chunkDataEnd <= data.count else {
                throw CursorError.invalidANI(Localized.string("error.invalidChunkLength"))
            }

            if chunkID == "anih", chunkSize >= 36 {
                defaultJiffies = Int(readUInt32LE(data, chunkDataStart + 28))
            } else if chunkID == "LIST", chunkSize >= 4 {
                let listType = fourCC(data, chunkDataStart)
                if listType == "fram" {
                    cursorChunks.append(contentsOf: try extractIconChunks(from: Data(data[chunkDataStart + 4..<chunkDataEnd])))
                }
            } else if chunkID == "rate", chunkSize >= 4 {
                guard chunkSize / 4 <= Self.maximumSourceFrameCount else {
                    throw CursorError.invalidANI(Localized.string("error.cursorTooManyFrames", Self.maximumSourceFrameCount))
                }
                rateJiffies = readUInt32List(data, start: chunkDataStart, byteCount: chunkSize).map(Int.init)
            } else if chunkID == "seq ", chunkSize >= 4 {
                guard chunkSize / 4 <= Self.maximumSourceFrameCount else {
                    throw CursorError.invalidANI(Localized.string("error.cursorTooManyFrames", Self.maximumSourceFrameCount))
                }
                sequence = readUInt32List(data, start: chunkDataStart, byteCount: chunkSize).map(Int.init)
            }

            offset = chunkDataEnd + (chunkSize & 1)
        }

        let stepFrameIndices = sequence.isEmpty ? Array(cursorChunks.indices) : sequence
        guard stepFrameIndices.count <= Self.maximumSourceFrameCount else {
            throw CursorError.invalidANI(Localized.string("error.cursorTooManyFrames", Self.maximumSourceFrameCount))
        }
        let frames = try stepFrameIndices.enumerated().map { stepIndex, frameIndex in
            guard cursorChunks.indices.contains(frameIndex) else {
                throw CursorError.invalidANI("Invalid ANI sequence index.")
            }
            let frameJiffies = rateJiffies.indices.contains(stepIndex) ? rateJiffies[stepIndex] : defaultJiffies
            return try autoreleasepool {
                try decodeFrame(from: cursorChunks[frameIndex], defaultDelay: TimeInterval(max(frameJiffies, 1)) / 60.0)
            }
        }
        guard let first = frames.first else {
            throw CursorError.invalidANI(Localized.string("error.noFrames"))
        }

        return CursorAnimation(
            frames: frames.map { CursorFrame(image: $0.image, delay: $0.delay) },
            hotspot: first.hotspot,
            canvasSize: first.size
        )
    }

    func parseCUR(data: Data) throws -> CursorAnimation {
        try validateFileSize(data.count)
        let frame = try decodeFrame(from: data, defaultDelay: 1.0)
        return CursorAnimation(
            frames: [CursorFrame(image: frame.image, delay: 1.0)],
            hotspot: frame.hotspot,
            canvasSize: frame.size
        )
    }

    private func extractIconChunks(from data: Data) throws -> [Data] {
        var chunks: [Data] = []
        var offset = data.startIndex
        while offset + 8 <= data.endIndex {
            let chunkID = fourCC(data, offset)
            let chunkSize = Int(readUInt32LE(data, offset + 4))
            let start = offset + 8
            let end = start + chunkSize
            guard end <= data.endIndex else {
                throw CursorError.invalidANI(Localized.string("error.invalidIconChunkLength"))
            }
            if chunkID == "icon" {
                chunks.append(data[start..<end])
                guard chunks.count <= Self.maximumSourceFrameCount else {
                    throw CursorError.invalidANI(Localized.string("error.cursorTooManyFrames", Self.maximumSourceFrameCount))
                }
            }
            offset = end + (chunkSize & 1)
        }
        return chunks
    }

    private func decodeFrame(from data: Data, defaultDelay: TimeInterval) throws -> (image: NSImage, hotspot: CGPoint, size: CGSize, delay: TimeInterval) {
        let data = Data(data)
        guard data.count >= 22 else {
            throw CursorError.invalidANI(Localized.string("error.curTooShort"))
        }
        let type = readUInt16LE(data, 2)
        let count = Int(readUInt16LE(data, 4))
        guard type == 2, count >= 1 else {
            throw CursorError.invalidANI(Localized.string("error.invalidCurHeader"))
        }

        guard count <= Self.maximumCursorRepresentationCount, 6 + (count * 16) <= data.count else {
            throw CursorError.invalidANI(Localized.string("error.invalidCurHeader"))
        }

        let entries = try (0..<count).map { index in
            try cursorEntry(in: data, at: 6 + (index * 16))
        }
        guard let selectedEntry = entries.max(by: { lhs, rhs in
            let lhsArea = lhs.width * lhs.height
            let rhsArea = rhs.width * rhs.height
            if lhsArea == rhsArea {
                return lhs.imageBytes < rhs.imageBytes
            }
            return lhsArea < rhsArea
        }) else {
            throw CursorError.invalidANI(Localized.string("error.invalidCurHeader"))
        }

        let imagePayload = Data(data[selectedEntry.imageOffset..<(selectedEntry.imageOffset + selectedEntry.imageBytes)])
        try validateEncodedImageDimensions(imagePayload)
        let selectedCursorData = singleEntryCursorData(entry: selectedEntry, payload: imagePayload)
        guard let image = NSImage(data: selectedCursorData) ?? NSImage(data: imagePayload) else {
            throw CursorError.unsupportedCursorPayload
        }

        let rep = image.representations.compactMap { $0 as? NSBitmapImageRep }.max {
            ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh)
        }
        let width = rep?.pixelsWide ?? selectedEntry.width
        let height = rep?.pixelsHigh ?? selectedEntry.height
        guard width <= Self.maximumFrameDimension, height <= Self.maximumFrameDimension else {
            throw CursorError.invalidANI(Localized.string("error.cursorDimensionsTooLarge", Self.maximumFrameDimension))
        }

        return (
            image: image,
            hotspot: CGPoint(x: selectedEntry.hotspotX, y: selectedEntry.hotspotY),
            size: CGSize(width: width, height: height),
            delay: defaultDelay
        )
    }

    private struct CursorEntry {
        let directoryData: Data
        let width: Int
        let height: Int
        let hotspotX: Int
        let hotspotY: Int
        let imageBytes: Int
        let imageOffset: Int
    }

    private func cursorEntry(in data: Data, at offset: Int) throws -> CursorEntry {
        let width = data[offset] == 0 ? 256 : Int(data[offset])
        let height = data[offset + 1] == 0 ? 256 : Int(data[offset + 1])
        let imageBytes = Int(readUInt32LE(data, offset + 8))
        let imageOffset = Int(readUInt32LE(data, offset + 12))
        guard imageBytes > 0, imageOffset >= 0, imageOffset + imageBytes <= data.count else {
            throw CursorError.invalidANI(Localized.string("error.invalidCurEmbeddedRange"))
        }
        guard width <= Self.maximumFrameDimension, height <= Self.maximumFrameDimension else {
            throw CursorError.invalidANI(Localized.string("error.cursorDimensionsTooLarge", Self.maximumFrameDimension))
        }
        return CursorEntry(
            directoryData: Data(data[offset..<(offset + 16)]),
            width: width,
            height: height,
            hotspotX: Int(readUInt16LE(data, offset + 4)),
            hotspotY: Int(readUInt16LE(data, offset + 6)),
            imageBytes: imageBytes,
            imageOffset: imageOffset
        )
    }

    private func singleEntryCursorData(entry: CursorEntry, payload: Data) -> Data {
        var data = Data([0x00, 0x00, 0x02, 0x00, 0x01, 0x00])
        var directoryData = entry.directoryData
        let offset = UInt32(22).littleEndian
        directoryData.replaceSubrange(12..<16, with: withUnsafeBytes(of: offset, Array.init))
        data.append(directoryData)
        data.append(payload)
        return data
    }

    private func readCursorData(at url: URL) throws -> Data {
        if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            try validateFileSize(fileSize)
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        try validateFileSize(data.count)
        return data
    }

    private func validateFileSize(_ byteCount: Int) throws {
        guard byteCount <= Self.maximumFileSize else {
            throw CursorError.invalidANI(Localized.string("error.cursorFileTooLarge", Self.maximumFileSize / 1_024 / 1_024))
        }
    }

    private func validateEncodedImageDimensions(_ data: Data) throws {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return
        }
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard width <= Self.maximumFrameDimension, height <= Self.maximumFrameDimension else {
            throw CursorError.invalidANI(Localized.string("error.cursorDimensionsTooLarge", Self.maximumFrameDimension))
        }
    }

    private func fourCC(_ data: Data, _ offset: Int) -> String {
        String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
    }

    private func readUInt16LE(_ data: Data, _ offset: Int) -> UInt16 {
        let range = offset..<(offset + 2)
        return data.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.baseAddress!.advanced(by: range.lowerBound)
            return base.loadUnaligned(as: UInt16.self).littleEndian
        }
    }

    private func readUInt32LE(_ data: Data, _ offset: Int) -> UInt32 {
        let range = offset..<(offset + 4)
        return data.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.baseAddress!.advanced(by: range.lowerBound)
            return base.loadUnaligned(as: UInt32.self).littleEndian
        }
    }

    private func readUInt32List(_ data: Data, start: Int, byteCount: Int) -> [UInt32] {
        let count = byteCount / 4
        return (0..<count).map { readUInt32LE(data, start + ($0 * 4)) }
    }
}
