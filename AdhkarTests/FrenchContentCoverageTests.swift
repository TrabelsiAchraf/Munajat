// AdhkarTests/FrenchContentCoverageTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("French content coverage")
struct FrenchContentCoverageTests {
    /// Guards the ASO promise: every dhikr surfaced by a life context must
    /// have a French translation (the top download countries are
    /// francophone). Fails loudly if a data regeneration drops them.
    @Test func everyContextReferencedDhikrHasFrenchTranslation() throws {
        let categories = try DataProvider.loadCategoriesThrowing(from: Bundle.main)
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        let byId = Dictionary(
            uniqueKeysWithValues: categories.flatMap(\.adhkarList).map { ($0.id, $0) }
        )
        for context in contexts {
            for id in context.dhikrIds {
                let dhikr = try #require(byId[id], "context \(context.id) references missing item \(id)")
                // Bound to a `let` rather than inlined: #expect's macro mis-instruments
                // `!(optional-chain ?? default).isEmpty` (traces `.isEmpty` as `Optional<()>`
                // instead of `Bool`), causing spurious failures even when the value is
                // non-empty. A plain Bool argument sidesteps the macro expansion bug.
                let hasFrenchTranslation = !(dhikr.translation?.fr ?? "").isEmpty
                #expect(hasFrenchTranslation, "\(id) (context \(context.id)) missing fr translation")
            }
        }
    }

    @Test func overallFrenchCoverageAtLeast250Items() throws {
        let categories = try DataProvider.loadCategoriesThrowing(from: Bundle.main)
        let items = categories.flatMap(\.adhkarList)
        let withFr = items.filter { !($0.translation?.fr ?? "").isEmpty }
        #expect(withFr.count >= 250, "only \(withFr.count)/\(items.count) items have a French translation")
    }

    /// Pins the exact fr text for the two short, generic Arabic items that
    /// went through the enrichment script's short-text fallback (matched by
    /// substring containment, not tokens — "سبحان الله" and "الله أكبر" are
    /// too short/common to token-match safely). A prior fallback version
    /// picked the *first* substring-containing candidate in source order and
    /// silently produced a wrong translation for both; this locks the
    /// correct, source-verbatim text so a fallback regression fails loudly
    /// instead of just being non-empty.
    @Test func iconicShortDhikrHaveTheCorrectFrenchTranslation() throws {
        let categories = try DataProvider.loadCategoriesThrowing(from: Bundle.main)
        let byId = Dictionary(
            uniqueKeysWithValues: categories.flatMap(\.adhkarList).map { ($0.id, $0) }
        )
        let subhanAllah = try #require(byId["duaa_of_amazement_and_joy_1"])
        #expect(subhanAllah.translation?.fr == "« Gloire à Allah. »")

        let allahuAkbar = try #require(byId["duaa_of_amazement_and_joy_2"])
        #expect(allahuAkbar.translation?.fr == "« Allah est le plus Grand. »")
    }
}
