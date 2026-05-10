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
            return file.categories.sorted { $0.order < $1.order }
        } catch {
            throw LoadError.decodingFailed(error)
        }
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
