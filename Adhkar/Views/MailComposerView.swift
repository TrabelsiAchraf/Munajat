#if canImport(MessageUI) && os(iOS)
import MessageUI
import SwiftUI

struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onFinish: (MFMailComposeResult) -> Void

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        init(parent: MailComposerView) { self.parent = parent }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            parent.onFinish(result)
            controller.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.mailComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
}
#endif
