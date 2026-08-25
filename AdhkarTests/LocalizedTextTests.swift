// AdhkarTests/LocalizedTextTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("LocalizedText", .serialized) // mutates the shared AppleLanguages default
struct LocalizedTextTests {
    let text = LocalizedText(ar: "الرئيسية", fr: "Accueil", en: "Home")

    /// Runs `body` with `AppleLanguages` set to `languages`, then restores it.
    private func withDeviceLanguages(_ languages: [String], _ body: () -> Void) {
        let key = "AppleLanguages"
        let previous = UserDefaults.standard.array(forKey: key)
        UserDefaults.standard.set(languages, forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        body()
    }

    // MARK: - Supported languages

    @Test("the three supported languages each resolve to their own string",
          arguments: [("fr-FR", "Accueil"), ("fr-SN", "Accueil"),
                      ("en-US", "Home"), ("ar-SA", "الرئيسية")])
    func supportedLanguage(tag: String, expected: String) {
        withDeviceLanguages([tag]) {
            #expect(text.resolved() == expected)
        }
    }

    // MARK: - Fallback

    // Regression: every unsupported language used to land on Arabic, so a
    // Turkish or Indonesian device showed an Arabic interface.
    @Test("an unsupported language falls back to English, not Arabic",
          arguments: ["tr-TR", "id-ID", "ur-PK", "ms-MY", "de-DE", "es-ES", "pt-BR"])
    func unsupportedLanguageFallsBackToEnglish(tag: String) {
        withDeviceLanguages([tag]) {
            #expect(text.resolved() == "Home")
        }
    }

    @Test func arabicOnlyTextStillResolvesForAnUnsupportedLanguage() {
        withDeviceLanguages(["tr-TR"]) {
            #expect(LocalizedText(ar: "الرئيسية").resolved() == "الرئيسية")
        }
    }

    @Test func frenchTextIsUsedWhenEnglishIsMissing() {
        withDeviceLanguages(["tr-TR"]) {
            #expect(LocalizedText(fr: "Accueil").resolved() == "Accueil")
        }
    }

    // MARK: - Layout direction

    @Test func onlyArabicMirrorsTheLayout() {
        withDeviceLanguages(["ar-SA"]) {
            #expect(LocalizedText.preferredLayoutDirection == .rightToLeft)
        }
        for tag in ["fr-FR", "en-US", "tr-TR"] {
            withDeviceLanguages([tag]) {
                #expect(LocalizedText.preferredLayoutDirection == .leftToRight)
            }
        }
    }
}
