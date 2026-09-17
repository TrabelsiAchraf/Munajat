import Foundation
import Testing
@testable import Adhkar

@Suite("Multilingual category navigation and search")
struct AdhkarSearchTests {
    @Test func everyCategoryHasFrenchAndEnglishNavigationLabels() throws {
        let categories = try DataProvider.loadCategoriesThrowing()
        let titles = try DataProvider.loadCategoryTitles()
        #expect(categories.count == 133)
        #expect(Set(titles.keys) == Set(categories.map(\.id)))
        for category in categories {
            #expect(category.title.fr?.isEmpty == false, "Missing FR: \(category.id)")
            #expect(category.title.en?.isEmpty == false, "Missing EN: \(category.id)")
            #expect(category.title.ar?.isEmpty == false, "Missing AR: \(category.id)")
        }
    }

    @Test(arguments: [("matin", "morning_adhkar"), ("evening", "evening_adhkar"),
                      ("apres priere", "after_prayer_adhkar"), ("اذكار الصباح", "morning_adhkar")])
    func categoryTitlesAreSearchable(query: String, expected: String) throws {
        let search = AdhkarSearch(categories: try DataProvider.loadCategoriesThrowing())
        #expect(search.results(for: query).contains { $0.id == expected })
        #expect(search.results(for: query).first?.id == expected)
    }

    @Test func searchesTranslationAndTransliteration() {
        let category = AdhkarCategory(id: "sample", type: .wakeUp,
            title: LocalizedText(ar: "عنوان", fr: "Au réveil", en: "Waking up"),
            order: 1, section: .daily,
            adhkarList: [Adhkar(id: "sample_1", dhikr: "الْحَمْدُ لِلَّهِ", 
                transliteration: LocalizedText(fr: "Al-ḥamdu lillāhi"),
                translation: LocalizedText(fr: "Louange à Allah", en: "All praise is for Allah"),
                source: "source", count: 1, audio: nil, virtue: nil)])
        let search = AdhkarSearch(categories: [category])
        for query in ["louange", "PRAISE", "hamdu", "lillahi", "الحمد", "  reveil  "] {
            #expect(search.results(for: query).map(\.id) == ["sample"], "No match: \(query)")
        }
        for query in ["", " \n ", "ـَُ", "!!!", "unrelated", "louange unrelated"] {
            #expect(search.results(for: query).isEmpty)
        }
    }

    @Test func titleMatchesRankAboveLongTextMatches() {
        let item = Adhkar(id: "one", dhikr: "النص", transliteration: nil,
                         translation: LocalizedText(fr: "Le matin"), source: "", count: 1, audio: nil, virtue: nil)
        let textMatch = AdhkarCategory(id: "text", type: .wakeUp, title: LocalizedText(en: "First"), order: 1, section: .daily, adhkarList: [item])
        let titleMatch = AdhkarCategory(id: "title", type: .wakeUp, title: LocalizedText(fr: "Matin"), order: 2, section: .daily, adhkarList: [])
        #expect(AdhkarSearch(categories: [textMatch, titleMatch]).results(for: "matin").map(\.id) == ["title", "text"])
    }
}
