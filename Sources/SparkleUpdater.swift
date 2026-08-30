import Combine
import Sparkle
import SwiftUI

struct SparkleAvailableUpdate: Equatable {
    let displayVersion: String
}

@MainActor
final class SparkleUpdateState: NSObject, ObservableObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    @Published private(set) var availableUpdate: SparkleAvailableUpdate?

    var hasAvailableUpdate: Bool {
        availableUpdate != nil
    }

    @objc var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func markAvailableUpdate(displayVersion: String) {
        availableUpdate = SparkleAvailableUpdate(displayVersion: displayVersion)
    }

    func clearAvailableUpdate() {
        availableUpdate = nil
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        markAvailableUpdate(displayVersion: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        clearAvailableUpdate()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        clearAvailableUpdate()
    }

    @objc(standardUserDriverShouldHandleShowingScheduledUpdate:andInImmediateFocus:)
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    @objc(standardUserDriverWillHandleShowingUpdate:forUpdate:state:)
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if state.userInitiated {
            clearAvailableUpdate()
        } else {
            markAvailableUpdate(displayVersion: update.displayVersionString)
        }
    }

    @objc(standardUserDriverDidReceiveUserAttentionForUpdate:)
    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        clearAvailableUpdate()
    }

    @objc
    func standardUserDriverWillFinishUpdateSession() {
        clearAvailableUpdate()
    }
}

@MainActor
final class SparkleUpdaterController {
    static let shared = SparkleUpdaterController()

    let updaterController: SPUStandardUpdaterController
    let updateState: SparkleUpdateState

    private var hasRequestedAvailableUpdateCheck = false

    private init() {
        let updateState = SparkleUpdateState()
        self.updateState = updateState
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updateState,
            userDriverDelegate: updateState
        )
    }

    func checkForAvailableUpdateOnce() {
        guard !hasRequestedAvailableUpdateCheck else { return }
        hasRequestedAvailableUpdateCheck = true
        checkForAvailableUpdateWhenReady(remainingAttempts: 3)
    }

    func showAvailableUpdate() {
        updateState.clearAvailableUpdate()
        updaterController.updater.checkForUpdates()
    }

    private func checkForAvailableUpdateWhenReady(remainingAttempts: Int) {
        guard remainingAttempts > 0 else { return }
        let updater = updaterController.updater
        if !updater.sessionInProgress {
            updater.checkForUpdateInformation()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkForAvailableUpdateWhenReady(remainingAttempts: remainingAttempts - 1)
        }
    }
}

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    private var cancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: \.canCheckForUpdates, on: self)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button(Localized.string("menu.checkForUpdates")) {
            updater.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}
