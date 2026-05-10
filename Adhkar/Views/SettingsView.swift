//
//  SettingsView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(NotificationManager.self) private var notifications

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground()
                List {
                    notificationsSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n.tabSettings.resolved())
        }
    }

    // MARK: - Sections

    private var notificationsSection: some View {
        Section {
            ForEach(NotificationManager.Slot.allCases) { slot in
                NotificationRow(slot: slot)
            }
            if notifications.permissionDenied {
                Text(L10n.settingsPermissionDenied.resolved())
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } header: {
            Label(L10n.settingsNotifs.resolved(), systemImage: "bell.fill")
        } footer: {
            Text(L10n.settingsNotifsHelp.resolved())
        }
        .listRowBackground(Color.cardBackground)
    }

    private var aboutSection: some View {
        Section {
            LabeledRow(icon: "book.closed.fill",
                       title: L10n.settingsContentSource.resolved(),
                       value: L10n.settingsContentSourceVal.resolved())
            LabeledRow(icon: "info.circle.fill",
                       title: L10n.settingsVersion.resolved(),
                       value: appVersion)
        } header: {
            Label(L10n.settingsAbout.resolved(), systemImage: "info.circle")
        }
        .listRowBackground(Color.cardBackground)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}

private struct NotificationRow: View {
    let slot: NotificationManager.Slot
    @Environment(NotificationManager.self) private var notifications

    var body: some View {
        @Bindable var notifications = notifications
        let isOn = Binding(
            get: { notifications.isEnabled[slot] ?? false },
            set: { newValue in Task { await notifications.toggle(slot, on: newValue) } }
        )
        let date = Binding<Date>(
            get: { notifications.date(for: slot) },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                Task { await notifications.setTime(slot, hour: comps.hour ?? 0, minute: comps.minute ?? 0) }
            }
        )
        return HStack {
            Toggle(isOn: isOn) {
                Text(slot.label.resolved())
            }
            if isOn.wrappedValue {
                DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
    }
}

private struct LabeledRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .font(.footnote)
                .multilineTextAlignment(.trailing)
        }
    }
}
