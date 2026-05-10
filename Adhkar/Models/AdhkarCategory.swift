//
//  AdhkarCategory.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 18/04/2025.
//

import Foundation

struct AdhkarCategory: Identifiable, Hashable, Equatable, Codable {
    let id: String
    let type: AdhkarType
    let title: LocalizedText
    let order: Int
    let section: AdhkarSection?
    let adhkarList: [Adhkar]

    var displayTitle: String { title.resolved() }

    enum CodingKeys: String, CodingKey {
        case id, type, title, order, section
        case adhkarList = "items"
    }
}

struct Adhkar: Identifiable, Hashable, Equatable, Codable {
    let id: String
    let dhikr: String
    let transliteration: LocalizedText?
    let translation: LocalizedText?
    let source: String
    let count: Int
    let audio: String?
    let virtue: LocalizedText?

    enum CodingKeys: String, CodingKey {
        case id
        case dhikr = "arabic"
        case transliteration, translation, source, count, audio, virtue
    }
}

enum AdhkarSection: String, Codable, Hashable {
    case daily
    case prayer
    case eating
    case travel
    case hajj
    case funerals
    case weather
    case social
    case protection
    case healing
    case other
}
