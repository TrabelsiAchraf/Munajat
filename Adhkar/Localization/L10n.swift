//
//  L10n.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import Foundation

/// Centralised UI strings. Reuses the existing `LocalizedText` (AR/FR/EN)
/// from Phase 2 — no separate String Catalog needed.
enum L10n {
    // Tab bar
    static let tabHome      = LocalizedText(ar: "الرئيسية",  fr: "Accueil",   en: "Home")
    static let tabFavorites = LocalizedText(ar: "المفضلة",   fr: "Favoris",   en: "Favorites")
    static let tabSearch    = LocalizedText(ar: "بحث",       fr: "Recherche", en: "Search")
    static let tabSettings  = LocalizedText(ar: "الإعدادات", fr: "Réglages",  en: "Settings")

    // Home
    static let homeTitle           = LocalizedText(ar: "أذكار", fr: "Adhkar", en: "Adhkar")
    static let suggestedForNow     = LocalizedText(ar: "الذكر المقترح الآن", fr: "Suggéré maintenant", en: "Suggested for now")
    static let itemsCountSuffix    = LocalizedText(ar: "ذكر", fr: "invocations", en: "items")

    // Favorites
    static let favoritesEmptyTitle = LocalizedText(ar: "لا يوجد مفضل بعد", fr: "Aucun favori pour l'instant", en: "No favorites yet")
    static let favoritesEmptyHint  = LocalizedText(ar: "اضغط على القلب في إحدى البطاقات لإضافتها هنا.", fr: "Tape sur le cœur d'une carte pour l'ajouter ici.", en: "Tap the heart on any card to add it here.")

    // Search
    static let searchPrompt        = LocalizedText(ar: "ابحث عن ذكر…", fr: "Recherche un dhikr…", en: "Search a dhikr…")
    static let searchPlaceholder   = LocalizedText(ar: "ابحث بالعنوان أو الفئة أو النص العربي.", fr: "Recherche par titre, catégorie ou texte arabe.", en: "Search by title, category, or Arabic text.")
    static let searchEmptyResults  = LocalizedText(ar: "لا يوجد نتائج", fr: "Aucun résultat", en: "No results")
    static let searchTryAnother    = LocalizedText(ar: "جرّب كلمة أخرى.", fr: "Essaie un autre mot.", en: "Try another word.")

    // Settings
    static let settingsAbout            = LocalizedText(ar: "حول التطبيق", fr: "À propos", en: "About")
    static let settingsContentSource    = LocalizedText(ar: "مصدر المحتوى", fr: "Source du contenu", en: "Content source")
    static let settingsContentSourceVal = LocalizedText(ar: "حصن المسلم — سعيد القحطاني", fr: "Hisn al-Muslim — Saʿīd al-Qaḥṭānī", en: "Hisn al-Muslim — Saʿīd al-Qaḥṭānī")
    static let settingsVersion          = LocalizedText(ar: "الإصدار", fr: "Version", en: "Version")
    static let settingsNotifs           = LocalizedText(ar: "التنبيهات", fr: "Notifications", en: "Notifications")
    static let settingsNotifsHelp       = LocalizedText(ar: "تذكير يومي بأذكار الصباح والمساء والنوم.", fr: "Rappels quotidiens pour les adhkar du matin, du soir et du coucher.", en: "Daily reminders for morning, evening and sleep adhkar.")
    static let settingsPermissionDenied = LocalizedText(ar: "أذونات التنبيهات مرفوضة. فعّلها في إعدادات النظام.", fr: "Les notifications sont refusées. Active-les dans les Réglages système.", en: "Notifications are denied. Enable them in System Settings.")

    static let slotMorning = LocalizedText(ar: "أذكار الصباح", fr: "Adhkar du matin", en: "Morning adhkar")
    static let slotEvening = LocalizedText(ar: "أذكار المساء", fr: "Adhkar du soir",  en: "Evening adhkar")
    static let slotSleep   = LocalizedText(ar: "أذكار النوم",  fr: "Adhkar du coucher", en: "Sleep adhkar")

    // Detail view
    static let translation     = LocalizedText(ar: "الترجمة",   fr: "Traduction",     en: "Translation")
    static let transliteration = LocalizedText(ar: "النطق",     fr: "Translittération", en: "Transliteration")
    static let listen          = LocalizedText(ar: "استمع",     fr: "Écouter",          en: "Listen")
    static let pause           = LocalizedText(ar: "إيقاف",     fr: "Pause",            en: "Pause")
    static let share           = LocalizedText(ar: "مشاركة",    fr: "Partager",         en: "Share")
    static let done            = LocalizedText(ar: "تم",        fr: "Terminé",          en: "Done")
    static let tapToCount      = LocalizedText(ar: "اضغط",      fr: "Tape pour compter", en: "Tap to count")

    // Hero header (Quran 33:41)
    static let heroVerseTranslation = LocalizedText(
        ar: "سورة الأحزاب، الآية ٤١",
        fr: "Sourate Al-Ahzab, verset 41 — « Et invoquez Allah très souvent »",
        en: "Surah Al-Ahzab 33:41 — \"And remember Allah often\""
    )

    // Notification body
    static let notifTitleMorning = LocalizedText(ar: "وقت أذكار الصباح", fr: "C'est l'heure des adhkar du matin", en: "Time for morning adhkar")
    static let notifTitleEvening = LocalizedText(ar: "وقت أذكار المساء", fr: "C'est l'heure des adhkar du soir", en: "Time for evening adhkar")
    static let notifTitleSleep   = LocalizedText(ar: "وقت أذكار النوم",  fr: "C'est l'heure des adhkar du coucher", en: "Time for sleep adhkar")
    static let notifBody         = LocalizedText(ar: "خذ لحظة لذكر الله.", fr: "Prends un moment pour le rappel d'Allah.", en: "Take a moment for the remembrance of Allah.")

    // Streak
    static let streakTitle      = LocalizedText(ar: "السلسلة اليومية", fr: "Série quotidienne", en: "Daily streak")
    static let streakDays       = LocalizedText(ar: "يوم متتالٍ",       fr: "jours consécutifs", en: "day streak")
    static let streakBest       = LocalizedText(ar: "أفضل سلسلة",       fr: "Meilleur record",   en: "Best streak")
    static let streakStartToday = LocalizedText(ar: "ابدأ سلسلتك اليوم", fr: "Commence ta série aujourd'hui", en: "Start your streak today")

    // Widget
    static let widgetDisplayName = LocalizedText(ar: "ذكر اليوم", fr: "Dhikr du moment", en: "Today's dhikr")
    static let widgetDescription = LocalizedText(
        ar: "يعرض الذكر المقترح لوقت اليوم الحالي (صباحًا، مساءً، أو قبل النوم).",
        fr: "Affiche le dhikr suggéré pour le moment de la journée (matin, soir ou coucher).",
        en: "Shows the dhikr suggested for the current time of day (morning, evening or sleep)."
    )

    // Share card
    static let shareCardFooter = LocalizedText(ar: "مناجاة · munajat.app", fr: "Munajat · munajat.app", en: "Munajat · munajat.app")

    // Settings — privacy / support
    static let privacyPolicy = LocalizedText(ar: "سياسة الخصوصية", fr: "Politique de confidentialité", en: "Privacy policy")
    static let support       = LocalizedText(ar: "الدعم",          fr: "Support",                       en: "Support")
    static let settingsLegal = LocalizedText(ar: "قانوني",         fr: "Mentions légales",              en: "Legal")

    // Accessibility helpers
    static let a11yCounterLabel        = LocalizedText(ar: "العدّاد",        fr: "Compteur",      en: "Counter")
    static let a11yResetCounters       = LocalizedText(ar: "إعادة العدّ",     fr: "Réinitialiser",  en: "Reset counters")
    static let a11yResetCountersHint   = LocalizedText(ar: "إعادة كل العدّادات إلى الصفر", fr: "Remet tous les compteurs à zéro", en: "Resets all counters to zero")
    static let a11yFavorite            = LocalizedText(ar: "مفضل",            fr: "Favori",        en: "Favorite")
    static let a11yCategoryCardHint    = LocalizedText(ar: "افتح هذه الفئة",  fr: "Ouvrir cette catégorie", en: "Open this category")
    static let a11yDecorativePattern   = LocalizedText(ar: "زخرفة",           fr: "Décoration",     en: "Decoration")
}
