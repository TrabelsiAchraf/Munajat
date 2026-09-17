import Foundation
import ImageIO
import Testing
@testable import Adhkar

@Suite("Dhikr image export")
struct ShareableDhikrImageTests {
    @MainActor @Test func exportsValidPNGAtTheIntendedSize() throws {
        let category = try #require(DataProvider.adharCategories.first { $0.id == "wearing_clothes" })
        let item = try #require(category.adhkarList.first)
        let export = ShareableDhikrImage(category: category, dhikr: item)
        let data = try export.pngData()
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.png")
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 1080)
        #expect(image.height == 1920)
    }
}
