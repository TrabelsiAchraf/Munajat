//
//  PostPrayerSequence.swift
//  Adhkar
//

import Foundation

/// Prayers after which a step is recited. Display-only: the app has no
/// prayer times, so the user decides whether the step applies.
enum PrayerScope: Hashable {
    case fajr
    case fajrAndMaghrib

    var label: LocalizedText {
        switch self {
        case .fajr:
            LocalizedText(ar: "بعد الفجر", fr: "après Fajr", en: "after Fajr")
        case .fajrAndMaghrib:
            LocalizedText(ar: "بعد الفجر والمغرب", fr: "après Fajr et Maghrib", en: "after Fajr and Maghrib")
        }
    }
}

/// One countable step of the guided sequence.
///
/// `arabic`, `transliteration` and `translation` are non-nil only for steps
/// split out of a JSON item that bundled several dhikr; otherwise the values
/// come from the referenced `Adhkar`.
struct PostPrayerStep: Identifiable, Hashable {
    let id: String
    let itemId: String
    let arabic: String?
    let transliteration: LocalizedText?
    let translation: LocalizedText?
    let repetitions: Int
    let advancesAutomatically: Bool
    let onlyAfter: PrayerScope?

    init(id: String,
         itemId: String,
         arabic: String? = nil,
         transliteration: LocalizedText? = nil,
         translation: LocalizedText? = nil,
         repetitions: Int,
         advancesAutomatically: Bool = false,
         onlyAfter: PrayerScope? = nil) {
        self.id = id
        self.itemId = itemId
        self.arabic = arabic
        self.transliteration = transliteration
        self.translation = translation
        self.repetitions = repetitions
        self.advancesAutomatically = advancesAutomatically
        self.onlyAfter = onlyAfter
    }

    var sourceItem: Adhkar? { PostPrayerSequence.item(for: itemId) }
    var displayArabic: String { arabic ?? sourceItem?.dhikr ?? "" }
    var displayTransliteration: String? {
        let text = transliteration ?? sourceItem?.transliteration
        let resolved = text?.resolved()
        return (resolved?.isEmpty ?? true) ? nil : resolved
    }
    var displayTranslation: String? {
        let text = translation ?? sourceItem?.translation
        let resolved = text?.resolved()
        return (resolved?.isEmpty ?? true) ? nil : resolved
    }
}

/// The post-prayer adhkar of Hisn al-Muslim, in the order of
/// `after_prayer_adhkar` in `adhkar.json` — the order is the source's, not a
/// product decision, and must not be changed.
///
/// An item is split **only when the dhikr it bundles carry different
/// repetition counts**: item 1 (istighfār three times, then the salām formula
/// once) and item 4 (three tasbihāt thirty-three times each, then the tahlīl
/// that completes the hundred). Item 5 holds three sūrahs but each is recited
/// once, and the JSON supplies them as one unit — it stays whole.
enum PostPrayerSequence {
    static let categoryId = "after_prayer_adhkar"

    static var category: AdhkarCategory? {
        DataProvider.adharCategories.first { $0.id == categoryId }
    }

    static func item(for id: String) -> Adhkar? {
        category?.adhkarList.first { $0.id == id }
    }

    static let steps: [PostPrayerStep] = [
        PostPrayerStep(
            id: "istighfar",
            itemId: "after_prayer_adhkar_1",
            arabic: "أَسْتَغْفِرُ اللهَ",
            transliteration: LocalizedText(fr: "Astaghfiru-Llāh", en: "Astaghfiru-Llāh"),
            translation: LocalizedText(
                ar: "أستغفر الله",
                fr: "Je demande pardon à Allah.",
                en: "I ask Allah for forgiveness."),
            repetitions: 3,
            advancesAutomatically: true),

        PostPrayerStep(
            id: "salam",
            itemId: "after_prayer_adhkar_1",
            arabic: "اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ",
            transliteration: LocalizedText(
                fr: "Allāhumma anta-s-salām, wa minka-s-salām, tabārakta yā dhā-l-jalāli wa-l-ikrām",
                en: "Allāhumma anta-s-salām, wa minka-s-salām, tabārakta yā dhā-l-jalāli wa-l-ikrām"),
            translation: LocalizedText(
                fr: "Ô Allah, Tu es la Paix et de Toi vient la paix. Béni sois-Tu, ô Détenteur de la majesté et de la générosité.",
                en: "O Allah, You are As-Salām and from You is all peace, blessed are You, O Possessor of majesty and honour."),
            repetitions: 1),

        PostPrayerStep(id: "tahlil-full", itemId: "after_prayer_adhkar_2", repetitions: 1),
        PostPrayerStep(id: "tahlil-quwwa", itemId: "after_prayer_adhkar_3", repetitions: 1),

        PostPrayerStep(
            id: "subhanallah",
            itemId: "after_prayer_adhkar_4",
            arabic: "سُبْحَانَ اللهِ",
            transliteration: LocalizedText(fr: "Subḥāna-Llāh", en: "Subḥāna-Llāh"),
            translation: LocalizedText(fr: "Gloire à Allah.", en: "How perfect Allah is."),
            repetitions: 33,
            advancesAutomatically: true),

        PostPrayerStep(
            id: "alhamdulillah",
            itemId: "after_prayer_adhkar_4",
            arabic: "الْحَمْدُ لِلَّهِ",
            transliteration: LocalizedText(fr: "Al-ḥamdu li-Llāh", en: "Al-ḥamdu li-Llāh"),
            translation: LocalizedText(fr: "Louange à Allah.", en: "All praise is for Allah."),
            repetitions: 33,
            advancesAutomatically: true),

        PostPrayerStep(
            id: "allahuakbar",
            itemId: "after_prayer_adhkar_4",
            arabic: "اللهُ أَكْبَرُ",
            transliteration: LocalizedText(fr: "Allāhu akbar", en: "Allāhu akbar"),
            translation: LocalizedText(fr: "Allah est le plus grand.", en: "Allah is the greatest."),
            repetitions: 33,
            advancesAutomatically: true),

        PostPrayerStep(
            id: "tahlil-hundred",
            itemId: "after_prayer_adhkar_4",
            arabic: "لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
            transliteration: LocalizedText(
                fr: "Lā ilāha illa-Llāh waḥdahu lā sharīka lah, lahu-l-mulku wa lahu-l-ḥamd, wa huwa ʿalā kulli shay'in qadīr",
                en: "Lā ilāha illa-Llāh waḥdahu lā sharīka lah, lahu-l-mulku wa lahu-l-ḥamd, wa huwa ʿalā kulli shay'in qadīr"),
            translation: LocalizedText(
                fr: "Il n'y a de divinité qu'Allah, Seul, sans associé. À Lui la royauté, à Lui la louange, et Il est capable de toute chose.",
                en: "None has the right to be worshipped except Allah, alone, without partner; to Him belongs all sovereignty and praise, and He is over all things omnipotent."),
            repetitions: 1),

        PostPrayerStep(id: "suras", itemId: "after_prayer_adhkar_5", repetitions: 1),
        PostPrayerStep(id: "ayat-al-kursi", itemId: "after_prayer_adhkar_6", repetitions: 1),
        PostPrayerStep(id: "tahlil-ten", itemId: "after_prayer_adhkar_7",
                       repetitions: 10, onlyAfter: .fajrAndMaghrib),
        PostPrayerStep(id: "beneficial-knowledge", itemId: "after_prayer_adhkar_8",
                       repetitions: 1, onlyAfter: .fajr),
    ]
}
