//
//  AdhkarDetailsView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 19/04/2025.
//

import SwiftUI
import SwiftData
import StoreKit

struct AdhkarDetailsView: View {
    let adhkar: AdhkarCategory
    let focusedItemId: String?
    let navTitleOverride: LocalizedText?

    init(adhkar: AdhkarCategory, focusedItemId: String? = nil, navTitleOverride: LocalizedText? = nil) {
        self.adhkar = adhkar
        self.focusedItemId = focusedItemId
        self.navTitleOverride = navTitleOverride
    }

    @State private var resetToken = UUID()
    @State private var selectedIndex: Int = 0
    @State private var showCelebration = false
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audio
    @Environment(StreakService.self) private var streak
    @Environment(\.requestReview) private var requestReview

    /// All persisted counters. We filter to the current category in code so we
    /// don't need a dynamic SwiftData predicate, and we re-check
    /// `isDateInToday(lastUpdated)` so a category fully completed yesterday
    /// reads as 0/N this morning (counters auto-reset on first visit per page).
    @Query private var allProgress: [DhikrProgress]

    private var accent: Color { (adhkar.section ?? .other).accentColor }

    /// Items shown — either all category items, or just the focused one
    /// when `focusedItemId` is set.
    private var visibleItems: [Adhkar] {
        guard let id = focusedItemId else { return adhkar.adhkarList }
        return adhkar.adhkarList.filter { $0.id == id }
    }

    private var totalCount: Int { visibleItems.count }

    private var completedCount: Int {
        let progressById = Dictionary(
            uniqueKeysWithValues: allProgress.map { ($0.itemId, $0) }
        )
        let calendar = Calendar.current
        return visibleItems.reduce(into: 0) { acc, dhikr in
            guard let p = progressById[dhikr.id],
                  calendar.isDateInToday(p.lastUpdated),
                  p.count >= dhikr.count
            else { return }
            acc += 1
        }
    }

    private var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return min(Double(completedCount) / Double(totalCount), 1)
    }

    /// One-shot-per-day-per-category flag. Persisted to `UserDefaults` so the
    /// celebration doesn't re-fire if the user closes and re-opens the app,
    /// or resets and re-completes the same category in the same day.
    private var celebrationStorageKey: String {
        "celebration.lastShown.\(adhkar.id)"
    }

    private func celebrationAlreadyShownToday() -> Bool {
        let ts = UserDefaults.standard.double(forKey: celebrationStorageKey)
        guard ts > 0 else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts))
    }

    private func markCelebrationShown() {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: celebrationStorageKey)
        ReviewPromptGate.recordCelebration()
    }

    var body: some View {
        if #available(visionOS 26.0, *) {
            baseContent
                .toolbar { resetToolbarItem }
                .onChange(of: selectedIndex) { _, _ in audio.stop() }
                .onChange(of: completedCount) { oldValue, newValue in
                    handleProgressChange(old: oldValue, new: newValue)
                }
                .sensoryFeedback(.success, trigger: showCelebration) { _, new in new }
                .overlay { celebrationOverlay }
                .onDisappear { audio.stop() }
        } else {
            baseContent
                .toolbar { resetToolbarItem }
                .onChange(of: selectedIndex) { _, _ in audio.stop() }
                .onChange(of: completedCount) { oldValue, newValue in
                    handleProgressChange(old: oldValue, new: newValue)
                }
                .overlay { celebrationOverlay }
                .onDisappear { audio.stop() }
        }
    }

    private var baseContent: some View {
        ZStack {
            AdaptiveBackground(decorated: true)
            pagedDhikrList
        }
        .safeAreaInset(edge: .top, spacing: 0) { progressHeader }
        .navigationTitle(navTitleOverride?.resolved() ?? adhkar.displayTitle)
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var resetToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                resetAllCounters()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .tint(accent)
            .accessibilityLabel(L10n.a11yResetCounters.resolved())
            .accessibilityHint(L10n.a11yResetCountersHint.resolved())
        }
    }

    @ViewBuilder
    private var celebrationOverlay: some View {
        if showCelebration {
            CompletionOverlay(accent: accent) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showCelebration = false
                }
                if ReviewPromptGate.shouldRequestNow() {
                    ReviewPromptGate.recordRequest()
                    requestReview()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
            .zIndex(1)
        }
    }

    private func handleProgressChange(old: Int, new: Int) {
        guard focusedItemId == nil else { return } // no celebration in single-item mode
        guard new == totalCount,
              totalCount > 0,
              old < totalCount,
              !celebrationAlreadyShownToday()
        else { return }
        markCelebrationShown()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showCelebration = true
        }
    }

    /// Slim accent-coloured bar showing how many dhikr in this category the
    /// user has completed today (counter reached its target), with a
    /// `completed / total` label on the right.
    private var progressHeader: some View {
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(accent.opacity(0.18))
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * progressFraction)
                        .animation(.easeOut(duration: 0.35), value: progressFraction)
                }
            }
            .frame(height: 5)
            Text("\(completedCount)/\(totalCount)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.a11yProgressHeader.resolved()
                .replacingOccurrences(of: "{completed}", with: "\(completedCount)")
                .replacingOccurrences(of: "{total}", with: "\(totalCount)")
        )
    }

    /// Paged TabView on iOS / visionOS; plain vertical scroll on macOS where
    /// `tabViewStyle(.page)` is unavailable.
    @ViewBuilder
    private var pagedDhikrList: some View {
        #if os(iOS) || os(visionOS)
        TabView(selection: $selectedIndex) {
            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, dhikr in
                DhikrPageView(
                    category: adhkar,
                    dhikr: dhikr,
                    position: index + 1,
                    total: visibleItems.count,
                    accent: accent,
                    onCompletion: { streak.recordDhikrCompleted(context: modelContext) }
                )
                .id("\(dhikr.id)-\(resetToken)")
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        #else
        ScrollView {
            VStack(spacing: 24) {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, dhikr in
                    DhikrPageView(
                        category: adhkar,
                        dhikr: dhikr,
                        position: index + 1,
                        total: visibleItems.count,
                        accent: accent,
                        onCompletion: { streak.recordDhikrCompleted(context: modelContext) }
                    )
                    .id("\(dhikr.id)-\(resetToken)")
                }
            }
            .padding(.vertical)
        }
        #endif
    }

    private func resetAllCounters() {
        let ids = visibleItems.map(\.id)
        let descriptor = FetchDescriptor<DhikrProgress>(
            predicate: #Predicate<DhikrProgress> { ids.contains($0.itemId) }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for progress in existing {
                progress.count = 0
                progress.lastUpdated = .now
            }
        }
        resetToken = UUID()
    }
}

private struct DhikrPageView: View {
    let category: AdhkarCategory
    let dhikr: Adhkar
    let position: Int
    let total: Int
    let accent: Color
    /// Called the first time `counter` reaches `dhikr.count` during this page's
    /// lifetime — used to bump the daily activity for streak history.
    var onCompletion: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audio

    @State private var counter: Int = 0
    @State private var transliterationExpanded = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var completionFired = false

    private var isCompleted: Bool { counter >= dhikr.count }
    private var progress: Double {
        guard dhikr.count > 0 else { return 0 }
        return min(Double(counter) / Double(dhikr.count), 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                positionPill

                Text(dhikr.dhikr)
                    .font(.amiri(size: 28))
                    .multilineTextAlignment(.center)
                    .lineSpacing(14)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.cardBackground)
                    .clipShape(.rect(cornerRadius: 18))

                if let translation = dhikr.translation?.resolved(), !translation.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.translation.resolved())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(translation)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.cardBackground)
                    .clipShape(.rect(cornerRadius: 14))
                }

                if let translit = dhikr.transliteration?.resolved(), !translit.isEmpty {
                    DisclosureSection(title: L10n.transliteration.resolved(), expanded: $transliterationExpanded) {
                        Text(translit)
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !dhikr.source.isEmpty {
                    VStack(spacing: 4) {
                        Text(L10n.sourceHisnLabel.resolved())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(dhikr.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }

                counterButton

                actionRow
            }
            .padding()
            .padding(.bottom, 40)
        }
        .onAppear { loadOrResetCounter() }
    }

    private var positionPill: some View {
        Text("\(position) / \(total)")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(accent.opacity(0.15))
            .clipShape(Capsule())
    }

    private var counterButton: some View {
        Button {
            guard !isCompleted else { return }
            counter += 1
            saveCounter()
            if isCompleted, !completionFired {
                completionFired = true
                onCompletion()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.18), accent.opacity(0.05)],
                            center: .center,
                            startRadius: 5,
                            endRadius: 95
                        )
                    )
                Circle()
                    .stroke(accent.opacity(0.20), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.2), value: progress)

                VStack(spacing: 4) {
                    Text("\(counter)")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                    Text("/ \(dhikr.count)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    if isCompleted {
                        Text(L10n.done.resolved())
                            .font(.caption.bold())
                            .foregroundStyle(accent)
                            .padding(.top, 2)
                    } else if counter == 0 {
                        Label(L10n.tapToCount.resolved(), systemImage: "hand.tap.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent.opacity(0.75))
                            .padding(.top, 2)
                    }
                }
            }
            .frame(width: 190, height: 190)
            .shadow(color: accent.opacity(0.25), radius: 14, x: 0, y: 6)
            .scaleEffect(pulseScale)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
//        .sensoryFeedback(.impact(weight: .light), trigger: counter)
//        .sensoryFeedback(.success, trigger: isCompleted) { _, new in new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.a11yCounterLabel.resolved())
        .accessibilityValue("\(counter) / \(dhikr.count)")
        .accessibilityHint(isCompleted ? L10n.done.resolved() : L10n.tapToCount.resolved())
        .accessibilityAddTraits(isCompleted ? [] : .isButton)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: counter) { _, newValue in
            if newValue > 0 {
                withAnimation(.easeOut(duration: 0.25)) { pulseScale = 1.0 }
            }
        }
    }

    private func startPulseIfNeeded() {
        guard counter == 0 else { return }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
            pulseScale = 1.04
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 12) {
            if let audioURL = dhikrAudioURL {
                audioButton(url: audioURL)
            }
            shareButton
            MemorizeButton(itemId: dhikr.id, accent: accent)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let shareable = makeShareableImage() {
            ShareLink(
                item: shareable,
                preview: SharePreview(
                    category.displayTitle,
                    image: Image(decorative: shareable.cgImage, scale: 3, orientation: .up)
                )
            ) {
                shareLabel
            }
            .tint(accent)
            .accessibilityLabel(L10n.share.resolved())
        } else {
            ShareLink(item: shareText) { shareLabel }
                .tint(accent)
                .accessibilityLabel(L10n.share.resolved())
        }
    }

    private var shareLabel: some View {
        Label(L10n.share.resolved(), systemImage: "square.and.arrow.up")
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .clipShape(Capsule())
    }

    @MainActor
    private func makeShareableImage() -> ShareableDhikrImage? {
        let renderer = ImageRenderer(
            content: ShareableDhikrCard(category: category, dhikr: dhikr)
        )
        renderer.scale = 3
        guard let cg = renderer.cgImage else { return nil }
        let name = category.displayTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return ShareableDhikrImage(cgImage: cg, suggestedName: "munajat_\(name)")
    }

    private func audioButton(url: URL) -> some View {
        let playing = audio.isPlaying(itemId: dhikr.id)
        return Button {
            audio.toggle(itemId: dhikr.id, url: url)
        } label: {
            Label(playing ? L10n.pause.resolved() : L10n.listen.resolved(),
                  systemImage: playing ? "pause.fill" : "play.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(playing ? accent.opacity(0.2) : Color.cardBackground)
                .foregroundStyle(accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playing ? L10n.pause.resolved() : L10n.listen.resolved())
    }

    private var dhikrAudioURL: URL? {
        guard let s = dhikr.audio, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    private var shareText: String {
        var parts: [String] = [dhikr.dhikr]
        if let t = dhikr.translation?.resolved(), !t.isEmpty { parts.append(t) }
        if !dhikr.source.isEmpty { parts.append("— \(dhikr.source)") }
        return parts.joined(separator: "\n\n")
    }

    // MARK: - Persistence

    private func loadOrResetCounter() {
        let id = dhikr.id
        let descriptor = FetchDescriptor<DhikrProgress>(
            predicate: #Predicate<DhikrProgress> { $0.itemId == id }
        )
        guard let existing = (try? modelContext.fetch(descriptor))?.first else {
            counter = 0
            return
        }
        if Calendar.current.isDateInToday(existing.lastUpdated) {
            counter = existing.count
        } else {
            existing.count = 0
            existing.lastUpdated = .now
            counter = 0
        }
    }

    private func saveCounter() {
        let id = dhikr.id
        let descriptor = FetchDescriptor<DhikrProgress>(
            predicate: #Predicate<DhikrProgress> { $0.itemId == id }
        )
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.count = counter
            existing.lastUpdated = .now
        } else {
            modelContext.insert(DhikrProgress(itemId: id, count: counter, lastUpdated: .now))
        }
    }
}

private struct DisclosureSection<Content: View>: View {
    let title: String
    @Binding var expanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
    }
}

/// Full-screen congratulatory overlay shown once per day per category when
/// every dhikr counter has reached its target. Sober, no confetti — a gold
/// ring with a crescent + star halo, "ما شاء الله" in Amiri, and a localized
/// subtitle. Tap anywhere to dismiss, or it auto-dismisses after a few
/// seconds via the `.task` modifier.
private struct CompletionOverlay: View {
    let accent: Color
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 0.4
    @State private var rotation: Double = -20
    @State private var glowOpacity: Double = 0
    @State private var sparkleRotation: Double = 0

    private let gold1 = Color(hex: "#FFE9A6")
    private let gold2 = Color(hex: "#D4A857")

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.45))
                        .frame(width: 220, height: 220)
                        .blur(radius: 36)
                        .opacity(glowOpacity)

                    ForEach(0..<6) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(gold1.opacity(0.85))
                            .offset(y: -78)
                            .rotationEffect(.degrees(Double(i) * 60 + sparkleRotation))
                    }

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [gold1, gold2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 140, height: 140)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [gold1, gold2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(rotation))
                }

                Text("ما شاء الله")
                    .font(.amiri(size: 40, bold: true))
                    .foregroundStyle(.white)

                Text(L10n.celebrationSubtitle.resolved())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
            )
            .scaleEffect(scale)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isModal)
            .onTapGesture { onDismiss() }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                scale = 1.0
                rotation = 0
            }
            withAnimation(.easeOut(duration: 0.9)) {
                glowOpacity = 1.0
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            onDismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AdhkarDetailsView(adhkar: DataProvider.adharCategories.first!)
    }
    .environment(FavoritesStore())
    .environment(AudioPlayer())
    .environment(StreakService())
    .modelContainer(for: DhikrProgress.self, inMemory: true)
}
