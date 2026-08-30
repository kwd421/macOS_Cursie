import AppKit
import Foundation

protocol CursorAgentManaging {
    func saveAppliedCape(_ cape: [String: Any]) throws
    func loadAppliedCape() throws -> [String: Any]?
    func installLaunchAgent(bundleIdentifier: String) throws
    func verifyLaunchAgentReady(timeout: TimeInterval) throws
    func stopLaunchAgent() throws
    func removeLaunchAgentPlist() throws
    func removeAppliedCape() throws
    func removePersistedState() throws
}

protocol CursorApplyConflictChecking {
    func activeConflictDescription() -> String?
}

struct CursorAgentManager {
    // Keep the original CapeForge launchd label so existing installs update in
    // place instead of leaving an orphaned login agent behind.
    static let label = "com.seinel.capeforge.cursor-agent"
    private static let activeStatus = "active"
    private static let failedStatusPrefix = "failed:"
    private static let idleStatus = "idle"

    private let fileManager = FileManager.default

    var applicationSupportDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Cursie", isDirectory: true)
    }

    var appliedCapeURL: URL {
        applicationSupportDirectory.appendingPathComponent("AppliedCursor.cape")
    }

    var launchAgentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(Self.label).plist")
    }

    var agentLogURL: URL {
        applicationSupportDirectory.appendingPathComponent("CursorAgent.log")
    }

    var agentStatusURL: URL {
        applicationSupportDirectory.appendingPathComponent("CursorAgent.status")
    }

    func saveAppliedCape(_ cape: [String: Any]) throws {
        try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: cape, format: .xml, options: 0)
        try data.write(to: appliedCapeURL, options: .atomic)
    }

    func loadAppliedCape() throws -> [String: Any]? {
        guard fileManager.fileExists(atPath: appliedCapeURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: appliedCapeURL)
        return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    }

    func installLaunchAgent(bundleIdentifier: String) throws {
        try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? removeAgentStatus()
        let plist = Self.launchAgentPropertyList(
            bundleIdentifier: bundleIdentifier,
            logPath: agentLogURL.path
        )
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentURL, options: .atomic)

        // Remove any previously loaded instance so launchd picks up the refreshed
        // plist at the next login. We intentionally do NOT bootstrap/kickstart the
        // agent here: the foreground apply already set the system cursor, so running
        // the agent now would only spawn a background process that briefly shows a
        // Dock icon and reads as "running in the background." The agent just needs to
        // run at the NEXT login, which RunAtLoad handles when launchd loads this plist.
        try? stopLaunchAgent()
    }

    static func launchAgentPropertyList(bundleIdentifier: String, logPath: String) -> [String: Any] {
        [
            "Label": Self.label,
            "ProgramArguments": [
                "/usr/bin/open",
                "-gj",
                "-n",
                "-b",
                bundleIdentifier,
                "--args",
                "--cursor-agent"
            ],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath
        ]
    }

    func verifyLaunchAgentReady(timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastStatus: String?

        while Date() < deadline {
            if let status = try? readAgentStatus() {
                lastStatus = status
                if status == Self.activeStatus {
                    return
                }
                if status.hasPrefix(Self.failedStatusPrefix) {
                    let message = String(status.dropFirst(Self.failedStatusPrefix.count))
                    throw CursorError.systemCursorApplyFailed(message)
                }
            }

            if !isLaunchAgentLoaded() {
                throw CursorError.systemCursorApplyFailed("LaunchAgent is not loaded: \(Self.label)")
            }

            Thread.sleep(forTimeInterval: 0.1)
        }

        let suffix = lastStatus.map { " Last status: \($0)" } ?? ""
        throw CursorError.systemCursorApplyFailed("LaunchAgent did not become ready within \(timeout)s.\(suffix)")
    }

    func stopLaunchAgent() throws {
        guard isLaunchAgentLoaded() else {
            return
        }

        do {
            _ = try runLaunchctl(["bootout", launchctlServicePath])
        } catch {
            if !isLaunchAgentLoaded() {
                return
            }
            throw error
        }

        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if !isLaunchAgentLoaded() {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        throw CursorError.systemCursorApplyFailed("LaunchAgent is still loaded after bootout: \(Self.label)")
    }

    func removePersistedState() throws {
        try removeLaunchAgentPlist()
        try removeAppliedCape()
        try removeAgentStatus()
    }

    func removeLaunchAgentPlist() throws {
        if fileManager.fileExists(atPath: launchAgentURL.path) {
            try fileManager.removeItem(at: launchAgentURL)
        }
    }

    func removeAppliedCape() throws {
        if fileManager.fileExists(atPath: appliedCapeURL.path) {
            try fileManager.removeItem(at: appliedCapeURL)
        }
    }

    func writeAgentStatusActive() throws {
        try writeAgentStatus(Self.activeStatus)
    }

    func writeAgentStatusFailed(_ message: String) throws {
        try writeAgentStatus("\(Self.failedStatusPrefix)\(message)")
    }

    func writeAgentStatusIdle() throws {
        try writeAgentStatus(Self.idleStatus)
    }

    private func removeAgentStatus() throws {
        if fileManager.fileExists(atPath: agentStatusURL.path) {
            try fileManager.removeItem(at: agentStatusURL)
        }
    }

    private func readAgentStatus() throws -> String? {
        guard fileManager.fileExists(atPath: agentStatusURL.path) else {
            return nil
        }
        return try String(contentsOf: agentStatusURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeAgentStatus(_ status: String) throws {
        try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        try status.write(to: agentStatusURL, atomically: true, encoding: .utf8)
    }

    private var launchctlDomain: String {
        "gui/\(getuid())"
    }

    private var launchctlServicePath: String {
        "\(launchctlDomain)/\(Self.label)"
    }

    private func isLaunchAgentLoaded() -> Bool {
        (try? runLaunchctl(["print", launchctlServicePath])) != nil
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()

        // Drain the pipe BEFORE waiting for exit. launchctl (e.g. `print`) can
        // emit more than the OS pipe buffer (~64 KB); if we waitUntilExit() first
        // the child blocks writing to a full pipe while we block waiting for it —
        // a permanent deadlock. readDataToEndOfFile() consumes output as it
        // arrives and returns once the child closes the pipe on exit.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw CursorError.systemCursorApplyFailed("launchctl \(arguments.joined(separator: " ")) failed: \(output)")
        }
        return output
    }
}

extension CursorAgentManager: CursorAgentManaging {}

struct MousecapeConflictChecker: CursorApplyConflictChecking {
    private let conflictingBundleIdentifiers = [
        "com.alexzielenski.Mousecape",
        "com.alexzielenski.mousecloakhelper"
    ]

    func activeConflictDescription() -> String? {
        if let application = NSWorkspace.shared.runningApplications.first(where: { application in
            guard let bundleIdentifier = application.bundleIdentifier else { return false }
            return conflictingBundleIdentifiers.contains(bundleIdentifier)
        }) {
            return application.localizedName ?? application.bundleIdentifier ?? "Mousecape"
        }

        return activeMousecapeProcess()
    }

    private func activeMousecapeProcess() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let data: Data
        do {
            try process.run()
            // Drain stdout BEFORE waitUntilExit(). `ps -axo pid=,comm=` prints the
            // full executable path per process; on a machine running many processes
            // the output easily exceeds the OS pipe buffer (~64 KB). Waiting for exit
            // first would let `ps` block on a full pipe while we block waiting for it,
            // freezing the caller forever. (This runs on the main actor during
            // prepareApply, so the deadlock froze the whole UI.)
            data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        return output
            .split(separator: "\n")
            .compactMap { line -> String? in
                let text = String(line)
                let lowercased = text.lowercased()
                guard lowercased.contains("mousecape") || lowercased.contains("mousecloak") else {
                    return nil
                }
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .first
    }
}

struct CursorSystemApplyService: @unchecked Sendable {
    struct PreparedApply: @unchecked Sendable {
        let plan: CursorApplyPlan
        let cape: [String: Any]
        let bundleIdentifier: String
    }

    struct ApplyResult: Sendable {
        let agentReady: Bool
        let agentWarning: String?
    }

    private let capeBuilder: CursorCapeBuilder
    private let agentManager: CursorAgentManaging
    private let conflictChecker: CursorApplyConflictChecking
    private let makeApplicator: () throws -> SystemCursorApplying

    init(
        capeBuilder: CursorCapeBuilder = CursorCapeBuilder(),
        agentManager: CursorAgentManaging = CursorAgentManager(),
        conflictChecker: CursorApplyConflictChecking = MousecapeConflictChecker(),
        makeApplicator: @escaping () throws -> SystemCursorApplying = { try SystemCursorApplicator.live() }
    ) {
        self.capeBuilder = capeBuilder
        self.agentManager = agentManager
        self.conflictChecker = conflictChecker
        self.makeApplicator = makeApplicator
    }

    func apply(
        theme: CursorTheme,
        sizeMultiplier: Double,
        author: String,
        bundleIdentifier: String?,
        executableURL: URL
    ) throws {
        let prepared = try prepareApply(
            theme: theme,
            sizeMultiplier: sizeMultiplier,
            author: author,
            bundleIdentifier: bundleIdentifier,
            executableURL: executableURL
        )
        _ = try applyPrepared(prepared)
    }

    func prepareApply(
        theme: CursorTheme,
        sizeMultiplier: Double,
        author: String,
        bundleIdentifier: String?,
        executableURL: URL
    ) throws -> PreparedApply {
        if let conflict = conflictChecker.activeConflictDescription() {
            throw CursorError.systemCursorApplyFailed(Localized.string("error.mousecapeConflict", conflict))
        }

        try CursorAgentExecutableLocation.validate(executableURL)
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            throw CursorError.systemCursorApplyFailed(Localized.string("error.systemApplyBundleIdentifierMissing"))
        }
        let identifier = "local.\(bundleIdentifier).system.\(UUID().uuidString.lowercased())"
        let plan = try capeBuilder.makePlan(theme: theme, sizeMultiplier: sizeMultiplier)
        let cape = try capeBuilder.makeCape(
            name: "Cursie Applied",
            author: author,
            identifier: identifier,
            plan: plan
        )
        return PreparedApply(plan: plan, cape: cape, bundleIdentifier: bundleIdentifier)
    }

    func applyPrepared(
        _ prepared: PreparedApply,
        progress: (@Sendable (SystemApplyProgress) -> Void)? = nil
    ) throws -> ApplyResult {
        let applicator = try makeApplicator()
        var foregroundApplySucceeded = false
        let agentWarning: String? = nil

        do {
            progress?(.registering)
            try applicator.apply(prepared.plan)
            foregroundApplySucceeded = true
            progress?(.agent)
            try agentManager.saveAppliedCape(prepared.cape)
            try agentManager.installLaunchAgent(bundleIdentifier: prepared.bundleIdentifier)
        } catch {
            try? agentManager.stopLaunchAgent()
            try? agentManager.removePersistedState()
            if foregroundApplySucceeded {
                try? makeApplicator().restoreDefaults()
            }
            throw error
        }

        return ApplyResult(agentReady: agentWarning == nil, agentWarning: agentWarning)
    }

    func restoreDefaults() throws {
        var failures: [String] = []

        do {
            try agentManager.stopLaunchAgent()
        } catch {
            failures.append(error.localizedDescription)
        }

        do {
            try agentManager.removePersistedState()
        } catch {
            failures.append(error.localizedDescription)
        }

        do {
            try makeApplicator().restoreDefaults()
        } catch {
            failures.append(error.localizedDescription)
        }

        guard failures.isEmpty else {
            throw CursorError.systemCursorApplyFailed(failures.joined(separator: "\n"))
        }
    }

}

enum CursorAgentExecutableLocation {
    static func validate(_ executableURL: URL) throws {
        let path = executableURL.standardizedFileURL.path
        guard !path.hasPrefix("/Volumes/"), !path.contains("/AppTranslocation/") else {
            throw CursorError.systemCursorApplyFailed(Localized.string("error.installCursieBeforeApplying"))
        }
    }
}

@MainActor
final class CursorAgentRuntime {
    static let shared = CursorAgentRuntime()
    static let periodicReapplyInterval: TimeInterval? = nil
    static let staysResidentAfterLoginReapply = false

    private let manager = CursorAgentManager()

    func run() -> Never {
        NSApplication.shared.setActivationPolicy(.accessory)
        reapply()
        exit(EXIT_SUCCESS)
    }

    func reapply() {
        do {
            guard let cape = try manager.loadAppliedCape() else {
                try? manager.writeAgentStatusIdle()
                return
            }
            let plan = try CursorApplyPlan(cape: cape)
            try SystemCursorApplicator.live().apply(plan)
            try? manager.writeAgentStatusActive()
        } catch {
            try? manager.writeAgentStatusFailed(error.localizedDescription)
            fputs("Cursie cursor agent apply failed: \(error.localizedDescription)\n", stderr)
        }
    }
}
