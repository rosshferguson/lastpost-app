//
//  DisclaimerView.swift
//  Last Post
//

import SwiftUI

struct DisclaimerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    Text("Last Post is a notification service designed to inform your chosen contacts when you pass away. It is not a legal, financial, or estate management service.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    disclaimer(
                        title: "No guarantee of delivery",
                        body: "Last Post sends notifications by email and SMS. We cannot guarantee that every message will be delivered — emails may be filtered as spam, phone numbers may change, and services may be temporarily unavailable. You should maintain other means of communicating your wishes, such as a will or a letter left with a trusted person."
                    )

                    disclaimer(
                        title: "Dependent on your Designated Person",
                        body: "Notifications are only sent when your Designated Person confirms your passing in the app or via the web link provided. Last Post cannot independently verify or initiate notifications. If your Designated Person is unable or unwilling to act, notifications will not be sent."
                    )

                    disclaimer(
                        title: "Service availability",
                        body: "Last Post is provided on a best-efforts basis. While we take steps to keep the service running reliably, we cannot guarantee uninterrupted availability. In the event the service is discontinued, we will provide reasonable notice where possible."
                    )

                    disclaimer(
                        title: "Not a substitute for legal planning",
                        body: "Last Post does not replace a will, lasting power of attorney, or other legal arrangements. We strongly recommend consulting a solicitor or financial adviser to ensure your affairs are in order."
                    )

                    disclaimer(
                        title: "Data and privacy",
                        body: "Your personal data and the details of your contacts are stored securely and used solely for the purpose of sending notifications. We do not sell or share your data with third parties. See our full Privacy Policy at lastpost.app/privacy.html."
                    )

                    disclaimer(
                        title: "Limitation of liability",
                        body: "To the maximum extent permitted by law, Last Post and its operators accept no liability for any loss, distress, or damage arising from the use or inability to use this service, including failure to deliver notifications."
                    )

                    Text("By using Last Post, you acknowledge and accept these limitations.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func disclaimer(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
