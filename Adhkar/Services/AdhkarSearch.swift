import Foundation

/// Build the small offline index once per screen, rather than normalizing the
/// entire corpus on every keystroke. Match in any of the three languages.
struct AdhkarSearch {
    private struct Entry {
        let category: AdhkarCategory
        let title: String
        let content: String
    }
    private let entries: [Entry]

    init(categories: [AdhkarCategory]) {
        entries = categories.map { category in
            let titles = Self.strings(category.title)
            let content = category.adhkarList.flatMap { item in
                [item.dhikr] + Self.strings(item.translation) + Self.strings(item.transliteration)
            }
            return Entry(category: category, title: Self.normalize(titles.joined(separator: " ")),
                         content: Self.normalize(content.joined(separator: " ")))
        }
    }

    func results(for query: String) -> [AdhkarCategory] {
        let tokens = Self.normalize(query).split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return [] }
        let matches = entries.filter { entry in
            tokens.allSatisfy { entry.title.contains($0) || entry.content.contains($0) }
        }
        // Category names first, with the most concise match first. For example
        // "apres priere" should lead to "Après la prière", before the longer
        // "Prière sur le Prophète après le tachahhoud".
        return matches.filter { entry in tokens.allSatisfy { entry.title.contains($0) } }
            .sorted { lhs, rhs in
                if lhs.title.count != rhs.title.count { return lhs.title.count < rhs.title.count }
                return lhs.category.order < rhs.category.order
            }.map(\.category)
            + matches.filter { entry in !tokens.allSatisfy { entry.title.contains($0) } }.map(\.category)
    }

    private static func strings(_ text: LocalizedText?) -> [String] {
        [text?.ar, text?.fr, text?.en].compactMap { $0 }
    }

    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        var result = ""
        for scalar in folded.unicodeScalars {
            if scalar.value == 0x0640 || CharacterSet.nonBaseCharacters.contains(scalar) { continue }
            switch scalar.value {
            case 0x0622, 0x0623, 0x0625, 0x0671: result.append("ا")
            case 0x0649: result.append("ي")
            default:
                result.append(CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " ")
            }
        }
        return result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
