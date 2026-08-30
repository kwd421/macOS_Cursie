import AppKit
import Foundation
import UniformTypeIdentifiers

// @unchecked Sendable: these are immutable value types. The only non-Sendable
// member is NSImage, which we treat as read-only once a theme is built — it is
// rendered (drawn into bitmap contexts) but never mutated. Marking them Sendable
// lets a fully-built theme cross into the background apply task so the heavy
// rendering no longer blocks the main thread.
struct CursorFrame: @unchecked Sendable {
    let image: NSImage
    let delay: TimeInterval
}

struct CursorAnimation: @unchecked Sendable {
    let frames: [CursorFrame]
    let hotspot: CGPoint
    let canvasSize: CGSize
}

enum CursorRole: String, CaseIterable, Identifiable {
    case arrow
    case text
    case link
    case location
    case precision
    case move
    case unavailable
    case busy
    case working
    case help
    case handwriting
    case person
    case alternate
    case verticalResize
    case horizontalResize
    case diagonalResizeNWSE
    case diagonalResizeNESW

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arrow: return Localized.string("role.arrow")
        case .text: return Localized.string("role.text")
        case .link: return Localized.string("role.link")
        case .location: return Localized.string("role.location")
        case .precision: return Localized.string("role.precision")
        case .move: return Localized.string("role.move")
        case .unavailable: return Localized.string("role.unavailable")
        case .busy: return Localized.string("role.busy")
        case .working: return Localized.string("role.working")
        case .help: return Localized.string("role.help")
        case .handwriting: return Localized.string("role.handwriting")
        case .person: return Localized.string("role.person")
        case .alternate: return Localized.string("role.alternate")
        case .verticalResize: return Localized.string("role.verticalResize")
        case .horizontalResize: return Localized.string("role.horizontalResize")
        case .diagonalResizeNWSE: return Localized.string("role.diagonalResizeNWSE")
        case .diagonalResizeNESW: return Localized.string("role.diagonalResizeNESW")
        }
    }

    var themeFileName: String {
        switch self {
        case .arrow: return "독케익_일반선택.ani"
        case .text: return "독케익_텍스트 선택.ani"
        case .link: return "독케익_연결,위치,사용자 선택.ani"
        case .location: return "Pin.ani"
        case .precision: return "독케익_정밀도 선택.ani"
        case .move: return "독케익_이동.ani"
        case .unavailable: return "독케익_사용할 수 없음.ani"
        case .busy: return "Busy.ani"
        case .working: return "독케익_백그라운드 작업,사용중.ani"
        case .help: return "Help.ani"
        case .handwriting: return "Handwriting.ani"
        case .person: return "Person.ani"
        case .alternate: return "Alternate.ani"
        case .verticalResize: return "독케익_수직 크기 조절.ani"
        case .horizontalResize: return "독케익_수평 크기 조절.ani"
        case .diagonalResizeNWSE: return "독케익_대각선 방향 크기 조절 1.ani"
        case .diagonalResizeNESW: return "독케익_대각선 방향 크기 조절 2.ani"
        }
    }

    var mousecapeMappingDescription: String {
        switch self {
        case .arrow:
            return "Arrow"
        case .text:
            return "IBeam, IBeamXOR"
        case .link:
            return "Link, Pointing"
        case .location:
            return "Copy, Copy Drag"
        case .precision:
            return "Crosshair, Crosshair 2"
        case .move:
            return "Move"
        case .unavailable:
            return "Forbidden"
        case .busy:
            return "Busy"
        case .working:
            return "Wait"
        case .help:
            return "Help"
        case .handwriting:
            return "Cell XOR"
        case .person:
            return "Cell"
        case .alternate:
            return "Alias"
        case .verticalResize:
            return "Resize N, Resize S, Resize N-S, Window N, Window S, Window N-S"
        case .horizontalResize:
            return "Resize W, Resize E, Resize W-E, Window W, Window E, Window E-W"
        case .diagonalResizeNWSE:
            return "Window NW, Window NW-SE, Window SE"
        case .diagonalResizeNESW:
            return "Window NE, Window NE-SW, Window SW"
        }
    }

}

struct CursorAssignment: Identifiable {
    let role: CursorRole
    let appliedPreview: CursorAnimation?
    let sourceURL: URL?
    let isOverride: Bool
    let isResolved: Bool
    let usesArrowFallback: Bool

    var id: CursorRole { role }
}

struct CursorTheme: @unchecked Sendable {
    let animations: [CursorRole: CursorAnimation]
    let supplementalAnimations: [SupplementalCursorRole: CursorAnimation]

    init(
        animations: [CursorRole: CursorAnimation],
        supplementalAnimations: [SupplementalCursorRole: CursorAnimation] = [:]
    ) {
        self.animations = animations
        self.supplementalAnimations = supplementalAnimations
    }

    subscript(role: CursorRole) -> CursorAnimation? {
        animations[role]
    }

    subscript(role: SupplementalCursorRole) -> CursorAnimation? {
        supplementalAnimations[role]
    }
}

private struct CursorThemeLoadRequest: @unchecked Sendable {
    let baseDirectory: URL?
    let primaryOverrides: [CursorRole: URL]
    let supplementalOverrides: [SupplementalCursorRole: URL]
}

private struct CursorThemeLoadResult: @unchecked Sendable {
    let theme: CursorTheme
    let filesByRole: [CursorRole: URL]
    let fallbackRoles: Set<CursorRole>
    let missingSupplementalOverrides: [URL]
}

private struct CursorThemeLoader {
    static func load(_ request: CursorThemeLoadRequest) throws -> CursorThemeLoadResult {
        let parser = AniParser()
        var animations: [CursorRole: CursorAnimation] = [:]
        var supplementalAnimations: [SupplementalCursorRole: CursorAnimation] = [:]
        var parsedAnimationsByURL: [URL: CursorAnimation] = [:]
        var resolvedFiles: [CursorRole: URL] = [:]
        var fallbackRoles = Set<CursorRole>()
        var missingSupplementalOverrides: [URL] = []

        if let baseDirectory = request.baseDirectory {
            let resolvedTheme = try ThemeResolver().resolveTheme(in: baseDirectory)
            resolvedFiles = resolvedTheme.filesByRole
            fallbackRoles = resolvedTheme.fallbackRoles
        } else if request.primaryOverrides.isEmpty && request.supplementalOverrides.isEmpty {
            throw CursorError.missingTheme(Localized.string("error.noThemeFolderSelected"))
        }

        func parsedAnimation(for url: URL) throws -> CursorAnimation {
            try Task.checkCancellation()
            let normalizedURL = url.standardizedFileURL
            if let cached = parsedAnimationsByURL[normalizedURL] {
                return cached
            }
            let parsed = try autoreleasepool {
                try parser.parseCursorFile(at: url)
            }
            parsedAnimationsByURL[normalizedURL] = parsed
            return parsed
        }

        for role in CursorRole.allCases {
            try Task.checkCancellation()
            if let override = request.primaryOverrides[role], FileManager.default.fileExists(atPath: override.path) {
                animations[role] = try parsedAnimation(for: override)
                resolvedFiles[role] = override
                continue
            }
            guard let url = resolvedFiles[role] else { continue }
            animations[role] = try parsedAnimation(for: url)
        }

        for role in SupplementalCursorRole.allCases {
            try Task.checkCancellation()
            guard let override = request.supplementalOverrides[role] else { continue }
            if FileManager.default.fileExists(atPath: override.path) {
                supplementalAnimations[role] = try parsedAnimation(for: override)
            } else {
                missingSupplementalOverrides.append(override)
            }
        }

        if let baseDirectory = request.baseDirectory, animations[.arrow] == nil {
            throw CursorError.missingTheme(baseDirectory.path)
        }
        guard !animations.isEmpty || !supplementalAnimations.isEmpty else {
            throw CursorError.missingTheme(Localized.string("error.noThemeFolderSelected"))
        }

        return CursorThemeLoadResult(
            theme: CursorTheme(animations: animations, supplementalAnimations: supplementalAnimations),
            filesByRole: resolvedFiles,
            fallbackRoles: fallbackRoles,
            missingSupplementalOverrides: missingSupplementalOverrides
        )
    }
}

enum SupplementalCursorRole: String, CaseIterable, Identifiable {
    case contextualMenu
    case contextMenuLegacy
    case dragCopy
    case dragLink
    case disappearingItem
    case empty
    case camera
    case camera2
    case iBeamHorizontal
    case countingUp
    case countingDown
    case countingUpDown
    case closeHand
    case openHand
    case poof
    case resizeSquare
    case resizeUp
    case resizeDown
    case resizeLeft
    case resizeRight
    case verticalIBeam
    case zoomIn
    case zoomOut

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .contextualMenu: return "Contextual Menu"
        case .contextMenuLegacy: return "Ctx Menu"
        case .dragCopy: return "Drag Copy"
        case .dragLink: return "Drag Link"
        case .disappearingItem: return "Disappearing Item"
        case .empty: return "Empty"
        case .camera: return "Camera"
        case .camera2: return "Camera 2"
        case .iBeamHorizontal: return "IBeam H."
        case .countingUp: return "Counting Up"
        case .countingDown: return "Counting Down"
        case .countingUpDown: return "Counting Up/Down"
        case .closeHand: return "Closed"
        case .openHand: return "Open"
        case .poof: return "Poof"
        case .resizeSquare: return "Resize Square"
        case .resizeUp: return "Resize Up"
        case .resizeDown: return "Resize Down"
        case .resizeLeft: return "Resize Left"
        case .resizeRight: return "Resize Right"
        case .verticalIBeam: return "Vertical IBeam"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        }
    }

    var mousecapeMappingDescription: String {
        switch self {
        case .contextualMenu: return "Contextual Menu"
        case .contextMenuLegacy: return "Ctx Menu"
        case .dragCopy: return "Drag Copy"
        case .dragLink: return "Drag Link"
        case .disappearingItem: return "Disappearing Item"
        case .empty: return "Empty"
        case .camera: return "Camera"
        case .camera2: return "Camera 2"
        case .iBeamHorizontal: return "IBeam H."
        case .countingUp: return "Counting Up"
        case .countingDown: return "Counting Down"
        case .countingUpDown: return "Counting Up/Down"
        case .closeHand: return "Closed"
        case .openHand: return "Open"
        case .poof: return "Poof"
        case .resizeSquare: return "Resize Square"
        case .resizeUp: return "Resize Up"
        case .resizeDown: return "Resize Down"
        case .resizeLeft: return "Resize Left"
        case .resizeRight: return "Resize Right"
        case .verticalIBeam: return "Vertical IBeam"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        }
    }

    var mappedPrimaryRole: CursorRole {
        switch self {
        case .contextualMenu, .contextMenuLegacy: return .link
        case .dragCopy: return .location
        case .dragLink: return .alternate
        case .disappearingItem, .empty: return .unavailable
        case .camera, .camera2, .resizeSquare: return .precision
        case .iBeamHorizontal: return .text
        case .countingUp, .countingDown, .countingUpDown: return .busy
        case .closeHand, .openHand: return .move
        case .poof: return .unavailable
        case .resizeUp, .resizeDown: return .verticalResize
        case .resizeLeft, .resizeRight: return .horizontalResize
        case .verticalIBeam: return .text
        case .zoomIn, .zoomOut: return .precision
        }
    }
}

enum SidebarCursorItem: Hashable, Identifiable {
    case primary(CursorRole)
    case supplemental(SupplementalCursorRole)

    var id: String {
        switch self {
        case .primary(let role): return "primary.\(role.rawValue)"
        case .supplemental(let role): return "supplemental.\(role.rawValue)"
        }
    }
}

struct SupplementalCursorAssignment: Identifiable {
    let role: SupplementalCursorRole
    let mappedRole: CursorRole
    let appliedPreview: CursorAnimation?
    let sourceURL: URL?
    let isOverride: Bool
    let isResolved: Bool

    var id: SupplementalCursorRole { role }
}

struct UserFacingAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct SystemApplyProgress: Sendable {
    let titleKey: String
    let detailKey: String
    let fraction: Double

    static let preparing = SystemApplyProgress(
        titleKey: "systemApply.progressTitle",
        detailKey: "systemApply.progressPreparing",
        fraction: 0.10
    )
    static let rendering = SystemApplyProgress(
        titleKey: "systemApply.progressTitle",
        detailKey: "systemApply.progressRendering",
        fraction: 0.35
    )
    static let registering = SystemApplyProgress(
        titleKey: "systemApply.progressTitle",
        detailKey: "systemApply.progressRegistering",
        fraction: 0.65
    )
    static let agent = SystemApplyProgress(
        titleKey: "systemApply.progressTitle",
        detailKey: "systemApply.progressAgent",
        fraction: 0.90
    )
    static let restoring = SystemApplyProgress(
        titleKey: "systemApply.restoreProgressTitle",
        detailKey: "systemApply.restoreProgressDetail",
        fraction: 0.65
    )
}

struct SystemCompletionNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        case applied
        case restored
    }

    let id = UUID()
    let kind: Kind
}

@MainActor
final class CursorController: ObservableObject {
    private enum DefaultsKey {
        static let selectedThemeFolderPath = "selectedThemeFolderPath"
    }

    private enum StatusState {
        case startingUp
        case chooseCursorFolder
        case supportedFiles
        case systemApplySuccess
        case systemApplyWarning(String)
        case systemApplyFailure(String)
        case systemRestoreSuccess
        case systemRestoreFailure(String)
        case loaded(folderName: String, resolvedRoleCount: Int, totalRoleCount: Int)
        case loadFailure(String)
    }

    @Published private(set) var selectedFolderURL: URL?
    @Published private(set) var selectedFolderIsValid = false
    @Published private(set) var resolvedRoleCount = 0
    @Published private(set) var assignments: [CursorAssignment] = []
    @Published private(set) var statusText = Localized.string("status.startingUp")
    @Published private(set) var isApplyingSystemCursors = false
    @Published private(set) var isLoadingTheme = false
    @Published private(set) var systemApplyProgress = SystemApplyProgress.preparing
    @Published private(set) var systemCompletionNotice: SystemCompletionNotice?
    @Published var activeAlert: UserFacingAlert?
    @Published var exportSizeMultiplier: Double {
        didSet {
            let clamped = Self.clampExportSizeMultiplier(exportSizeMultiplier)
            if clamped != exportSizeMultiplier {
                exportSizeMultiplier = clamped
            }
        }
    }

    private let cursorSystemApplyService: CursorSystemApplyService
    private let defaults: UserDefaults
    private var overrideURLs: [CursorRole: URL] = [:]
    private var supplementalOverrideURLs: [SupplementalCursorRole: URL] = [:]
    private var currentTheme = CursorTheme(animations: [:], supplementalAnimations: [:])
    private var statusState: StatusState = .startingUp
    private var securityScopedURLs: [URL: URL] = [:]
    private var reloadGeneration: UInt = 0
    private var reloadTask: Task<Void, Never>?
    private var completionDismissTask: Task<Void, Never>?

    init(
        cursorSystemApplyService: CursorSystemApplyService = CursorSystemApplyService(),
        defaults: UserDefaults = .standard
    ) {
        self.cursorSystemApplyService = cursorSystemApplyService
        self.defaults = defaults
        exportSizeMultiplier = 1.0
    }

    deinit {
        reloadTask?.cancel()
        completionDismissTask?.cancel()
        for url in securityScopedURLs.values {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func start() {
        clearLegacyDefaults()
        exportSizeMultiplier = 1.0
        resetToLaunchPlaceholderState()
        setStatus(.chooseCursorFolder)
    }

    func relocalize() {
        statusText = localizedStatusText(for: statusState)
        objectWillChange.send()
    }

    func chooseThemeFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedFolderURL
        panel.prompt = Localized.string("panel.chooseFolder")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        setThemeFolder(url)
    }

    func setThemeFolder(_ url: URL, persistSelection: Bool = true) {
        let normalizedNewURL = url.standardizedFileURL
        let previousURL = selectedFolderURL?.standardizedFileURL
        retainSecurityScopedAccess(to: url)
        selectedFolderURL = url
        if persistSelection {
            defaults.set(normalizedNewURL.path, forKey: DefaultsKey.selectedThemeFolderPath)
        }
        if previousURL != normalizedNewURL, !overrideURLs.isEmpty {
            releaseSecurityScopedAccess(for: Array(overrideURLs.values))
            overrideURLs.removeAll()
        }
        if previousURL != normalizedNewURL, !supplementalOverrideURLs.isEmpty {
            releaseSecurityScopedAccess(for: Array(supplementalOverrideURLs.values))
            supplementalOverrideURLs.removeAll()
        }
        reload()
    }

    @discardableResult
    func handleDroppedItem(at url: URL, selection: SidebarCursorItem?) -> Bool {
        if isDirectory(at: url) {
            setThemeFolder(url)
            return true
        }

        let ext = url.pathExtension.lowercased()
        guard ext == "ani" || ext == "cur" else {
            setStatus(.supportedFiles)
            presentError(Localized.string("status.supportedFiles"))
            return false
        }

        guard let selection else {
            presentError(Localized.string("alert.dropCursorSelectionRequired"))
            return false
        }

        switch selection {
        case .primary(let role):
            applyOverride(at: url, for: role)
        case .supplemental(let role):
            applyOverride(at: url, for: role)
        }
        return true
    }

    func chooseOverride(for role: CursorRole) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedCursorContentTypes
        panel.directoryURL = overrideURLs[role]?.deletingLastPathComponent() ?? selectedFolderURL
        panel.prompt = Localized.string("panel.chooseCursor")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        applyOverride(at: url, for: role)
    }

    func chooseOverride(for role: SupplementalCursorRole) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedCursorContentTypes
        panel.directoryURL = supplementalOverrideURLs[role]?.deletingLastPathComponent() ?? selectedFolderURL
        panel.prompt = Localized.string("panel.chooseCursor")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        applyOverride(at: url, for: role)
    }

    func applyToSystemCursors() {
        guard !isApplyingSystemCursors, !isLoadingTheme else { return }
        dismissSystemCompletionNotice()
        isApplyingSystemCursors = true
        systemApplyProgress = .preparing

        // Resolve the theme and gather parameters on the main actor (this reads
        // @Published state and the loaded cursor files), then hand everything to a
        // background task. The expensive work — image rendering in prepareApply and
        // the Mousecape `ps` conflict check — must NOT run on the main thread, or
        // the UI freezes for the duration of the apply.
        let executableURL: URL
        do {
            guard !currentTheme.animations.isEmpty || !currentTheme.supplementalAnimations.isEmpty else {
                throw CursorError.missingTheme(Localized.string("error.noThemeFolderSelected"))
            }
            guard let executable = Bundle.main.executableURL else {
                throw CursorError.systemCursorApplyFailed(Localized.string("error.systemApplyExecutableMissing"))
            }
            executableURL = executable
        } catch {
            isApplyingSystemCursors = false
            setStatus(.systemApplyFailure(error.localizedDescription))
            presentError(error.localizedDescription)
            return
        }

        let service = cursorSystemApplyService
        let theme = currentTheme
        let sizeMultiplier = exportSizeMultiplier
        let author = defaultAuthorName()
        let bundleIdentifier = Bundle.main.bundleIdentifier

        systemApplyProgress = .rendering

        Task.detached { [service, theme, sizeMultiplier, author, bundleIdentifier, executableURL] in
            do {
                let prepared = try service.prepareApply(
                    theme: theme,
                    sizeMultiplier: sizeMultiplier,
                    author: author,
                    bundleIdentifier: bundleIdentifier,
                    executableURL: executableURL
                )
                let result = try service.applyPrepared(prepared) { progress in
                    Task { @MainActor in
                        self.systemApplyProgress = progress
                    }
                }
                await MainActor.run {
                    self.systemApplyProgress = SystemApplyProgress(
                        titleKey: "systemApply.progressTitle",
                        detailKey: "systemApply.progressDone",
                        fraction: 1.0
                    )
                    self.isApplyingSystemCursors = false
                    if let warning = result.agentWarning {
                        self.setStatus(.systemApplyWarning(warning))
                    } else {
                        self.setStatus(.systemApplySuccess)
                        self.showSystemCompletionNotice(.applied)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isApplyingSystemCursors = false
                    self.setStatus(.systemApplyFailure(error.localizedDescription))
                    self.presentError(error.localizedDescription)
                }
            }
        }
    }

    func restoreSystemCursors() {
        guard !isApplyingSystemCursors else { return }
        dismissSystemCompletionNotice()
        isApplyingSystemCursors = true
        systemApplyProgress = .restoring
        let service = cursorSystemApplyService

        Task.detached {
            do {
                try service.restoreDefaults()
                await MainActor.run {
                    self.isApplyingSystemCursors = false
                    self.setStatus(.systemRestoreSuccess)
                    self.showSystemCompletionNotice(.restored)
                }
            } catch {
                await MainActor.run {
                    self.isApplyingSystemCursors = false
                    self.setStatus(.systemRestoreFailure(error.localizedDescription))
                    self.presentError(error.localizedDescription)
                }
            }
        }
    }

    func reload() {
        reloadGeneration &+= 1
        let generation = reloadGeneration
        reloadTask?.cancel()
        isLoadingTheme = true
        let request = CursorThemeLoadRequest(
            baseDirectory: selectedFolderURL,
            primaryOverrides: overrideURLs,
            supplementalOverrides: supplementalOverrideURLs
        )

        reloadTask = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                try CursorThemeLoader.load(request)
            }
            let result: Result<CursorThemeLoadResult, Error>
            do {
                result = .success(try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                })
            } catch {
                result = .failure(error)
            }

            guard let self, !Task.isCancelled, generation == self.reloadGeneration else { return }
            self.isLoadingTheme = false
            switch result {
            case .success(let resolution):
                for url in resolution.missingSupplementalOverrides {
                    self.releaseSecurityScopedAccess(for: [url])
                    self.supplementalOverrideURLs = self.supplementalOverrideURLs.filter { $0.value.standardizedFileURL != url.standardizedFileURL }
                }
                self.currentTheme = resolution.theme
                self.assignments = self.makeAssignments(
                    from: resolution.theme,
                    resolvedFiles: resolution.filesByRole,
                    fallbackRoles: resolution.fallbackRoles
                )
                self.resolvedRoleCount = self.assignments.filter(\.isResolved).count
                self.selectedFolderIsValid = self.selectedFolderURL != nil
                if let folderURL = self.selectedFolderURL {
                    self.setStatus(.loaded(folderName: folderURL.lastPathComponent, resolvedRoleCount: self.resolvedRoleCount, totalRoleCount: CursorRole.allCases.count))
                } else {
                    self.setStatus(.chooseCursorFolder)
                }
            case .failure(let error):
                guard !(error is CancellationError) else { return }
                self.currentTheme = CursorTheme(animations: [:], supplementalAnimations: [:])
                self.assignments = self.unresolvedAssignments()
                self.resolvedRoleCount = 0
                self.selectedFolderIsValid = false
                self.setStatus(.loadFailure(error.localizedDescription))
                if self.selectedFolderURL != nil {
                    self.presentError(error.localizedDescription)
                }
            }
        }
    }

    func waitForPendingReload() async {
        await reloadTask?.value
    }

    func assignment(for role: CursorRole) -> CursorAssignment? {
        assignments.first(where: { $0.role == role })
    }

    func supplementalAssignment(for role: SupplementalCursorRole) -> SupplementalCursorAssignment {
        let overrideURL = supplementalOverrideURLs[role]
        return SupplementalCursorAssignment(
            role: role,
            mappedRole: role.mappedPrimaryRole,
            appliedPreview: currentTheme[role],
            sourceURL: overrideURL,
            isOverride: overrideURL != nil,
            isResolved: currentTheme[role] != nil
        )
    }

    var exportSizePercentageText: String {
        "\(Int((exportSizeMultiplier * 100).rounded()))%"
    }

    private static func clampExportSizeMultiplier(_ value: Double) -> Double {
        min(max(value, 1.0), 3.0)
    }

    private func makeAssignments(from theme: CursorTheme, resolvedFiles: [CursorRole: URL], fallbackRoles: Set<CursorRole>) -> [CursorAssignment] {
        CursorRole.allCases.map { role in
            let autoResolved = resolvedFiles[role]
            let overrideURL = overrideURLs[role]
            let isOverride = {
                guard let overrideURL else { return false }
                guard let autoResolved else { return true }
                return overrideURL.standardizedFileURL != autoResolved.standardizedFileURL
            }()
            let applied = theme[role]
        return CursorAssignment(
                role: role,
                appliedPreview: applied,
                sourceURL: overrideURL ?? autoResolved,
                isOverride: isOverride,
                isResolved: applied != nil,
                usesArrowFallback: !isOverride && fallbackRoles.contains(role)
            )
        }
    }

    private func unresolvedAssignments() -> [CursorAssignment] {
        CursorRole.allCases.map { role in
            CursorAssignment(
                role: role,
                appliedPreview: nil,
                sourceURL: overrideURLs[role],
                isOverride: overrideURLs[role] != nil,
                isResolved: false,
                usesArrowFallback: false
            )
        }
    }

    private func resetToLaunchPlaceholderState() {
        selectedFolderURL = nil
        selectedFolderIsValid = false
        resolvedRoleCount = 0
        overrideURLs = [:]
        supplementalOverrideURLs = [:]
        currentTheme = CursorTheme(animations: [:], supplementalAnimations: [:])
        assignments = unresolvedAssignments()
    }

    private func clearLegacyDefaults() {
        [
            "calibrationOffsets",
            "isEnabled",
            "selectedBorder",
            "selectedStyle"
        ].forEach { defaults.removeObject(forKey: $0) }
    }

    private func applyOverride(at url: URL, for role: CursorRole) {
        let ext = url.pathExtension.lowercased()
        guard ext == "ani" || ext == "cur" else {
            setStatus(.supportedFiles)
            presentError(Localized.string("status.supportedFiles"))
            return
        }
        if let previousURL = overrideURLs[role] {
            releaseSecurityScopedAccess(for: [previousURL])
        }
        retainSecurityScopedAccess(to: url)
        overrideURLs[role] = url
        reload()
    }

    private func applyOverride(at url: URL, for role: SupplementalCursorRole) {
        let ext = url.pathExtension.lowercased()
        guard ext == "ani" || ext == "cur" else {
            setStatus(.supportedFiles)
            presentError(Localized.string("status.supportedFiles"))
            return
        }
        if let previousURL = supplementalOverrideURLs[role] {
            releaseSecurityScopedAccess(for: [previousURL])
        }
        retainSecurityScopedAccess(to: url)
        supplementalOverrideURLs[role] = url
        reload()
    }

    private func isDirectory(at url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func retainSecurityScopedAccess(to url: URL) {
        let standardizedURL = url.standardizedFileURL
        guard securityScopedURLs[standardizedURL] == nil else { return }
        if url.startAccessingSecurityScopedResource() {
            securityScopedURLs[standardizedURL] = url
        }
    }

    private func releaseSecurityScopedAccess(for urls: [URL]) {
        for url in urls {
            let standardizedURL = url.standardizedFileURL
            if let scopedURL = securityScopedURLs.removeValue(forKey: standardizedURL) {
                scopedURL.stopAccessingSecurityScopedResource()
            }
        }
    }

    private var supportedCursorContentTypes: [UTType] {
        [UTType(filenameExtension: "ani"), UTType(filenameExtension: "cur")].compactMap { $0 }
    }

    func defaultAuthorName() -> String {
        let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty {
            return fullName
        }

        let userName = NSUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !userName.isEmpty {
            return userName
        }

        return Localized.string("export.unknownAuthor")
    }

    private func presentError(_ message: String) {
        activeAlert = UserFacingAlert(
            title: Localized.string("alert.errorTitle"),
            message: message
        )
    }

    private func setStatus(_ state: StatusState) {
        statusState = state
        statusText = localizedStatusText(for: state)
    }

    private func showSystemCompletionNotice(_ kind: SystemCompletionNotice.Kind) {
        completionDismissTask?.cancel()
        let notice = SystemCompletionNotice(kind: kind)
        systemCompletionNotice = notice
        completionDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, self?.systemCompletionNotice?.id == notice.id else { return }
            self?.systemCompletionNotice = nil
        }
    }

    private func dismissSystemCompletionNotice() {
        completionDismissTask?.cancel()
        completionDismissTask = nil
        systemCompletionNotice = nil
    }

    private func localizedStatusText(for state: StatusState) -> String {
        switch state {
        case .startingUp:
            return Localized.string("status.startingUp")
        case .chooseCursorFolder:
            return Localized.string("status.chooseCursorFolder")
        case .supportedFiles:
            return Localized.string("status.supportedFiles")
        case .systemApplySuccess:
            return Localized.string("status.systemApplySuccess")
        case .systemApplyWarning(let message):
            return Localized.string("status.systemApplyWarning", message)
        case .systemApplyFailure(let message):
            return Localized.string("status.systemApplyFailure", message)
        case .systemRestoreSuccess:
            return Localized.string("status.systemRestoreSuccess")
        case .systemRestoreFailure(let message):
            return Localized.string("status.systemRestoreFailure", message)
        case .loaded(let folderName, let resolvedRoleCount, let totalRoleCount):
            let displayFolder = folderName.isEmpty ? Localized.string("app.noFolderSelected") : folderName
            return Localized.string("status.loaded", displayFolder, resolvedRoleCount, totalRoleCount)
        case .loadFailure(let message):
            return Localized.string("status.loadFailure", message)
        }
    }

}

enum CursorError: LocalizedError {
    case missingTheme(String)
    case invalidANI(String)
    case invalidThemeSelection(String)
    case unsupportedCursorPayload
    case systemCursorApplyFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingTheme(let path):
            return Localized.string("error.themeFileMissing", path)
        case .invalidANI(let message):
            return Localized.string("error.aniParsingFailed", message)
        case .invalidThemeSelection(let message):
            return message
        case .unsupportedCursorPayload:
            return Localized.string("error.unsupportedCursorPayload")
        case .systemCursorApplyFailed(let message):
            return message
        }
    }
}
