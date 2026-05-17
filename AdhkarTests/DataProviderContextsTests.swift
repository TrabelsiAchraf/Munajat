// AdhkarTests/DataProviderContextsTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("DataProvider contexts")
struct DataProviderContextsTests {
    @Test func loadsBundledFile() throws {
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        #expect(contexts.count == 15)
    }

    @Test func eightEmotionsAndSevenTrials() throws {
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        let emotions = contexts.filter { $0.family == .emotion }
        let trials   = contexts.filter { $0.family == .trial }
        #expect(emotions.count == 8)
        #expect(trials.count == 7)
    }

    @Test func everyContextHasNonEmptyTitleInThreeLanguages() throws {
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        for c in contexts {
            #expect(!(c.title.fr ?? "").isEmpty, "\(c.id) missing fr title")
            #expect(!(c.title.en ?? "").isEmpty, "\(c.id) missing en title")
        }
    }

    @Test func everyContextHasUniqueId() throws {
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        let ids = contexts.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
