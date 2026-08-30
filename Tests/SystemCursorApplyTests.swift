import AppKit
import Foundation
import Testing
@testable import Cursie

struct CursorSlotCatalogTests {
    @Test
    func primaryCursorSlotsMatchMousecapeIdentifiers() {
        #expect(CursorSlotCatalog.identifiers(for: .arrow) == ["com.apple.coregraphics.Arrow"])
        #expect(CursorSlotCatalog.identifiers(for: .text) == ["com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamXOR"])
        #expect(CursorSlotCatalog.identifiers(for: .verticalResize) == [
            "com.apple.cursor.21",
            "com.apple.cursor.22",
            "com.apple.cursor.23",
            "com.apple.cursor.31",
            "com.apple.cursor.32",
            "com.apple.cursor.36"
        ])
        #expect(CursorSlotCatalog.identifiers(for: .horizontalResize) == [
            "com.apple.cursor.17",
            "com.apple.cursor.18",
            "com.apple.cursor.19",
            "com.apple.cursor.27",
            "com.apple.cursor.28",
            "com.apple.cursor.38"
        ])
        #expect(CursorSlotCatalog.identifiers(for: .diagonalResizeNWSE) == [
            "com.apple.cursor.33",
            "com.apple.cursor.34",
            "com.apple.cursor.35"
        ])
        #expect(CursorSlotCatalog.identifiers(for: .diagonalResizeNESW) == [
            "com.apple.cursor.29",
            "com.apple.cursor.30",
            "com.apple.cursor.37"
        ])
    }

    @Test
    func supplementalCursorSlotsMatchMousecapeIdentifiers() {
        #expect(CursorSlotCatalog.identifiers(for: .dragCopy) == ["com.apple.coregraphics.CopyDrag"])
        #expect(CursorSlotCatalog.identifiers(for: .dragLink) == ["com.apple.coregraphics.LinkDrag"])
        #expect(CursorSlotCatalog.identifiers(for: .resizeUp) == ["com.apple.coregraphics.ResizeUp"])
        #expect(CursorSlotCatalog.identifiers(for: .verticalIBeam) == ["com.apple.coregraphics.IBeamForVerticalLayout"])
    }
}

struct SystemCursorNameCatalogTests {
    @Test
    func discoversTahoeArrowAndIBeamSynonymsFromSystemCursorNames() {
        let names = [
            "com.apple.tahoe.cursor.Arrow",
            "com.apple.tahoe.cursor.arrowShadow",
            "com.apple.tahoe.cursor.IBeam",
            "com.apple.tahoe.cursor.VERTICAL_IBEAM",
            "com.apple.cursor.unrelated",
            "com.apple.tahoe.cursor.Arrow"
        ]

        #expect(SystemCursorNameCatalog.arrowSynonyms(systemCursorNames: names) == [
            "com.apple.coregraphics.Arrow",
            "com.apple.coregraphics.ArrowCtx",
            "com.apple.tahoe.cursor.Arrow",
            "com.apple.tahoe.cursor.arrowShadow"
        ])
        #expect(SystemCursorNameCatalog.iBeamSynonyms(systemCursorNames: names) == [
            "com.apple.coregraphics.IBeam",
            "com.apple.coregraphics.IBeamXOR",
            "com.apple.tahoe.cursor.IBeam",
            "com.apple.tahoe.cursor.VERTICAL_IBEAM"
        ])
    }

    @Test
    func backupTargetsIncludeTahoeArrowAndIBeamSynonyms() {
        let names = [
            "com.apple.tahoe.cursor.Arrow",
            "com.apple.tahoe.cursor.IBeam",
            "com.apple.cursor.unrelated"
        ]

        let targets = SystemCursorNameCatalog.backupTargets(systemCursorNames: names)

        #expect(targets.contains("com.apple.coregraphics.Arrow"))
        #expect(targets.contains("com.apple.coregraphics.ArrowCtx"))
        #expect(targets.contains("com.apple.tahoe.cursor.Arrow"))
        #expect(targets.contains("com.apple.coregraphics.IBeam"))
        #expect(targets.contains("com.apple.coregraphics.IBeamXOR"))
        #expect(targets.contains("com.apple.tahoe.cursor.IBeam"))
        #expect(targets.contains("com.apple.coregraphics.Wait"))
    }

    @Test
    func explicitRemovalTargetsIncludeEveryNonBackupRegistrationSlot() {
        let targets = SystemCursorNameCatalog.explicitRemovalTargets(systemCursorNames: [])

        #expect(targets.contains("com.apple.coregraphics.ResizeUp"))
        #expect(targets.contains("com.apple.coregraphics.ResizeDown"))
        #expect(targets.contains("com.apple.coregraphics.ResizeLeft"))
        #expect(targets.contains("com.apple.coregraphics.ResizeRight"))
        #expect(targets.contains("com.apple.cursor.17"))
        #expect(targets.contains("com.apple.cursor.33"))
        #expect(targets.contains("com.apple.cursor.4"))
        #expect(!targets.contains("com.apple.coregraphics.Arrow"))
        #expect(!targets.contains("com.apple.coregraphics.IBeam"))
    }
}

struct CursorPayloadRendererTests {
    @MainActor
    @Test
    func animatedPayloadKeepsStackedRepresentationsAndSeparateFrameCount() throws {
        let frames = [
            CursorFrame(image: solidImage(.red), delay: 0.2),
            CursorFrame(image: solidImage(.blue), delay: 0.2)
        ]
        let animation = CursorAnimation(
            frames: frames,
            hotspot: CGPoint(x: 2, y: 3),
            canvasSize: CGSize(width: 16, height: 16)
        )

        let payload = try CursorPayloadRenderer().render(animation, sizeMultiplier: 1.0)

        #expect(payload.frameCount == 2)
        #expect(payload.frameDuration == 0.2)
        #expect(payload.hotSpot == CGPoint(x: 2, y: 3))
        #expect(payload.pointSize == CGSize(width: 16, height: 16))
        #expect(payload.representations.count == 3)

        let rep = try #require(NSBitmapImageRep(data: payload.representations[0]))
        #expect(rep.pixelsWide == 32)
        #expect(rep.pixelsHigh == 64)

        let midRep = try #require(NSBitmapImageRep(data: payload.representations[1]))
        #expect(midRep.pixelsWide == 80)
        #expect(midRep.pixelsHigh == 160)

        let largeRep = try #require(NSBitmapImageRep(data: payload.representations[2]))
        #expect(largeRep.pixelsWide == 160)
        #expect(largeRep.pixelsHigh == 320)
    }

    @MainActor
    @Test
    func animatedPayloadKeepsTwentyFourFrameCursorUnchanged() throws {
        let image = solidImage(.red)
        let frames = (0..<24).map { _ in
            CursorFrame(image: image, delay: 0.04)
        }
        let animation = CursorAnimation(
            frames: frames,
            hotspot: CGPoint(x: 2, y: 3),
            canvasSize: CGSize(width: 16, height: 16)
        )

        let payload = try CursorPayloadRenderer().render(animation, sizeMultiplier: 1.0)

        #expect(payload.frameCount == 24)
        #expect(payload.frameDuration == 0.04)
    }

    @MainActor
    @Test
    func animatedPayloadResamplesVariableFrameTiming() throws {
        let animation = CursorAnimation(
            frames: [
                CursorFrame(image: solidImage(.red), delay: 0.1),
                CursorFrame(image: solidImage(.blue), delay: 0.2),
                CursorFrame(image: solidImage(.green), delay: 0.3)
            ],
            hotspot: CGPoint(x: 2, y: 3),
            canvasSize: CGSize(width: 16, height: 16)
        )

        let payload = try CursorPayloadRenderer().render(animation, sizeMultiplier: 1.0)

        #expect(payload.frameCount == 6)
        #expect(abs(payload.frameDuration - 0.1) < 0.000_001)
        #expect(abs((Double(payload.frameCount) * payload.frameDuration) - 0.6) < 0.000_001)
        #expect(redFrameCount(in: payload) == 1)
    }

    @MainActor
    @Test
    func rejectsCursorCanvasAboveRenderLimitBeforeAllocation() {
        let animation = CursorAnimation(
            frames: [CursorFrame(image: solidImage(.red), delay: 0.1)],
            hotspot: .zero,
            canvasSize: CGSize(
                width: CursorRenderLimit.maximumSourceDimension + 1,
                height: CursorRenderLimit.maximumSourceDimension + 1
            )
        )

        #expect(throws: CursorError.self) {
            try CursorPayloadRenderer().render(animation, sizeMultiplier: 1.0)
        }
    }

    @MainActor
    @Test
    func animatedPayloadDownsamplesAboveTwentyFourFramesAndPreservesDuration() throws {
        let image = solidImage(.blue)
        let frames = (0..<72).map { _ in
            CursorFrame(image: image, delay: 0.05)
        }
        let animation = CursorAnimation(
            frames: frames,
            hotspot: CGPoint(x: 2, y: 3),
            canvasSize: CGSize(width: 16, height: 16)
        )

        let payload = try CursorPayloadRenderer().render(animation, sizeMultiplier: 1.0)

        #expect(payload.frameCount == 24)
        #expect(abs((Double(payload.frameCount) * payload.frameDuration) - 3.6) < 0.001)
    }

    @MainActor
    @Test
    func animatedPayloadDownsamplesByTimelineInsteadOfSourceIndex() throws {
        let frames = [CursorFrame(image: solidImage(.red), delay: 0.75)]
            + (0..<47).map { _ in CursorFrame(image: solidImage(.blue), delay: 0.01) }
        let animation = CursorAnimation(
            frames: frames,
            hotspot: CGPoint(x: 2, y: 3),
            canvasSize: CGSize(width: 16, height: 16)
        )

        let payload = try CursorPayloadRenderer().render(animation, sizeMultiplier: 1.0)

        #expect(payload.frameCount == 24)
        #expect(redFrameCount(in: payload) >= 12)
    }

}

struct CursorApplyPlanTests {
    @Test
    func savedCapeUsesCatalogOrderInsteadOfLexicographicOrder() throws {
        let payload = cursorDictionary()
        let cape: [String: Any] = [
            "Cursors": [
                "com.apple.cursor.10": payload,
                "com.apple.cursor.2": payload,
                "com.apple.cursor.14": payload
            ]
        ]

        let plan = try CursorApplyPlan(cape: cape)

        #expect(plan.cursors.map(\.identifier) == [
            "com.apple.cursor.2",
            "com.apple.cursor.10",
            "com.apple.cursor.14"
        ])
    }
}

struct CursorAgentRuntimeTests {
    @MainActor
    @Test
    func agentDoesNotPollFullCursorReapplyOnFixedTimer() {
        #expect(CursorAgentRuntime.periodicReapplyInterval == nil)
        #expect(!CursorAgentRuntime.staysResidentAfterLoginReapply)
    }
}

struct CursorAgentManagerTests {
    @Test
    func launchAgentFindsInstalledAppByBundleIdentifier() throws {
        let plist = CursorAgentManager.launchAgentPropertyList(
            bundleIdentifier: "com.example.Cursie",
            logPath: "/tmp/Cursie.log"
        )
        let arguments = try #require(plist["ProgramArguments"] as? [String])

        #expect(arguments == [
            "/usr/bin/open", "-gj", "-n", "-b", "com.example.Cursie", "--args", "--cursor-agent"
        ])
        #expect(!arguments.contains(where: { $0.hasSuffix(".app/Contents/MacOS/Cursie") }))
    }
}

struct SystemCursorApplicatorTests {
    @Test
    func restoreDefaultsAlsoClearsDockCursorOverride() throws {
        let bridge = RecordingCursorBridge()
        let applicator = SystemCursorApplicator(bridge: bridge)

        try applicator.restoreDefaults()

        #expect(bridge.events == [
            .resetAllCursors,
            .setDockCursorOverride(false)
        ])
    }

    @Test
    func applyContinuesWhenAtLeastOneDiscoveredSynonymRegisters() throws {
        let payload = RenderedCursorPayload(
            frameCount: 1,
            frameDuration: 0.1,
            hotSpot: CGPoint(x: 1, y: 1),
            pointSize: CGSize(width: 16, height: 16),
            representations: [Data([0x01, 0x02])]
        )
        let plan = CursorApplyPlan(cursors: [
            CursorRegistration(identifier: "com.apple.coregraphics.Arrow", payload: payload)
        ])
        let bridge = RecordingCursorBridge()
        bridge.systemCursorNames = ["com.apple.tahoe.cursor.Arrow"]
        bridge.failingIdentifiers = [
            "com.apple.coregraphics.Arrow",
            "com.apple.coregraphics.ArrowCtx"
        ]
        let applicator = SystemCursorApplicator(bridge: bridge)

        try applicator.apply(plan)

        #expect(bridge.events == [
            .resetAllCursors,
            .register("com.apple.coregraphics.Arrow", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.coregraphics.ArrowCtx", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.tahoe.cursor.Arrow", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .setDockCursorOverride(false)
        ])
    }

    @Test
    func applyResetsToDefaultsWhenEveryDiscoveredSynonymFails() throws {
        let payload = RenderedCursorPayload(
            frameCount: 1,
            frameDuration: 0.1,
            hotSpot: CGPoint(x: 1, y: 1),
            pointSize: CGSize(width: 16, height: 16),
            representations: [Data([0x01, 0x02])]
        )
        let plan = CursorApplyPlan(cursors: [
            CursorRegistration(identifier: "com.apple.coregraphics.Arrow", payload: payload)
        ])
        let bridge = RecordingCursorBridge()
        bridge.systemCursorNames = ["com.apple.tahoe.cursor.Arrow"]
        bridge.failingIdentifiers = [
            "com.apple.coregraphics.Arrow",
            "com.apple.coregraphics.ArrowCtx",
            "com.apple.tahoe.cursor.Arrow"
        ]
        let applicator = SystemCursorApplicator(bridge: bridge)

        #expect(throws: CursorError.self) {
            try applicator.apply(plan)
        }
        #expect(bridge.events == [
            .resetAllCursors,
            .register("com.apple.coregraphics.Arrow", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.coregraphics.ArrowCtx", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.tahoe.cursor.Arrow", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .setDockCursorOverride(false),
            .resetAllCursors
        ])
    }

    @Test
    func applyRegistersDiscoveredTahoeArrowAndIBeamSynonyms() throws {
        let payload = RenderedCursorPayload(
            frameCount: 1,
            frameDuration: 0.1,
            hotSpot: CGPoint(x: 1, y: 1),
            pointSize: CGSize(width: 16, height: 16),
            representations: [Data([0x01, 0x02])]
        )
        let plan = CursorApplyPlan(cursors: [
            CursorRegistration(identifier: "com.apple.coregraphics.Arrow", payload: payload),
            CursorRegistration(identifier: "com.apple.coregraphics.IBeam", payload: payload),
            CursorRegistration(identifier: "com.apple.cursor.33", payload: payload)
        ])
        let bridge = RecordingCursorBridge()
        bridge.systemCursorNames = [
            "com.apple.tahoe.cursor.Arrow",
            "com.apple.tahoe.cursor.IBeam",
            "com.apple.cursor.unrelated"
        ]
        let applicator = SystemCursorApplicator(bridge: bridge)

        try applicator.apply(plan)

        #expect(bridge.events == [
            .resetAllCursors,
            .register("com.apple.coregraphics.IBeam", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.coregraphics.IBeamXOR", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.tahoe.cursor.IBeam", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.cursor.33", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.coregraphics.Arrow", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.coregraphics.ArrowCtx", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.tahoe.cursor.Arrow", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .setDockCursorOverride(false)
        ])
    }

    @Test
    func applyDoesNotLetSupplementalArrowCtxOverridePrimaryArrowSynonyms() throws {
        let arrowPayload = RenderedCursorPayload(
            frameCount: 1,
            frameDuration: 0.1,
            hotSpot: CGPoint(x: 1, y: 1),
            pointSize: CGSize(width: 16, height: 16),
            representations: [Data([0x01, 0x02])]
        )
        let contextualPayload = RenderedCursorPayload(
            frameCount: 1,
            frameDuration: 0.1,
            hotSpot: CGPoint(x: 2, y: 2),
            pointSize: CGSize(width: 16, height: 16),
            representations: [Data([0x03, 0x04])]
        )
        let plan = CursorApplyPlan(cursors: [
            CursorRegistration(identifier: "com.apple.coregraphics.Arrow", payload: arrowPayload),
            CursorRegistration(identifier: "com.apple.coregraphics.ArrowCtx", payload: contextualPayload)
        ])
        let bridge = RecordingCursorBridge()
        bridge.systemCursorNames = ["com.apple.tahoe.cursor.ArrowS"]
        let applicator = SystemCursorApplicator(bridge: bridge)

        try applicator.apply(plan)

        #expect(bridge.events == [
            .resetAllCursors,
            .register("com.apple.coregraphics.Arrow", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.coregraphics.ArrowCtx", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.tahoe.cursor.ArrowS", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .setDockCursorOverride(false)
        ])
    }

    @Test
    func applyKeepsArrowActiveEvenWhenResizeCursorsAreRegisteredLast() throws {
        let payload = RenderedCursorPayload(
            frameCount: 1,
            frameDuration: 0.1,
            hotSpot: CGPoint(x: 1, y: 1),
            pointSize: CGSize(width: 16, height: 16),
            representations: [Data([0x01, 0x02])]
        )
        let plan = CursorApplyPlan(cursors: [
            CursorRegistration(identifier: "com.apple.coregraphics.Arrow", payload: payload),
            CursorRegistration(identifier: "com.apple.cursor.33", payload: payload),
            CursorRegistration(identifier: "com.apple.cursor.37", payload: payload)
        ])
        let bridge = RecordingCursorBridge()
        let applicator = SystemCursorApplicator(bridge: bridge)

        try applicator.apply(plan)

        #expect(bridge.events == [
            .resetAllCursors,
            .register("com.apple.cursor.33", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.cursor.37", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.coregraphics.Arrow", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.coregraphics.ArrowCtx", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .setDockCursorOverride(false)
        ])
    }

    @Test
    func applyRestoresDefaultsWhenRegistrationFailsAfterPartialMutation() throws {
        let payload = RenderedCursorPayload(
            frameCount: 1,
            frameDuration: 0.1,
            hotSpot: CGPoint(x: 1, y: 1),
            pointSize: CGSize(width: 16, height: 16),
            representations: [Data([0x01, 0x02])]
        )
        let plan = CursorApplyPlan(cursors: [
            CursorRegistration(identifier: "com.apple.cursor.33", payload: payload),
            CursorRegistration(identifier: "com.apple.cursor.37", payload: payload)
        ])
        let bridge = RecordingCursorBridge()
        bridge.failingIdentifiers = ["com.apple.cursor.37"]
        let applicator = SystemCursorApplicator(bridge: bridge)

        #expect(throws: CursorError.self) {
            try applicator.apply(plan)
        }
        #expect(bridge.events == [
            .resetAllCursors,
            .register("com.apple.cursor.33", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .register("com.apple.cursor.37", frameCount: 1, representationCount: 1, activatesImmediately: true),
            .resetAllCursors
        ])
    }
}

struct CursorSystemApplyServiceTests {
    @MainActor
    @Test
    func appliesLiveSystemCursorsFromEnvironmentWhenRequested() throws {
        guard
            ProcessInfo.processInfo.environment["CAPE_FORGE_LIVE_APPLY"] == "1",
            let folderPath = ProcessInfo.processInfo.environment["CAPE_FORGE_LIVE_APPLY_FOLDER"],
            let executablePath = ProcessInfo.processInfo.environment["CAPE_FORGE_LIVE_EXECUTABLE"],
            !folderPath.isEmpty,
            !executablePath.isEmpty
        else {
            return
        }

        let resolved = try ThemeResolver().resolveTheme(in: URL(fileURLWithPath: folderPath, isDirectory: true))
        let parser = AniParser()
        var animations: [CursorRole: CursorAnimation] = [:]
        for (role, fileURL) in resolved.filesByRole {
            animations[role] = try parser.parseCursorFile(at: fileURL)
        }

        try CursorSystemApplyService().apply(
            theme: CursorTheme(animations: animations),
            sizeMultiplier: 1.0,
            author: "Cape Forge Live Apply",
            bundleIdentifier: "com.seinel.capeforge",
            executableURL: URL(fileURLWithPath: executablePath)
        )

        #expect(FileManager.default.fileExists(atPath: CursorAgentManager().appliedCapeURL.path))
        print("LIVE_APPLIED_CAPE_PATH=\(CursorAgentManager().appliedCapeURL.path)")
    }

    @MainActor
    @Test
    func applyInstallsAgentOnlyAfterForegroundApplySucceeds() throws {
        let recorder = CursorSystemApplyRecorder()
        let manager = RecordingAgentManager(recorder: recorder)
        let applicator = RecordingSystemCursorApplying(recorder: recorder)
        let service = CursorSystemApplyService(
            agentManager: manager,
            conflictChecker: RecordingConflictChecker(),
            makeApplicator: { applicator }
        )

        try service.apply(
            theme: CursorTheme(animations: [.arrow: singleFrameAnimation()]),
            sizeMultiplier: 1.0,
            author: "Tester",
            bundleIdentifier: "test.capeforge",
            executableURL: URL(fileURLWithPath: "/tmp/Cape Forge")
        )

        #expect(recorder.events == [
            .apply(["com.apple.coregraphics.Arrow"]),
            .saveAppliedCape,
            .installLaunchAgent
        ])
    }

    @Test
    func restoreDefaultsRemovesLoginReapplyBeforeResettingCursors() throws {
        let recorder = CursorSystemApplyRecorder()
        let manager = RecordingAgentManager(recorder: recorder)
        let applicator = RecordingSystemCursorApplying(recorder: recorder)
        let service = CursorSystemApplyService(
            agentManager: manager,
            conflictChecker: RecordingConflictChecker(),
            makeApplicator: { applicator }
        )

        try service.restoreDefaults()

        #expect(recorder.events == [
            .stopLaunchAgent,
            .removePersistedState,
            .restoreDefaults
        ])
    }

    @Test
    func rejectsExecutableRunningFromDiskImageOrAppTranslocation() {
        #expect(throws: CursorError.self) {
            try CursorAgentExecutableLocation.validate(
                URL(fileURLWithPath: "/Volumes/Cursie/Cursie.app/Contents/MacOS/Cursie")
            )
        }
        #expect(throws: CursorError.self) {
            try CursorAgentExecutableLocation.validate(
                URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/ABC/Cursie.app/Contents/MacOS/Cursie")
            )
        }
        #expect(throws: Never.self) {
            try CursorAgentExecutableLocation.validate(
                URL(fileURLWithPath: "/Applications/Cursie.app/Contents/MacOS/Cursie")
            )
        }
    }

    @MainActor
    @Test
    func applyFailureRemovesPersistedStateWithoutStartingAgent() throws {
        let recorder = CursorSystemApplyRecorder()
        let manager = RecordingAgentManager(recorder: recorder)
        let applicator = RecordingSystemCursorApplying(recorder: recorder)
        applicator.applyError = CursorError.systemCursorApplyFailed("apply failed")
        let service = CursorSystemApplyService(
            agentManager: manager,
            conflictChecker: RecordingConflictChecker(),
            makeApplicator: { applicator }
        )

        #expect(throws: CursorError.self) {
            try service.apply(
                theme: CursorTheme(animations: [.arrow: singleFrameAnimation()]),
                sizeMultiplier: 1.0,
                author: "Tester",
                bundleIdentifier: "test.capeforge",
                executableURL: URL(fileURLWithPath: "/tmp/Cape Forge")
            )
        }
        #expect(recorder.events == [
            .apply(["com.apple.coregraphics.Arrow"]),
            .stopLaunchAgent,
            .removePersistedState
        ])
    }

    @MainActor
    @Test
    func installFailureRollsBackForegroundApplyAndPersistedState() throws {
        let recorder = CursorSystemApplyRecorder()
        let manager = RecordingAgentManager(recorder: recorder)
        manager.installError = CursorError.systemCursorApplyFailed("install failed")
        let applicator = RecordingSystemCursorApplying(recorder: recorder)
        let service = CursorSystemApplyService(
            agentManager: manager,
            conflictChecker: RecordingConflictChecker(),
            makeApplicator: { applicator }
        )

        #expect(throws: CursorError.self) {
            try service.apply(
                theme: CursorTheme(animations: [.arrow: singleFrameAnimation()]),
                sizeMultiplier: 1.0,
                author: "Tester",
                bundleIdentifier: "test.capeforge",
                executableURL: URL(fileURLWithPath: "/tmp/Cape Forge")
            )
        }
        #expect(recorder.events == [
            .apply(["com.apple.coregraphics.Arrow"]),
            .saveAppliedCape,
            .installLaunchAgent,
            .stopLaunchAgent,
            .removePersistedState,
            .restoreDefaults
        ])
    }

    @MainActor
    @Test
    func applyDoesNotWaitForLaunchAgentReadiness() throws {
        let recorder = CursorSystemApplyRecorder()
        let manager = RecordingAgentManager(recorder: recorder)
        manager.verifyReadyError = CursorError.systemCursorApplyFailed("agent waiting for accessibility")
        let applicator = RecordingSystemCursorApplying(recorder: recorder)
        let service = CursorSystemApplyService(
            agentManager: manager,
            conflictChecker: RecordingConflictChecker(),
            makeApplicator: { applicator }
        )

        try service.apply(
            theme: CursorTheme(animations: [.arrow: singleFrameAnimation()]),
            sizeMultiplier: 1.0,
            author: "Tester",
            bundleIdentifier: "test.capeforge",
            executableURL: URL(fileURLWithPath: "/tmp/Cape Forge")
        )
        #expect(recorder.events == [
            .apply(["com.apple.coregraphics.Arrow"]),
            .saveAppliedCape,
            .installLaunchAgent
        ])
    }

    @Test
    func applyDoesNotRequireAccessibilityBecauseItUsesMousecapeStyleRegistration() throws {
        let recorder = CursorSystemApplyRecorder()
        let manager = RecordingAgentManager(recorder: recorder)
        let applicator = RecordingSystemCursorApplying(recorder: recorder)
        let service = CursorSystemApplyService(
            agentManager: manager,
            conflictChecker: RecordingConflictChecker(),
            makeApplicator: { applicator }
        )

        try service.apply(
            theme: CursorTheme(animations: [.arrow: singleFrameAnimation()]),
            sizeMultiplier: 1.0,
            author: "Tester",
            bundleIdentifier: "test.capeforge",
            executableURL: URL(fileURLWithPath: "/tmp/Cape Forge")
        )

        #expect(recorder.events == [
            .apply(["com.apple.coregraphics.Arrow"]),
            .saveAppliedCape,
            .installLaunchAgent
        ])
    }

    @MainActor
    @Test
    func applyStopsBeforeRenderingWhenMousecapeIsRunning() throws {
        let recorder = CursorSystemApplyRecorder()
        let manager = RecordingAgentManager(recorder: recorder)
        let applicator = RecordingSystemCursorApplying(recorder: recorder)
        let service = CursorSystemApplyService(
            agentManager: manager,
            conflictChecker: RecordingConflictChecker(conflict: "Mousecape"),
            makeApplicator: { applicator }
        )

        #expect(throws: CursorError.self) {
            try service.apply(
                theme: CursorTheme(animations: [.arrow: singleFrameAnimation()]),
                sizeMultiplier: 1.0,
                author: "Tester",
                bundleIdentifier: "test.capeforge",
                executableURL: URL(fileURLWithPath: "/tmp/Cape Forge")
            )
        }
        #expect(recorder.events.isEmpty)
    }
}

private func cursorDictionary() -> [String: Any] {
    [
        "FrameCount": 1,
        "FrameDuration": 0.1,
        "HotSpotX": 1.0,
        "HotSpotY": 1.0,
        "PointsWide": 16.0,
        "PointsHigh": 16.0,
        "Representations": [Data([0x01, 0x02])]
    ]
}

private func singleFrameAnimation() -> CursorAnimation {
    CursorAnimation(
        frames: [CursorFrame(image: solidImage(.red), delay: 0.1)],
        hotspot: CGPoint(x: 1, y: 1),
        canvasSize: CGSize(width: 16, height: 16)
    )
}

private func solidImage(_ color: NSColor) -> NSImage {
    let image = NSImage(size: NSSize(width: 16, height: 16))
    image.lockFocus()
    color.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
    image.unlockFocus()
    return image
}

private func stackedPNG(width: Int, height: Int, frameColors: [NSColor]) throws -> Data {
    let rep = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height * frameColors.count,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ))

    NSGraphicsContext.saveGraphicsState()
    let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
    NSGraphicsContext.current = context
    for (index, color) in frameColors.enumerated() {
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: height * (frameColors.count - index - 1), width: width, height: height)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    return try #require(rep.representation(using: .png, properties: [:]))
}

private func dominantColor(in image: NSImage) -> NSColor? {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff)
    else {
        return nil
    }
    return rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)?.usingColorSpace(.deviceRGB)
}

private func isMostlyBlue(_ color: NSColor?) -> Bool {
    guard let color else { return false }
    return color.blueComponent > 0.8 && color.blueComponent > color.redComponent && color.blueComponent > color.greenComponent
}

private func isMostlyGreen(_ color: NSColor?) -> Bool {
    guard let color else { return false }
    return color.greenComponent > 0.8 && color.greenComponent > color.redComponent && color.greenComponent > color.blueComponent
}

private func redFrameCount(in payload: RenderedCursorPayload) -> Int {
    guard
        let representation = payload.representations.first,
        let rep = NSBitmapImageRep(data: representation),
        payload.frameCount > 0
    else {
        return 0
    }

    let frameHeight = max(rep.pixelsHigh / payload.frameCount, 1)
    var redCount = 0
    for frameIndex in 0..<payload.frameCount {
        let sampleY = min(frameIndex * frameHeight + frameHeight / 2, rep.pixelsHigh - 1)
        guard let color = rep.colorAt(x: rep.pixelsWide / 2, y: sampleY)?.usingColorSpace(.deviceRGB) else {
            continue
        }
        if color.redComponent > 0.7, color.blueComponent < 0.3 {
            redCount += 1
        }
    }
    return redCount
}

private final class CursorSystemApplyRecorder {
    enum Event: Equatable {
        case apply([String])
        case restoreDefaults
        case saveAppliedCape
        case installLaunchAgent
        case verifyLaunchAgentReady
        case stopLaunchAgent
        case removeLaunchAgentPlist
        case removeAppliedCape
        case removePersistedState
    }

    var events: [Event] = []
}

private final class RecordingAgentManager: CursorAgentManaging {
    let recorder: CursorSystemApplyRecorder
    var installError: Error?
    var verifyReadyError: Error?

    init(recorder: CursorSystemApplyRecorder) {
        self.recorder = recorder
    }

    func saveAppliedCape(_ cape: [String: Any]) throws {
        recorder.events.append(.saveAppliedCape)
    }

    func loadAppliedCape() throws -> [String: Any]? {
        nil
    }

    func installLaunchAgent(bundleIdentifier: String) throws {
        recorder.events.append(.installLaunchAgent)
        if let installError {
            throw installError
        }
    }

    func verifyLaunchAgentReady(timeout: TimeInterval) throws {
        recorder.events.append(.verifyLaunchAgentReady)
        if let verifyReadyError {
            throw verifyReadyError
        }
    }

    func stopLaunchAgent() throws {
        recorder.events.append(.stopLaunchAgent)
    }

    func removeLaunchAgentPlist() throws {
        recorder.events.append(.removeLaunchAgentPlist)
    }

    func removeAppliedCape() throws {
        recorder.events.append(.removeAppliedCape)
    }

    func removePersistedState() throws {
        recorder.events.append(.removePersistedState)
    }
}

private struct RecordingConflictChecker: CursorApplyConflictChecking {
    var conflict: String?

    func activeConflictDescription() -> String? {
        conflict
    }
}

private final class RecordingSystemCursorApplying: SystemCursorApplying {
    let recorder: CursorSystemApplyRecorder
    var applyError: Error?
    var restoreError: Error?

    init(recorder: CursorSystemApplyRecorder) {
        self.recorder = recorder
    }

    func apply(_ plan: CursorApplyPlan) throws {
        recorder.events.append(.apply(plan.cursors.map(\.identifier)))
        if let applyError {
            throw applyError
        }
    }

    func restoreDefaults() throws {
        recorder.events.append(.restoreDefaults)
        if let restoreError {
            throw restoreError
        }
    }
}

private final class RecordingCursorBridge: SystemCursorBridge {
    enum Event: Equatable {
        case resetAllCursors
        case register(String, frameCount: Int, representationCount: Int, activatesImmediately: Bool)
        case setDockCursorOverride(Bool)
    }

    var events: [Event] = []
    var systemCursorNames: [String] = []
    var failingIdentifiers: Set<String> = []

    func resetAllCursors() throws {
        events.append(.resetAllCursors)
    }

    func register(_ registration: CursorRegistration, activatesImmediately: Bool) throws {
        events.append(
            .register(
                registration.identifier,
                frameCount: registration.payload.frameCount,
                representationCount: registration.payload.representations.count,
                activatesImmediately: activatesImmediately
            )
        )
        if failingIdentifiers.contains(registration.identifier) {
            throw CursorError.systemCursorApplyFailed("failed \(registration.identifier)")
        }
    }

    func systemDefinedCursorNames() -> [String] {
        systemCursorNames
    }

    func setDockCursorOverride(_ enabled: Bool) throws {
        events.append(.setDockCursorOverride(enabled))
    }
}
