import Testing
@testable import Cursie

struct SparkleUpdaterTests {
    @MainActor
    @Test
    func updateStateShowsIndicatorWhenUpdateIsMarkedAvailable() {
        let state = SparkleUpdateState()

        #expect(!state.hasAvailableUpdate)

        state.markAvailableUpdate(displayVersion: "1.0.9")

        #expect(state.hasAvailableUpdate)
        #expect(state.availableUpdate?.displayVersion == "1.0.9")
    }

    @MainActor
    @Test
    func updateStateClearsIndicatorWhenUpdateIsCleared() {
        let state = SparkleUpdateState()
        state.markAvailableUpdate(displayVersion: "1.0.9")

        state.clearAvailableUpdate()

        #expect(!state.hasAvailableUpdate)
        #expect(state.availableUpdate == nil)
    }
}
