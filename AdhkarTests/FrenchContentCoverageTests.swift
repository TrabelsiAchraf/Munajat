// AdhkarTests/FrenchContentCoverageTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("French content coverage")
struct FrenchContentCoverageTests {
    /// Dhikr ids that are legitimately unmatched against the pinned French
    /// source despite being context-referenced — never a hand-sourced
    /// translation (policy: no religious content without user validation).
    /// Each entry must be justified here; this set exists so the coverage
    /// guard below stays strict for every OTHER context-referenced id.
    ///
    /// - morning_adhkar_10 ("حسبي الله لا إله إلا هو عليه توكلت وهو رب
    ///   العرش العظيم", recited 7x): the pinned source has no faithful
    ///   entry for this exact wording. The closest candidate (source id
    ///   142, "حَسْبُنَا اللهُ وَنِعْمَ الْوَكِيلُ") is a different, shorter
    ///   dua — plural "us" vs. this item's singular "me", and missing the
    ///   "rabbil-'arshil-'azim" clause entirely. Surfaced to Achraf as a
    ///   post-merge manual-sourcing option; ships with the English fallback
    ///   until then.
    static let knownMissingFrench: Set<String> = ["morning_adhkar_10"]

    /// Guards the ASO promise: every dhikr surfaced by a life context must
    /// have a French translation (the top download countries are
    /// francophone), except the documented `knownMissingFrench` exceptions.
    /// Fails loudly if a data regeneration drops any other one.
    @Test func everyContextReferencedDhikrHasFrenchTranslation() throws {
        let categories = try DataProvider.loadCategoriesThrowing(from: Bundle.main)
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        let byId = Dictionary(
            uniqueKeysWithValues: categories.flatMap(\.adhkarList).map { ($0.id, $0) }
        )
        for context in contexts {
            for id in context.dhikrIds {
                if Self.knownMissingFrench.contains(id) { continue }
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

    /// after_prayer_adhkar_5 recites the three Quls in full (~40 tokens);
    /// its only correct source counterpart is a short abbreviated reference
    /// caption naming the surahs, which a naive token-count-ratio gate would
    /// reject outright. Pins that the matcher's bypass for this class of
    /// candidate keeps working and keeps pointing at the right surahs.
    @Test func afterPrayerQulsMentionsAlIkhlas() throws {
        let categories = try DataProvider.loadCategoriesThrowing(from: Bundle.main)
        let byId = Dictionary(
            uniqueKeysWithValues: categories.flatMap(\.adhkarList).map { ($0.id, $0) }
        )
        let quls = try #require(byId["after_prayer_adhkar_5"])
        let mentionsAlIkhlas = (quls.translation?.fr ?? "").contains("Al-Ikhlas")
        #expect(mentionsAlIkhlas, "after_prayer_adhkar_5 fr should reference Al-Ikhlas: \(quls.translation?.fr ?? "nil")")
    }

    /// Structural guard against the matching-algorithm class of bug fixed in
    /// this file's companion script: a short/generic French candidate
    /// (e.g. "Au nom d'Allah.") silently attaching itself to a long Arabic
    /// item it doesn't actually translate. A genuine translation of a long
    /// dhikr is never a handful of words — if one shows up that short, it's
    /// almost certainly a mismatched candidate, not a real translation.
    @Test func noLongItemHasASuspiciouslyShortFrenchTranslation() throws {
        let categories = try DataProvider.loadCategoriesThrowing(from: Bundle.main)
        let items = categories.flatMap(\.adhkarList)
        for item in items {
            guard item.dhikr.count > 250, let fr = item.translation?.fr, !fr.isEmpty else { continue }
            #expect(fr.count >= 30, "\(item.id): arabic is \(item.dhikr.count) chars but fr is only \(fr.count) chars: \(fr)")
        }
    }
}
