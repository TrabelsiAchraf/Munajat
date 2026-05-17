// Adhkar/Models/LifeContext.swift
import Foundation

/// A life-state context (emotion or trial) that a user can choose to read
/// dhikr through. Defined in `contexts.json`, loaded by `DataProvider`.
struct LifeContext: Identifiable, Hashable, Equatable, Codable {
    let id: String
    let family: ContextFamily
    let iconName: String
    let color: String
    let title: LocalizedText
    let intro: LocalizedText
    let dhikrIds: [String]
}

enum ContextFamily: String, Codable, Hashable, CaseIterable {
    case emotion
    case trial
}
