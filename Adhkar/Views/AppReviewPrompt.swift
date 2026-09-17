import SwiftUI
import StoreKit

/// Wait for the completion UI to settle. SwiftUI cancels the task if this
/// screen disappears or a new trigger arrives; never prompt in the background.
private struct AppReviewPrompt: ViewModifier {
    let trigger: UUID?
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.task(id: trigger) {
            guard trigger != nil else { return }
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            guard !Task.isCancelled, scenePhase == .active,
                  ReviewPromptGate.shouldRequestNow() else { return }
            // Apple doesn't report display/submission; this records an attempt.
            ReviewPromptGate.recordRequest()
            requestReview()
        }
    }
}

extension View {
    func appReviewPrompt(trigger: UUID?) -> some View {
        modifier(AppReviewPrompt(trigger: trigger))
    }
}
