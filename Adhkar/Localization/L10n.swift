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

    // Privacy policy screen
    static let privacyIntroTitle = LocalizedText(
        ar: "خصوصيتك",
        fr: "Ta vie privée",
        en: "Your privacy"
    )
    static let privacyIntroBody = LocalizedText(
        ar: "تطبيق مناجاة لا يجمع أي بيانات شخصية ولا يستخدم أي خدمة تتبع أو إعلانات. يعمل التطبيق محليًا على جهازك.",
        fr: "Munajat ne collecte aucune donnée personnelle et n'utilise aucun service de pistage ni de publicité. L'application fonctionne entièrement en local sur ton appareil.",
        en: "Munajat collects no personal data and uses no tracking or advertising services. The app runs entirely on-device."
    )
    static let privacyDataStoredTitle = LocalizedText(
        ar: "البيانات المخزّنة محليًا",
        fr: "Données stockées localement",
        en: "Locally stored data"
    )
    static let privacyDataStoredBody = LocalizedText(
        ar: "نخزّن على جهازك فقط: عدّادات الأذكار، المفضلة، إعدادات التنبيهات، وسلسلة الأيام. لا يتم رفع أي شيء إلى أي خادم.",
        fr: "Sur ton appareil uniquement : les compteurs de dhikr, les favoris, les préférences de notifications et l'historique de la série quotidienne. Rien n'est envoyé vers un serveur.",
        en: "On your device only: dhikr counters, favorites, notification preferences and the daily-streak history. Nothing is uploaded to any server."
    )
    static let privacyNetworkTitle = LocalizedText(
        ar: "الاتصال بالشبكة",
        fr: "Connexion réseau",
        en: "Network access"
    )
    static let privacyNetworkBody = LocalizedText(
        ar: "الاستخدام الوحيد للشبكة هو بثّ ملفات الصوت من hisnmuslim.com عند الضغط على زر «استمع». لا نُرسل أي معرّف.",
        fr: "La seule utilisation du réseau est le streaming des fichiers audio depuis hisnmuslim.com quand tu touches le bouton « Écouter ». Aucun identifiant n'est transmis.",
        en: "The only network use is audio streaming from hisnmuslim.com when you tap “Listen”. No identifier is sent."
    )
    static let privacyNotifsTitle = LocalizedText(
        ar: "التنبيهات",
        fr: "Notifications",
        en: "Notifications"
    )
    static let privacyNotifsBody = LocalizedText(
        ar: "التنبيهات تُجدول محليًا عبر نظام iOS. لا يمرّ أي محتوى عبر خوادمنا.",
        fr: "Les rappels sont planifiés en local par iOS. Aucun contenu ne transite par nos serveurs.",
        en: "Reminders are scheduled locally by iOS. No content passes through our servers."
    )
    static let privacyContactTitle = LocalizedText(
        ar: "الاتصال",
        fr: "Contact",
        en: "Contact"
    )
    static let privacyContactBody = LocalizedText(
        ar: "لأي سؤال متعلق بالخصوصية، استخدم قسم الدعم في الإعدادات.",
        fr: "Pour toute question liée à la vie privée, utilise la rubrique Support depuis les Réglages.",
        en: "For any privacy question, use the Support section from Settings."
    )

    // Support screen
    static let supportHeaderTitle = LocalizedText(
        ar: "كيف نساعدك؟",
        fr: "Comment t'aider ?",
        en: "How can we help?"
    )
    static let supportHeaderBody = LocalizedText(
        ar: "أجوبة سريعة على الأسئلة الشائعة. إن لم تجد ما تبحث عنه، الاقتراحات والملاحظات مرحّب بها.",
        fr: "Réponses rapides aux questions fréquentes. Si tu ne trouves pas, suggestions et retours sont bienvenus.",
        en: "Quick answers to common questions. If you don't find what you need, suggestions and feedback are welcome."
    )
    static let supportFaqAudioQ = LocalizedText(
        ar: "الصوت لا يعمل",
        fr: "Le son ne marche pas",
        en: "Audio does not play"
    )
    static let supportFaqAudioA = LocalizedText(
        ar: "الصوت يتطلب اتصالاً بالإنترنت لأنه يُبثّ من hisnmuslim.com. تأكد من اتصالك ومن أن الجهاز ليس في وضع الطيران.",
        fr: "Le son nécessite une connexion Internet car il est diffusé depuis hisnmuslim.com. Vérifie ta connexion et que l'appareil n'est pas en mode Avion.",
        en: "Audio requires an Internet connection — it is streamed from hisnmuslim.com. Check your connection and that the device is not in Airplane Mode."
    )
    static let supportFaqNotifsQ = LocalizedText(
        ar: "لا تصلني التنبيهات",
        fr: "Je ne reçois pas les notifications",
        en: "Notifications don't fire"
    )
    static let supportFaqNotifsA = LocalizedText(
        ar: "افتح إعدادات النظام ← مناجاة ← التنبيهات وتأكد من تفعيلها. داخل التطبيق، فعّل الفتحة المطلوبة في «الإعدادات».",
        fr: "Ouvre Réglages système → Munajat → Notifications et vérifie qu'elles sont activées. Dans l'app, active aussi le créneau voulu depuis « Réglages ».",
        en: "Open System Settings → Munajat → Notifications and make sure they are enabled. In the app, also enable the desired slot under “Settings”."
    )
    static let supportFaqCountersQ = LocalizedText(
        ar: "تمت إعادة العدّادات إلى الصفر",
        fr: "Les compteurs sont remis à zéro",
        en: "The counters reset"
    )
    static let supportFaqCountersA = LocalizedText(
        ar: "هذا متعمَّد: تُعاد العدّادات في بداية كل يوم لتبدأ من جديد. تتقدّم سلسلتك بمجرد قراءة ذكر واحد.",
        fr: "C'est volontaire : les compteurs sont remis à zéro chaque jour pour repartir à neuf. Ta série progresse dès qu'un dhikr est lu.",
        en: "This is intentional: counters reset at the start of each day so you start fresh. Your streak advances as soon as one dhikr is read."
    )
    static let supportFaqStreakQ = LocalizedText(
        ar: "اختفت سلسلتي",
        fr: "Ma série a disparu",
        en: "My streak disappeared"
    )
    static let supportFaqStreakA = LocalizedText(
        ar: "تعتمد السلسلة على التاريخ الميلادي بالتوقيت المحلي. تغيير تقويم النظام لا يُفقد سجلّك المخزّن محليًا.",
        fr: "La série se base sur la date grégorienne et le fuseau horaire local. Changer le calendrier du système ne supprime pas ton historique stocké en local.",
        en: "The streak uses the Gregorian date in your local time zone. Changing the system calendar does not lose your locally stored history."
    )
    static let supportContentTitle = LocalizedText(
        ar: "ملاحظة حول المحتوى",
        fr: "Note sur le contenu",
        en: "About the content"
    )
    static let supportContentBody = LocalizedText(
        ar: "النصوص مأخوذة من «حصن المسلم» للشيخ سعيد بن علي القحطاني. لأي خطأ في الترجمة أو المصدر، يُرجى الإبلاغ.",
        fr: "Les textes sont issus de « Hisn al-Muslim » du Cheikh Saʿīd al-Qaḥṭānī. Pour toute erreur de traduction ou de source, n'hésite pas à le signaler.",
        en: "Texts come from “Hisn al-Muslim” by Sheikh Saʿīd al-Qaḥṭānī. Please report any translation or source error."
    )

    // Accessibility helpers
    static let a11yCounterLabel        = LocalizedText(ar: "العدّاد",        fr: "Compteur",      en: "Counter")
    static let a11yResetCounters       = LocalizedText(ar: "إعادة العدّ",     fr: "Réinitialiser",  en: "Reset counters")
    static let a11yResetCountersHint   = LocalizedText(ar: "إعادة كل العدّادات إلى الصفر", fr: "Remet tous les compteurs à zéro", en: "Resets all counters to zero")
    static let a11yFavorite            = LocalizedText(ar: "مفضل",            fr: "Favori",        en: "Favorite")
    static let a11yCategoryCardHint    = LocalizedText(ar: "افتح هذه الفئة",  fr: "Ouvrir cette catégorie", en: "Open this category")
    static let a11yDecorativePattern   = LocalizedText(ar: "زخرفة",           fr: "Décoration",     en: "Decoration")
    /// `{completed}` and `{total}` are placeholders replaced at call site.
    static let a11yProgressHeader      = LocalizedText(
        ar: "{completed} من {total} ذكر",
        fr: "{completed} sur {total} dhikr complétés",
        en: "{completed} of {total} dhikr completed"
    )

    // Completion celebration overlay
    static let celebrationSubtitle = LocalizedText(
        ar: "أتممت قراءة جميع أذكار هذه الفئة",
        fr: "Tu as lu tous les adhkar de cette catégorie",
        en: "You read every dhikr in this category"
    )

    // MARK: - Context-driven home
    static let contextHomeCardLabel    = LocalizedText(ar: "كيف تشعر؟", fr: "Comment te sens-tu ?", en: "How do you feel?")
    static let contextHomeCardHint     = LocalizedText(ar: "١٥ حالات · اختر ما تعيشه", fr: "15 états · choisis ce que tu vis", en: "15 states · pick what you're living")
    static let contextPickerTitle      = LocalizedText(ar: "كيف تشعر؟", fr: "Comment te sens-tu ?", en: "How do you feel?")
    static let contextFamilyEmotion    = LocalizedText(ar: "المشاعر", fr: "Émotions", en: "Emotions")
    static let contextFamilyTrial      = LocalizedText(ar: "ابتلاءات الحياة", fr: "Épreuves de vie", en: "Life trials")
    static let contextCancel           = LocalizedText(ar: "إلغاء", fr: "Annuler", en: "Cancel")
    static let contextDhikrSuggested   = LocalizedText(ar: "أذكار مقترحة", fr: "Dhikr suggérés", en: "Suggested dhikr")
    static let contextEmptyTitle       = LocalizedText(ar: "لا توجد عناصر بعد", fr: "Aucun dhikr pour ce contexte", en: "No dhikr for this context yet")
    static let contextEmptyHint        = LocalizedText(ar: "سيتم إضافتها قريبًا.", fr: "Ils seront ajoutés bientôt.", en: "They will be added soon.")
    static let contextDhikrCountSuffix = LocalizedText(ar: "ذكر", fr: "dhikr", en: "dhikr")
}
