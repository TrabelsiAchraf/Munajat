import SwiftUI

#if canImport(MessageUI) && os(iOS)
import MessageUI
#endif

struct ContactUsView: View {
    private static let recipient = "trabelsiachraf.devapps@gmail.com"
    private let reasons = [L10n.contactReasonBug, L10n.contactReasonContent,
                           L10n.contactReasonSuggestion, L10n.contactReasonQuestion]
    private let feelings = ["😤", "😕", "😑", "🙂", "😁"]

    @Environment(\.openURL) private var openURL
    @State private var selectedReason = 0
    @State private var message = ""
    @State private var feeling = 3
    @State private var showingComposer = false
    @State private var showingLimitAlert = false
    @State private var showingUnavailableAlert = false

    var body: some View {
        ZStack {
            AdaptiveBackground()
            Form {
                Section {
                    Picker(L10n.contactReasonLabel.resolved(), selection: $selectedReason) {
                        ForEach(reasons.indices, id: \.self) { index in
                            Text(reasons[index].resolved()).tag(index)
                        }
                    }
                    TextField(L10n.contactMessagePlaceholder.resolved(), text: $message, axis: .vertical)
                        .lineLimit(4...8)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.contactFeelingLabel.resolved())
                            .font(.subheadline.weight(.semibold))
                        Picker(L10n.contactFeelingLabel.resolved(), selection: $feeling) {
                            ForEach(feelings.indices, id: \.self) { index in
                                Text(feelings[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                } header: {
                    Text(L10n.contactSection.resolved())
                } footer: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.contactLimit.resolved())
                            .font(.footnote)
                        Button {
                            send()
                        } label: {
                            Label(L10n.contactSend.resolved(), systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(L10n.contactTitle.resolved())
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if canImport(MessageUI) && os(iOS)
        .sheet(isPresented: $showingComposer) {
            MailComposerView(recipient: Self.recipient,
                             subject: reasons[selectedReason].resolved(),
                             body: mailBody) { _ in
                showingComposer = false
            }
        }
        #endif
        .alert(L10n.contactLimitTitle.resolved(), isPresented: $showingLimitAlert) {
            Button(L10n.done.resolved(), role: .cancel) { }
        } message: {
            Text(L10n.contactLimitMessage.resolved())
        }
        .alert(L10n.contactUnavailableTitle.resolved(), isPresented: $showingUnavailableAlert) {
            Button(L10n.done.resolved(), role: .cancel) { }
        } message: {
            Text(L10n.contactUnavailableMessage.resolved())
        }
    }

    private var mailBody: String {
        "\(message)\n\n\(L10n.contactFeelingMail.resolved()) \(feelings[feeling])"
    }

    private func send() {
        guard ContactRateLimiter.reserveSend() else {
            showingLimitAlert = true
            return
        }
        #if canImport(MessageUI) && os(iOS)
        guard MFMailComposeViewController.canSendMail() else {
            showingUnavailableAlert = true
            return
        }
        showingComposer = true
        #else
        guard let url = URL(string: "mailto:\(Self.recipient)?subject=\(reasons[selectedReason].resolved().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Munajat")&body=\(mailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            showingUnavailableAlert = true
            return
        }
        openURL(url)
        #endif
    }
}
