//
//  DataProvider.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 18/04/2025.
//

import Foundation

enum DataProvider {
    static let adharCategories: [AdhkarCategory] = loadCategories()

    enum LoadError: Error, CustomStringConvertible {
        case fileNotFound
        case decodingFailed(Error)

        var description: String {
            switch self {
            case .fileNotFound: return "adhkar.json not found in app bundle"
            case .decodingFailed(let underlying): return "adhkar.json failed to decode: \(underlying)"
            }
        }
    }

    static func loadCategoriesThrowing(from bundle: Bundle = .main) throws -> [AdhkarCategory] {
        guard let url = bundle.url(forResource: "adhkar", withExtension: "json") else {
            throw LoadError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        do {
            let file = try JSONDecoder().decode(AdhkarFile.self, from: data)
            let titles = try loadCategoryTitles(from: bundle)
            return file.categories.map { category in
                let localized = titles[category.id]
                return AdhkarCategory(
                    id: category.id, type: category.type,
                    title: LocalizedText(ar: category.title.ar,
                                         fr: localized?.fr ?? category.title.fr,
                                         en: localized?.en ?? category.title.en),
                    order: category.order, section: category.section,
                    adhkarList: category.adhkarList
                )
            }.sorted { $0.order < $1.order }
        } catch {
            throw LoadError.decodingFailed(error)
        }
    }

    /// Navigation labels live separately so corpus regeneration cannot erase
    /// them or modify any religious text, translation, source or stable ID.
    static func loadCategoryTitles(from bundle: Bundle = .main) throws -> [String: LocalizedText] {
        guard let url = bundle.url(forResource: "category-titles", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([String: LocalizedText].self, from: Data(contentsOf: url))
    }

    private static func loadCategories() -> [AdhkarCategory] {
        do {
            return try loadCategoriesThrowing()
        } catch {
            assertionFailure("\(error)")
            return []
        }
    }
}

private struct AdhkarFile: Codable {
    let version: Int
    let categories: [AdhkarCategory]
}

extension DataProvider {
    static let lifeContexts: [LifeContext] = loadContexts()

    enum ContextsLoadError: Error, CustomStringConvertible {
        case fileNotFound
        case decodingFailed(Error)

        var description: String {
            switch self {
            case .fileNotFound: return "contexts.json not found in app bundle"
            case .decodingFailed(let underlying): return "contexts.json failed to decode: \(underlying)"
            }
        }
    }

    static func loadContextsThrowing(from bundle: Bundle = .main) throws -> [LifeContext] {
        guard let url = bundle.url(forResource: "contexts", withExtension: "json") else {
            throw ContextsLoadError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        do {
            let file = try JSONDecoder().decode(ContextsFile.self, from: data)
            return file.contexts
        } catch {
            throw ContextsLoadError.decodingFailed(error)
        }
    }

    private static func loadContexts() -> [LifeContext] {
        do {
            return try loadContextsThrowing()
        } catch {
            assertionFailure("\(error)")
            return []
        }
    }
}

private struct ContextsFile: Codable {
    let version: Int
    let contexts: [LifeContext]
}
