//
//  AdhkarSection+Display.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI

extension AdhkarSection {
    /// Stable display order on the home screen.
    static let displayOrder: [AdhkarSection] = [
        .daily, .prayer, .eating, .travel, .hajj,
        .funerals, .weather, .social, .protection, .healing, .other
    ]

    var displayName: LocalizedText {
        switch self {
        case .daily:      return LocalizedText(ar: "اليومي",        fr: "Quotidien",     en: "Daily")
        case .prayer:     return LocalizedText(ar: "الصلاة",         fr: "Prière",        en: "Prayer")
        case .eating:     return LocalizedText(ar: "الطعام",         fr: "Repas",         en: "Eating")
        case .travel:     return LocalizedText(ar: "السفر",          fr: "Voyage",        en: "Travel")
        case .hajj:       return LocalizedText(ar: "الحج والعمرة",   fr: "Hajj et Omra",  en: "Hajj & Umrah")
        case .funerals:   return LocalizedText(ar: "الجنائز",         fr: "Funérailles",   en: "Funerals")
        case .weather:    return LocalizedText(ar: "الطقس",          fr: "Météo",         en: "Weather")
        case .social:     return LocalizedText(ar: "الحياة الاجتماعية", fr: "Vie sociale", en: "Social life")
        case .protection: return LocalizedText(ar: "الحماية",         fr: "Protection",    en: "Protection")
        case .healing:    return LocalizedText(ar: "الشفاء",          fr: "Guérison",      en: "Healing")
        case .other:      return LocalizedText(ar: "آخر",            fr: "Autre",         en: "Other")
        }
    }

    var iconName: String {
        switch self {
        case .daily:      return "sun.and.horizon.fill"
        case .prayer:     return "moon.stars.fill"
        case .eating:     return "fork.knife"
        case .travel:     return "airplane"
        case .hajj:       return "building.columns.fill"
        case .funerals:   return "leaf.fill"
        case .weather:    return "cloud.sun.fill"
        case .social:     return "person.2.fill"
        case .protection: return "shield.fill"
        case .healing:    return "heart.text.square.fill"
        case .other:      return "ellipsis.circle.fill"
        }
    }

    /// Single app-wide accent so cards, counter, icons and toolbar all share
    /// the same warm hue across every section.
    var accentColor: Color { .orange }
}
