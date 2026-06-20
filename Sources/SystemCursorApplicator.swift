import AppKit
import CoreGraphics
import Foundation
import ImageIO

enum CursorSlotCatalog {
    static let defaultRegisteredCursorIdentifiers = [
        "com.apple.coregraphics.Arrow",
        "com.apple.coregraphics.IBeam",
        "com.apple.coregraphics.IBeamXOR",
        "com.apple.coregraphics.Alias",
        "com.apple.coregraphics.Copy",
        "com.apple.coregraphics.Move",
        "com.apple.coregraphics.ArrowCtx",
        "com.apple.coregraphics.Wait",
        "com.apple.coregraphics.Empty"
    ]

    private static let primaryIdentifiers: [CursorRole: [String]] = [
        .arrow: ["com.apple.coregraphics.Arrow"],
        .text: ["com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamXOR"],
        .link: ["com.apple.cursor.2", "com.apple.cursor.13"],
        .location: ["com.apple.coregraphics.Copy", "com.apple.cursor.5"],
        .precision: ["com.apple.cursor.7", "com.apple.cursor.8"],
        .move: ["com.apple.coregraphics.Move"],
        .unavailable: ["com.apple.cursor.3"],
        .busy: ["com.apple.cursor.4"],
        .working: ["com.apple.coregraphics.Wait"],
        .help: ["com.apple.cursor.40"],
        .handwriting: ["com.apple.cursor.20"],
        .person: ["com.apple.cursor.41"],
        .alternate: ["com.apple.coregraphics.Alias"],
        .verticalResize: ["com.apple.cursor.21", "com.apple.cursor.22", "com.apple.cursor.23", "com.apple.cursor.31", "com.apple.cursor.32", "com.apple.cursor.36"],
        .horizontalResize: ["com.apple.cursor.17", "com.apple.cursor.18", "com.apple.cursor.19", "com.apple.cursor.27", "com.apple.cursor.28", "com.apple.cursor.38"],
        .diagonalResizeNWSE: ["com.apple.cursor.33", "com.apple.cursor.34", "com.apple.cursor.35"],
        .diagonalResizeNESW: ["com.apple.cursor.29", "com.apple.cursor.30", "com.apple.cursor.37"]
    ]

    private static let supplementalIdentifiers: [SupplementalCursorRole: [String]] = [
        .contextualMenu: ["com.apple.coregraphics.ArrowCtx"],
        .contextMenuLegacy: ["com.apple.cursor.24"],
        .dragCopy: ["com.apple.coregraphics.CopyDrag"],
        .dragLink: ["com.apple.coregraphics.LinkDrag"],
        .disappearingItem: ["com.apple.coregraphics.DisappearingItem"],
        .empty: ["com.apple.coregraphics.Empty"],
        .camera: ["com.apple.cursor.10"],
        .camera2: ["com.apple.cursor.9"],
        .iBeamHorizontal: ["com.apple.cursor.26"],
        .countingUp: ["com.apple.cursor.14"],
        .countingDown: ["com.apple.cursor.15"],
        .countingUpDown: ["com.apple.cursor.16"],
        .closeHand: ["com.apple.cursor.11"],
        .openHand: ["com.apple.cursor.12"],
        .poof: ["com.apple.cursor.25"],
        .resizeSquare: ["com.apple.cursor.39"],
        .resizeUp: ["com.apple.coregraphics.ResizeUp"],
        .resizeDown: ["com.apple.coregraphics.ResizeDown"],
        .resizeLeft: ["com.apple.coregraphics.ResizeLeft"],
        .resizeRight: ["com.apple.coregraphics.ResizeRight"],
        .verticalIBeam: ["com.apple.coregraphics.IBeamForVerticalLayout"],
        .zoomIn: ["com.apple.cursor.42"],
        .zoomOut: ["com.apple.cursor.43"]
    ]

    static func identifiers(for role: CursorRole) -> [String] {
        primaryIdentifiers[role] ?? []
    }

    static func identifiers(for role: SupplementalCursorRole) -> [String] {
        supplementalIdentifiers[role] ?? []
    }

    static var orderedRegistrationIdentifiers: [String] {
        var identifiers: [String] = []
        for role in CursorRole.allCases {
            identifiers.append(contentsOf: Self.identifiers(for: role))
        }
        for role in SupplementalCursorRole.allCases {
            identifiers.append(contentsOf: Self.identifiers(for: role))
        }
        return identifiers
    }
}

enum SystemCursorNameCatalog {
    private static let legacyArrowSynonyms = [
        "com.apple.coregraphics.Arrow",
        "com.apple.coregraphics.ArrowCtx"
    ]
    private static let legacyIBeamSynonyms = [
        "com.apple.coregraphics.IBeam",
        "com.apple.coregraphics.IBeamXOR"
    ]

    static func arrowSynonyms(systemCursorNames: [String]) -> [String] {
        synonyms(
            legacy: legacyArrowSynonyms,
            systemCursorNames: systemCursorNames,
            matching: "arrow"
        )
    }

    static func iBeamSynonyms(systemCursorNames: [String]) -> [String] {
        synonyms(
            legacy: legacyIBeamSynonyms,
            systemCursorNames: systemCursorNames,
            matching: "ibeam"
        )
    }

    static func backupTargets(systemCursorNames: [String]) -> [String] {
        unique(
            CursorSlotCatalog.defaultRegisteredCursorIdentifiers +
                arrowSynonyms(systemCursorNames: systemCursorNames) +
                iBeamSynonyms(systemCursorNames: systemCursorNames)
        )
    }

    static func explicitRemovalTargets(systemCursorNames: [String]) -> [String] {
        let backedUpTargets = Set(backupTargets(systemCursorNames: systemCursorNames))
        return unique(CursorSlotCatalog.orderedRegistrationIdentifiers).filter {
            !backedUpTargets.contains($0)
        }
    }

    private static func synonyms(
        legacy: [String],
        systemCursorNames: [String],
        matching needle: String
    ) -> [String] {
        unique(
            legacy + systemCursorNames.filter {
                $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        )
    }

    static func coreCursorID(from identifier: String) -> Int32? {
        let prefix = "com.apple.cursor."
        guard identifier.hasPrefix(prefix) else { return nil }
        return Int32(identifier.dropFirst(prefix.count))
    }

    private static func unique(_ identifiers: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for identifier in identifiers where !identifier.isEmpty {
            guard seen.insert(identifier).inserted else { continue }
            result.append(identifier)
        }
        return result
    }
}

struct RenderedCursorPayload: Equatable, Sendable {
    let frameCount: Int
    let frameDuration: Double
    let hotSpot: CGPoint
    let pointSize: CGSize
    let representations: [Data]
}

struct CursorRegistration: Equatable, Sendable {
    let identifier: String
    let payload: RenderedCursorPayload
}

enum SystemCursorFrameLimit {
    static let maximumRegisteredFrameCount = 24

    static func contains(_ frameCount: Int) -> Bool {
        (1...maximumRegisteredFrameCount).contains(frameCount)
    }
}

struct CursorApplyPlan: Equatable, Sendable {
    let cursors: [CursorRegistration]

    init(cursors: [CursorRegistration]) {
        self.cursors = cursors
    }

    init(cape: [String: Any]) throws {
        guard let cursors = cape["Cursors"] as? [String: Any] else {
            throw CursorError.invalidThemeSelection(Localized.string("error.noCursorsToExport"))
        }

        let orderedIdentifiers = CursorSlotCatalog.orderedRegistrationIdentifiers.filter { cursors[$0] != nil }
        let unknownIdentifiers = cursors.keys
            .filter { !CursorSlotCatalog.orderedRegistrationIdentifiers.contains($0) }
            .sorted()

        self.cursors = try (orderedIdentifiers + unknownIdentifiers).map { identifier in
            guard
                let dictionary = cursors[identifier] as? [String: Any],
                let frameCount = dictionary["FrameCount"] as? Int,
                let frameDuration = dictionary["FrameDuration"] as? Double,
                let hotSpotX = dictionary["HotSpotX"] as? Double,
                let hotSpotY = dictionary["HotSpotY"] as? Double,
                let pointsWide = dictionary["PointsWide"] as? Double,
                let pointsHigh = dictionary["PointsHigh"] as? Double,
                let representations = dictionary["Representations"] as? [Data]
            else {
                throw CursorError.unsupportedCursorPayload
            }

            return CursorRegistration(
                identifier: identifier,
                payload: RenderedCursorPayload(
                    frameCount: frameCount,
                    frameDuration: frameDuration,
                    hotSpot: CGPoint(x: hotSpotX, y: hotSpotY),
                    pointSize: CGSize(width: pointsWide, height: pointsHigh),
                    representations: representations
                )
            )
        }
    }
}

struct CursorPayloadRenderer {
    func render(_ animation: CursorAnimation, sizeMultiplier: Double) throws -> RenderedCursorPayload {
        let exportAnimation = animationForExport(animation)
        let renderedFrames = try exportAnimation.frames.map { frame in
            try autoreleasepool {
                try bitmapRep(for: frame.image, canvasSize: exportAnimation.canvasSize)
            }
        }

        let basePixelWidth = renderedFrames.map(\.pixelsWide).max() ?? 1
        let basePixelHeight = renderedFrames.map(\.pixelsHigh).max() ?? 1
        let metrics = CapeExporter.exportMetrics(
            basePixelWidth: basePixelWidth,
            basePixelHeight: basePixelHeight,
            hotspot: exportAnimation.hotspot,
            sizeMultiplier: sizeMultiplier
        )
        let representations = try CapeExporter.cursorRepresentationScales.map { outputScale in
            let representationMetrics = CapeExporter.exportMetrics(
                basePixelWidth: basePixelWidth,
                basePixelHeight: basePixelHeight,
                hotspot: exportAnimation.hotspot,
                sizeMultiplier: sizeMultiplier,
                outputScale: outputScale
            )
            let scaledFrames = try renderedFrames.map { frame in
                try autoreleasepool {
                    try scaledBitmapRep(
                        for: frame,
                        width: representationMetrics.targetPixelWidth,
                        height: representationMetrics.targetPixelHeight
                    )
                }
            }

            let stacked = try stack(
                frames: scaledFrames,
                width: representationMetrics.targetPixelWidth,
                height: representationMetrics.targetPixelHeight
            )
            guard let representation = stacked.representation(using: .png, properties: [:]) else {
                throw CursorError.unsupportedCursorPayload
            }
            return representation
        }

        return RenderedCursorPayload(
            frameCount: exportAnimation.frames.count,
            frameDuration: exportAnimation.frames.first?.delay ?? 1.0,
            hotSpot: CGPoint(x: metrics.hotspotX, y: metrics.hotspotY),
            pointSize: CGSize(width: metrics.pointsWidth, height: metrics.pointsHeight),
            representations: representations
        )
    }

    private func animationForExport(_ animation: CursorAnimation) -> CursorAnimation {
        guard animation.frames.count > SystemCursorFrameLimit.maximumRegisteredFrameCount else {
            return animation
        }

        return downsampleAnimation(animation, maxFrames: SystemCursorFrameLimit.maximumRegisteredFrameCount)
    }

    private func downsampleAnimation(_ animation: CursorAnimation, maxFrames: Int) -> CursorAnimation {
        guard animation.frames.count > maxFrames, maxFrames > 0 else {
            return animation
        }

        let sourceFrames = animation.frames
        let sourceDurations = sourceFrames.map { max($0.delay, 0) }
        let totalDuration = sourceDurations.reduce(0.0, +)
        guard totalDuration > 0 else {
            return downsampleAnimationByIndex(animation, maxFrames: maxFrames)
        }
        let targetDelay = totalDuration / Double(maxFrames)
        var reducedFrames: [CursorFrame] = []
        reducedFrames.reserveCapacity(maxFrames)
        var sourceIndex = 0
        var sourceFrameEndTime = sourceDurations.first ?? 0

        for bucket in 0..<maxFrames {
            let sampleTime = (Double(bucket) + 0.5) * targetDelay
            while sourceIndex < sourceFrames.count - 1, sampleTime >= sourceFrameEndTime {
                sourceIndex += 1
                sourceFrameEndTime += sourceDurations[sourceIndex]
            }
            let representative = sourceFrames[sourceIndex]
            reducedFrames.append(
                CursorFrame(
                    image: representative.image,
                    delay: targetDelay
                )
            )
        }

        return CursorAnimation(
            frames: reducedFrames,
            hotspot: animation.hotspot,
            canvasSize: animation.canvasSize
        )
    }

    private func downsampleAnimationByIndex(_ animation: CursorAnimation, maxFrames: Int) -> CursorAnimation {
        let sourceFrames = animation.frames
        let sourceCount = sourceFrames.count
        var reducedFrames: [CursorFrame] = []
        reducedFrames.reserveCapacity(maxFrames)

        for bucket in 0..<maxFrames {
            let startIndex = Int((Double(bucket) * Double(sourceCount)) / Double(maxFrames))
            let endIndex = Int((Double(bucket + 1) * Double(sourceCount)) / Double(maxFrames))
            let clampedEnd = max(endIndex, startIndex + 1)
            let range = startIndex..<min(clampedEnd, sourceCount)
            let representativeIndex = min(startIndex + range.count / 2, sourceCount - 1)
            reducedFrames.append(sourceFrames[representativeIndex])
        }

        return CursorAnimation(
            frames: reducedFrames,
            hotspot: animation.hotspot,
            canvasSize: animation.canvasSize
        )
    }

    private func bitmapRep(for image: NSImage, canvasSize: CGSize) throws -> NSBitmapImageRep {
        let pixelWidth = max(Int(canvasSize.width.rounded(.up)), 1)
        let pixelHeight = max(Int(canvasSize.height.rounded(.up)), 1)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            throw CursorError.unsupportedCursorPayload
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            throw CursorError.unsupportedCursorPayload
        }
        context.imageInterpolation = .none
        NSGraphicsContext.current = context
        image.draw(
            in: NSRect(origin: .zero, size: NSSize(width: pixelWidth, height: pixelHeight)),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none]
        )
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private func scaledBitmapRep(for source: NSBitmapImageRep, width: Int, height: Int) throws -> NSBitmapImageRep {
        guard source.pixelsWide == width, source.pixelsHigh == height else {
            guard
                let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: width,
                    pixelsHigh: height,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                )
            else {
                throw CursorError.unsupportedCursorPayload
            }

            NSGraphicsContext.saveGraphicsState()
            guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
                NSGraphicsContext.restoreGraphicsState()
                throw CursorError.unsupportedCursorPayload
            }
            context.imageInterpolation = .none
            NSGraphicsContext.current = context
            source.draw(
                in: NSRect(x: 0, y: 0, width: width, height: height),
                from: NSRect(x: 0, y: 0, width: source.pixelsWide, height: source.pixelsHigh),
                operation: .copy,
                fraction: 1.0,
                respectFlipped: true,
                hints: nil
            )
            NSGraphicsContext.restoreGraphicsState()
            return rep
        }

        return source
    }

    private func stack(frames: [NSBitmapImageRep], width: Int, height: Int) throws -> NSBitmapImageRep {
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height * frames.count,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            throw CursorError.unsupportedCursorPayload
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            throw CursorError.unsupportedCursorPayload
        }
        context.imageInterpolation = .none
        NSGraphicsContext.current = context

        var currentY = 0
        for frame in frames.reversed() {
            _ = autoreleasepool {
                frame.draw(
                    in: NSRect(x: 0, y: currentY, width: frame.pixelsWide, height: frame.pixelsHigh),
                    from: NSRect(x: 0, y: 0, width: frame.pixelsWide, height: frame.pixelsHigh),
                    operation: .copy,
                    fraction: 1.0,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.none]
                )
            }
            currentY += frame.pixelsHigh
        }

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }
}

struct CursorCapeBuilder {
    private let renderer = CursorPayloadRenderer()

    func makeCape(
        name: String,
        author: String,
        identifier: String,
        theme: CursorTheme,
        sizeMultiplier: Double
    ) throws -> [String: Any] {
        let plan = try makePlan(theme: theme, sizeMultiplier: sizeMultiplier)

        return try makeCape(
            name: name,
            author: author,
            identifier: identifier,
            plan: plan
        )
    }

    func makeCape(
        name: String,
        author: String,
        identifier: String,
        plan: CursorApplyPlan
    ) throws -> [String: Any] {
        guard !plan.cursors.isEmpty else {
            throw CursorError.invalidThemeSelection(Localized.string("error.noCursorsToExport"))
        }
        var cursors: [String: Any] = [:]
        for registration in plan.cursors {
            cursors[registration.identifier] = dictionary(for: registration.payload)
        }

        return [
            "MinimumVersion": 2.0,
            "Version": 2.0,
            "CapeName": name,
            "CapeVersion": 1.0,
            "Cloud": false,
            "Author": author,
            "HiDPI": true,
            "Identifier": identifier,
            "Cursors": cursors
        ]
    }

    func makePlan(theme: CursorTheme, sizeMultiplier: Double) throws -> CursorApplyPlan {
        var registrations: [CursorRegistration] = []

        for role in CursorRole.allCases {
            guard let animation = theme[role] else { continue }
            let payload = try renderer.render(animation, sizeMultiplier: sizeMultiplier)
            registrations.append(
                contentsOf: CursorSlotCatalog.identifiers(for: role).map {
                    CursorRegistration(identifier: $0, payload: payload)
                }
            )
        }

        for role in SupplementalCursorRole.allCases {
            guard let animation = theme[role] else { continue }
            let payload = try renderer.render(animation, sizeMultiplier: sizeMultiplier)
            registrations.append(
                contentsOf: CursorSlotCatalog.identifiers(for: role).map {
                    CursorRegistration(identifier: $0, payload: payload)
                }
            )
        }

        for role in SupplementalCursorRole.allCases {
            guard theme[role] == nil, let animation = theme[role.mappedPrimaryRole] else { continue }
            let payload = try renderer.render(animation, sizeMultiplier: sizeMultiplier)
            registrations.append(
                contentsOf: CursorSlotCatalog.identifiers(for: role).map {
                    CursorRegistration(identifier: $0, payload: payload)
                }
            )
        }

        return CursorApplyPlan(cursors: registrations)
    }

    private func dictionary(for payload: RenderedCursorPayload) -> [String: Any] {
        [
            "FrameCount": payload.frameCount,
            "FrameDuration": payload.frameDuration,
            "HotSpotX": payload.hotSpot.x,
            "HotSpotY": payload.hotSpot.y,
            "PointsWide": payload.pointSize.width,
            "PointsHigh": payload.pointSize.height,
            "Representations": payload.representations
        ]
    }
}

protocol SystemCursorBridge: AnyObject {
    func resetAllCursors() throws
    func register(_ registration: CursorRegistration, activatesImmediately: Bool) throws
    func systemDefinedCursorNames() -> [String]
    func setDockCursorOverride(_ enabled: Bool) throws
}

extension SystemCursorBridge {
    func systemDefinedCursorNames() -> [String] {
        []
    }

    func setDockCursorOverride(_ enabled: Bool) throws {}
}

protocol SystemCursorApplying {
    func apply(_ plan: CursorApplyPlan) throws
    func restoreDefaults() throws
}

final class SystemCursorApplicator {
    private let bridge: SystemCursorBridge

    init(bridge: SystemCursorBridge) {
        self.bridge = bridge
    }

    static func live() throws -> SystemCursorApplicator {
        try SystemCursorApplicator(bridge: PrivateSystemCursorBridge())
    }

    func apply(_ plan: CursorApplyPlan) throws {
        try bridge.resetAllCursors()

        let batches = Self.registrationBatches(
            for: plan,
            systemCursorNames: bridge.systemDefinedCursorNames()
        )

        var attemptedRegistration = false
        var applyError: Error?

        do {
            for batch in batches.nonArrow {
                attemptedRegistration = true
                try register(batch, activatesImmediately: true)
            }
            for batch in batches.arrow {
                attemptedRegistration = true
                try register(batch, activatesImmediately: true)
            }
        } catch {
            applyError = error
        }

        if batches.needsDockCursorOverrideReset {
            do {
                try bridge.setDockCursorOverride(false)
            } catch {
                if applyError == nil {
                    applyError = error
                }
            }
        }

        if let applyError {
            if attemptedRegistration {
                try? bridge.resetAllCursors()
            }
            throw applyError
        }
    }

    func restoreDefaults() throws {
        try bridge.resetAllCursors()
    }
}

extension SystemCursorApplicator: SystemCursorApplying {}

private extension SystemCursorApplicator {
    struct RegistrationBatch {
        let registrations: [CursorRegistration]
        let requiresAnySuccess: Bool
    }

    static let arrowRegistrationSources: Set<String> = [
        "com.apple.coregraphics.Arrow",
        "com.apple.coregraphics.ArrowCtx"
    ]

    static let iBeamRegistrationSources: Set<String> = [
        "com.apple.coregraphics.IBeam",
        "com.apple.coregraphics.IBeamXOR"
    ]

    static let arrowActivationIdentifiers: Set<String> = [
        "com.apple.coregraphics.Arrow",
        "com.apple.coregraphics.ArrowCtx"
    ]

    static func registrationBatches(
        for plan: CursorApplyPlan,
        systemCursorNames: [String]
    ) -> (nonArrow: [RegistrationBatch], arrow: [RegistrationBatch], needsDockCursorOverrideReset: Bool) {
        let arrowSynonyms = SystemCursorNameCatalog.arrowSynonyms(systemCursorNames: systemCursorNames)
        let iBeamSynonyms = SystemCursorNameCatalog.iBeamSynonyms(systemCursorNames: systemCursorNames)
        let arrowTargets = Set(arrowSynonyms + Array(arrowActivationIdentifiers))
        let primaryArrowSource = plan.cursors.first { $0.identifier == "com.apple.coregraphics.Arrow" }
        let fallbackArrowSource = primaryArrowSource ?? plan.cursors.first { $0.identifier == "com.apple.coregraphics.ArrowCtx" }
        var nonArrow: [RegistrationBatch] = []
        var arrow: [RegistrationBatch] = []
        var registeredArrowSynonymBatch = false
        var needsDockCursorOverrideReset = false

        for registration in plan.cursors {
            if arrowRegistrationSources.contains(registration.identifier) {
                if registration.identifier == fallbackArrowSource?.identifier, !registeredArrowSynonymBatch {
                    arrow.append(
                        RegistrationBatch(
                            registrations: registrations(from: registration, identifiers: arrowSynonyms),
                            requiresAnySuccess: true
                        )
                    )
                    registeredArrowSynonymBatch = true
                }
                needsDockCursorOverrideReset = true
                continue
            }

            if iBeamRegistrationSources.contains(registration.identifier) {
                nonArrow.append(
                    RegistrationBatch(
                        registrations: registrations(from: registration, identifiers: iBeamSynonyms),
                        requiresAnySuccess: true
                    )
                )
                needsDockCursorOverrideReset = true
                continue
            }

            let batch = RegistrationBatch(registrations: [registration], requiresAnySuccess: false)
            if arrowTargets.contains(registration.identifier) {
                arrow.append(batch)
            } else {
                nonArrow.append(batch)
            }
        }

        return (nonArrow, arrow, needsDockCursorOverrideReset)
    }

    static func registrations(from registration: CursorRegistration, identifiers: [String]) -> [CursorRegistration] {
        identifiers.map {
            CursorRegistration(identifier: $0, payload: registration.payload)
        }
    }

    func register(_ batch: RegistrationBatch, activatesImmediately: Bool) throws {
        guard batch.requiresAnySuccess else {
            for registration in batch.registrations {
                try bridge.register(registration, activatesImmediately: activatesImmediately)
            }
            return
        }

        var failures: [String] = []
        var succeeded = false
        for registration in batch.registrations {
            do {
                try bridge.register(registration, activatesImmediately: activatesImmediately)
                succeeded = true
            } catch {
                failures.append("\(registration.identifier): \(error.localizedDescription)")
            }
        }

        guard succeeded else {
            throw CursorError.systemCursorApplyFailed("Failed to register cursor synonyms: \(failures.joined(separator: ", "))")
        }
    }
}

final class PrivateSystemCursorBridge: SystemCursorBridge {
    private typealias MainConnectionFunction = @convention(c) () -> UInt32
    private typealias RegisterCursorWithImagesFunction = @convention(c) (
        UInt32,
        UnsafePointer<CChar>,
        Bool,
        Bool,
        CGSize,
        CGPoint,
        Int,
        Double,
        CFArray,
        UnsafeMutablePointer<Int32>
    ) -> Int32
    private typealias CopyRegisteredCursorImagesFunction = @convention(c) (
        UInt32,
        UnsafeMutablePointer<CChar>,
        UnsafeMutablePointer<CGSize>,
        UnsafeMutablePointer<CGPoint>,
        UnsafeMutablePointer<Int>,
        UnsafeMutablePointer<Double>,
        UnsafeMutablePointer<CFArray?>
    ) -> Int32
    private typealias CoreCursorCopyImagesFunction = @convention(c) (
        UInt32,
        Int32,
        UnsafeMutablePointer<CFArray?>,
        UnsafeMutablePointer<CGSize>,
        UnsafeMutablePointer<CGPoint>,
        UnsafeMutablePointer<Int>,
        UnsafeMutablePointer<Double>
    ) -> Int32
    private typealias RemoveRegisteredCursorFunction = @convention(c) (
        UInt32,
        UnsafePointer<CChar>,
        Bool
    ) -> Int32
    private typealias UnregisterAllFunction = @convention(c) (UInt32) -> Int32
    private typealias SetSystemCursorFunction = @convention(c) (UInt32, Int32) -> Int32
    private typealias CursorNameForSystemCursorFunction = @convention(c) (Int32) -> UnsafeMutablePointer<CChar>?
    private typealias SetDockCursorOverrideFunction = @convention(c) (UInt32, Bool) -> Void

    private let mainConnection: MainConnectionFunction
    private let registerCursorWithImages: RegisterCursorWithImagesFunction
    private let copyRegisteredCursorImages: CopyRegisteredCursorImagesFunction
    private let coreCursorCopyImages: CoreCursorCopyImagesFunction
    private let removeRegisteredCursorFunction: RemoveRegisteredCursorFunction
    private let unregisterAll: UnregisterAllFunction
    private let setCoreCursor: SetSystemCursorFunction
    private let cursorNameForSystemCursor: CursorNameForSystemCursorFunction?
    private let setDockCursorOverrideFunction: SetDockCursorOverrideFunction?

    init() throws {
        mainConnection = try Self.symbol("CGSMainConnectionID", as: MainConnectionFunction.self)
        registerCursorWithImages = try Self.symbol("CGSRegisterCursorWithImages", as: RegisterCursorWithImagesFunction.self)
        copyRegisteredCursorImages = try Self.symbol("CGSCopyRegisteredCursorImages", as: CopyRegisteredCursorImagesFunction.self)
        coreCursorCopyImages = try Self.symbol("CoreCursorCopyImages", as: CoreCursorCopyImagesFunction.self)
        removeRegisteredCursorFunction = try Self.symbol("CGSRemoveRegisteredCursor", as: RemoveRegisteredCursorFunction.self)
        unregisterAll = try Self.symbol("CoreCursorUnregisterAll", as: UnregisterAllFunction.self)
        setCoreCursor = try Self.symbol("CoreCursorSet", as: SetSystemCursorFunction.self)
        cursorNameForSystemCursor = Self.optionalSymbol("CGSCursorNameForSystemCursor", as: CursorNameForSystemCursorFunction.self)
        setDockCursorOverrideFunction = Self.optionalSymbol("CGSSetDockCursorOverride", as: SetDockCursorOverrideFunction.self)
    }

    func resetAllCursors() throws {
        let systemCursorNames = systemDefinedCursorNames()
        let removalTargets = Set(
            SystemCursorNameCatalog.backupTargets(systemCursorNames: systemCursorNames)
                + SystemCursorNameCatalog.explicitRemovalTargets(systemCursorNames: systemCursorNames)
        )
        for identifier in removalTargets {
            try removeRegisteredCursor(named: identifier)
            try removeRegisteredCursor(named: backupIdentifier(for: identifier))
            try removeRegisteredCursor(named: mousecapeBackupIdentifier(for: identifier))
        }

        let unregisterCode = unregisterAll(mainConnection())
        guard unregisterCode == 0 else {
            throw CursorError.systemCursorApplyFailed("CoreCursorUnregisterAll failed: \(unregisterCode)")
        }

        var failures: [String] = []
        for cursorID in 0...44 {
            let code = setCoreCursor(mainConnection(), Int32(cursorID))
            if code != 0, code != -25190 {
                failures.append("\(cursorID):\(code)")
            }
        }
        if !failures.isEmpty {
            throw CursorError.systemCursorApplyFailed("CoreCursorSet failed: \(failures.joined(separator: ", "))")
        }

        let arrowCode = setCoreCursor(mainConnection(), 0)
        guard arrowCode == 0 || arrowCode == -25190 else {
            throw CursorError.systemCursorApplyFailed("CoreCursorSet failed for arrow: \(arrowCode)")
        }

        try setDockCursorOverride(false)
    }

    func register(_ registration: CursorRegistration, activatesImmediately: Bool) throws {
        guard SystemCursorFrameLimit.contains(registration.payload.frameCount) else {
            throw CursorError.systemCursorApplyFailed("Frame count out of range for \(registration.identifier): \(registration.payload.frameCount)")
        }
        try registerPayload(registration.payload, identifier: registration.identifier, instantly: activatesImmediately)
    }

    func registeredPayload(for identifier: String) -> RenderedCursorPayload? {
        copyPayload(for: identifier)
    }

    func registerProbePayload(_ payload: RenderedCursorPayload, identifier: String) throws {
        try registerPayload(payload, identifier: identifier, instantly: false)
    }

    func removeRegisteredCursor(named identifier: String) throws {
        let code = identifier.withCString {
            removeRegisteredCursorFunction(mainConnection(), $0, false)
        }
        guard code == 0 || code == 1000 || code == -25190 else {
            throw CursorError.systemCursorApplyFailed("CGSRemoveRegisteredCursor failed for \(identifier): \(code)")
        }
    }

    func systemDefinedCursorNames() -> [String] {
        guard let cursorNameForSystemCursor else {
            return []
        }

        var names: [String] = []
        for cursorID in 0..<128 {
            guard let cString = cursorNameForSystemCursor(Int32(cursorID)) else {
                continue
            }
            let name = String(cString: cString)
            guard !name.isEmpty else { continue }
            names.append(name)
        }
        return names
    }

    func setDockCursorOverride(_ enabled: Bool) throws {
        setDockCursorOverrideFunction?(mainConnection(), enabled)
    }

    private func copyPayload(for identifier: String) -> RenderedCursorPayload? {
        var size = CGSize.zero
        var hotSpot = CGPoint.zero
        var frameCount = 0
        var frameDuration = 0.0
        var representations: CFArray?
        let code: Int32

        if let cursorID = SystemCursorNameCatalog.coreCursorID(from: identifier) {
            code = coreCursorCopyImages(
                mainConnection(),
                cursorID,
                &representations,
                &size,
                &hotSpot,
                &frameCount,
                &frameDuration
            )
        } else {
            var cString = Array(identifier.utf8CString)
            code = copyRegisteredCursorImages(
                mainConnection(),
                &cString,
                &size,
                &hotSpot,
                &frameCount,
                &frameDuration,
                &representations
            )
        }

        guard code == 0, let representations else {
            return nil
        }

        let data = (representations as NSArray).compactMap { object -> Data? in
            if CFGetTypeID(object as CFTypeRef) == CGImage.typeID {
                return pngData(for: object as! CGImage)
            }
            return object as? Data
        }
        guard !data.isEmpty else {
            return nil
        }

        return RenderedCursorPayload(
            frameCount: frameCount,
            frameDuration: frameDuration,
            hotSpot: hotSpot,
            pointSize: size,
            representations: data
        )
    }

    private func registerPayload(_ payload: RenderedCursorPayload, identifier: String, instantly: Bool) throws {
        let images = try payload.representations.map { data in
            try cgImage(from: data)
        }
        var seed: Int32 = 0
        let code = identifier.withCString { cString in
            registerCursorWithImages(
                mainConnection(),
                cString,
                true,
                instantly,
                payload.pointSize,
                payload.hotSpot,
                payload.frameCount,
                payload.frameDuration,
                images as CFArray,
                &seed
            )
        }
        guard code == 0 else {
            throw CursorError.systemCursorApplyFailed("CGSRegisterCursorWithImages failed for \(identifier): \(code)")
        }
    }

    private func cgImage(from data: Data) throws -> CGImage {
        if let rep = NSBitmapImageRep(data: data), let image = rep.cgImage {
            return image
        }
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw CursorError.unsupportedCursorPayload
        }
        return image
    }

    private func backupIdentifier(for identifier: String) -> String {
        // The backup namespace predates the Cursie rename; keep it stable so
        // existing registered cursor backups can still be found and removed.
        "com.seinel.capeforge.backup.\(identifier)"
    }

    private func mousecapeBackupIdentifier(for identifier: String) -> String {
        "com.alexzielenski.mousecape.\(identifier)"
    }

    private func pngData(for image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    private static func symbol<T>(_ name: String, as type: T.Type) throws -> T {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            throw CursorError.systemCursorApplyFailed("Missing private cursor symbol: \(name)")
        }
        return unsafeBitCast(symbol, to: T.self)
    }

    private static func optionalSymbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }
}
