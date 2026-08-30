import Foundation
import Testing
@testable import Cursie

struct LocalizationControllerTests {
    @Test
    func restoresSparkleLanguageFromStoredAppLanguage() throws {
        let suiteName = "LocalizationControllerTests.restore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.korean.rawValue, forKey: "appLanguageOverride")
        defaults.set(["en"], forKey: "AppleLanguages")

        let controller = LocalizationController(defaults: defaults)

        #expect(controller.selectedLanguage == .korean)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ko"])
    }

    @Test
    func changingAppLanguageAlsoChangesSparkleLanguage() throws {
        let suiteName = "LocalizationControllerTests.change.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = LocalizationController(defaults: defaults)

        controller.setLanguage(.portugueseBrazil)

        #expect(controller.selectedLanguage == .portugueseBrazil)
        #expect(defaults.string(forKey: "appLanguageOverride") == AppLanguage.portugueseBrazil.rawValue)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["pt-BR"])
    }
}
