//
//  NotificationManager.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 08/05/2026.
//

import Foundation
import UserNotifications
import Observation

/// Schedules daily local notifications for morning, evening and sleep adhkar.
/// Uses fixed user-set times (default 8:00 / 17:00 / 22:00). The plan's
/// "1h after fajr / asr" via aladhan API is intentionally deferred — it adds
/// location permission + remote API + caching, all out of scope for now.
@Observable
final class NotificationManager {
    enum Slot: String, CaseIterable, Identifiable {
        case morning, evening, sleep
        var id: String { rawValue }

        var defaultHour: Int {
            switch self {
            case .morning: return 8
            case .evening: return 17
            case .sleep:   return 22
            }
        }

        var requestId: String { "adhkar.notif.\(rawValue)" }

        var title: LocalizedText {
            switch self {
            case .morning: return L10n.notifTitleMorning
            case .evening: return L10n.notifTitleEvening
            case .sleep:   return L10n.notifTitleSleep
            }
        }

        var label: LocalizedText {
            switch self {
            case .morning: return L10n.slotMorning
            case .evening: return L10n.slotEvening
            case .sleep:   return L10n.slotSleep
            }
        }
    }

    var isEnabled: [Slot: Bool] = [:]
    var times: [Slot: DateComponents] = [:]
    var permissionDenied: Bool = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for slot in Slot.allCases {
            isEnabled[slot] = defaults.bool(forKey: Self.enabledKey(slot))
            let hour = defaults.object(forKey: Self.hourKey(slot)) as? Int ?? slot.defaultHour
            let minute = defaults.object(forKey: Self.minuteKey(slot)) as? Int ?? 0
            times[slot] = DateComponents(hour: hour, minute: minute)
        }
        Task { await refreshPermissionStatus() }
    }

    // MARK: - Public API

    func toggle(_ slot: Slot, on: Bool) async {
        if on {
            let granted = await requestPermission()
            guard granted else {
                isEnabled[slot] = false
                permissionDenied = true
                persist(slot)
                return
            }
            isEnabled[slot] = true
            persist(slot)
            await schedule(slot)
        } else {
            isEnabled[slot] = false
            persist(slot)
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [slot.requestId])
        }
    }

    func setTime(_ slot: Slot, hour: Int, minute: Int) async {
        times[slot] = DateComponents(hour: hour, minute: minute)
        persist(slot)
        if isEnabled[slot] == true {
            await schedule(slot)
        }
    }

    func date(for slot: Slot) -> Date {
        let comps = times[slot] ?? DateComponents(hour: slot.defaultHour, minute: 0)
        return Calendar.current.date(bySettingHour: comps.hour ?? slot.defaultHour,
                                     minute: comps.minute ?? 0,
                                     second: 0,
                                     of: Date()) ?? Date()
    }

    // MARK: - Internals

    private func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            permissionDenied = false
            return true
        case .denied:
            permissionDenied = true
            return false
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            permissionDenied = !granted
            return granted
        @unknown default:
            return false
        }
    }

    private func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionDenied = (settings.authorizationStatus == .denied)
    }

    private func schedule(_ slot: Slot) async {
        let content = UNMutableNotificationContent()
        content.title = slot.title.resolved()
        content.body = L10n.notifBody.resolved()
        content.sound = .default

        let comps = times[slot] ?? DateComponents(hour: slot.defaultHour, minute: 0)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: slot.requestId, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [slot.requestId])
        try? await center.add(request)
    }

    // MARK: - Persistence keys

    private static func enabledKey(_ s: Slot) -> String { "notif.enabled.\(s.rawValue)" }
    private static func hourKey(_ s: Slot)    -> String { "notif.hour.\(s.rawValue)" }
    private static func minuteKey(_ s: Slot)  -> String { "notif.minute.\(s.rawValue)" }

    private func persist(_ slot: Slot) {
        defaults.set(isEnabled[slot] ?? false, forKey: Self.enabledKey(slot))
        defaults.set(times[slot]?.hour ?? slot.defaultHour, forKey: Self.hourKey(slot))
        defaults.set(times[slot]?.minute ?? 0, forKey: Self.minuteKey(slot))
    }
}
