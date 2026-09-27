//
//  NotificationPreviewView.swift
//  Last Post
//
//  Updated:
//  - App name updated to "Last Post" throughout
//  - "Who Will Be Notified" now shows ALL contacts with an email or phone,
//    regardless of whether they accepted an in-app invitation
//  - Customisable death notification message with edit sheet
//  - Fixed sign-off (no longer mentions "The Final Farewell Team")
//

import SwiftUI

struct NotificationPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let user: User

    @AppStorage("deathNotificationMessageTemplate") private var messageTemplate = NotificationPreviewView.defaultMessageTemplate
    @State private var showingEditMessage = false

    static let defaultMessageTemplate = "This message was prepared in advance by {ownerName} using Last Post, to ensure you were informed of their passing."

    // All contacts who can actually be reached — invitation acceptance is not required
    var notifiableContacts: [Contact] {
        user.contacts.filter { !$0.email.isEmpty || !$0.phoneNumber.isEmpty }
    }

    var unreachableContacts: [Contact] {
        user.contacts.filter { $0.email.isEmpty && $0.phoneNumber.isEmpty }
    }

    var resolvedMessage: String {
        messageTemplate
            .replacingOccurrences(of: "{ownerName}", with: user.firstName)
            .replacingOccurrences(of: "{contactName}", with: "[Contact Name]")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    Text("This is a preview of what your contacts will receive when your designated person triggers your notifications.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    // Email preview card
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.blue)
                            Text("Email Notification")
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08))

                        VStack(alignment: .leading, spacing: 12) {
                            Group {
                                LabeledContent("From", value: "Last Post <noreply@lastpost.app>")
                                LabeledContent("To", value: "[Contact's email]")
                                LabeledContent("Subject", value: "A message from \(user.fullName)")
                            }
                            .font(.subheadline)

                            Divider()

                            Text("Dear [Contact Name],")
                                .fontWeight(.medium)

                            Text("We are deeply sorry to let you know that \(user.fullName) has passed away.")

                            // Customisable message
                            Text(resolvedMessage)
                                .foregroundStyle(.secondary)

                            // Edit message button
                            Button {
                                showingEditMessage = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                    Text("Edit this message")
                                }
                                .font(.caption)
                                .foregroundStyle(.blue)
                            }

                            if !user.sharedMedia.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                        .foregroundStyle(.orange)
                                    Text("\(user.firstName) has shared \(user.sharedMedia.count) memor\(user.sharedMedia.count == 1 ? "y" : "ies") with you.")
                                        .font(.subheadline)
                                }
                                .padding(10)
                                .background(Color.orange.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "envelope.open")
                                    .foregroundStyle(.purple)
                                Text("Contacts with a personal message will also receive it privately.")
                                    .font(.subheadline)
                            }
                            .padding(10)
                            .background(Color.purple.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("This notification was delivered on behalf of \(user.fullName) by their designated person using Last Post.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .padding()
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Who will be notified
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.green)
                            Text("Who Will Be Notified")
                                .font(.headline)
                        }

                        if notifiableContacts.isEmpty {
                            Text("No contacts added yet. Add contacts with an email address or phone number and they will be notified when the time comes.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(notifiableContacts) { contact in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color.green.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text(contact.firstName.prefix(1) + contact.lastName.prefix(1))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.green)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.fullName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        HStack(spacing: 8) {
                                            if !contact.email.isEmpty {
                                                Label("Email", systemImage: "envelope")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if !contact.phoneNumber.isEmpty {
                                                Label("Phone", systemImage: "phone")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if contact.hasPersonalContent {
                                                Label("Personal message", systemImage: "envelope.badge")
                                                    .font(.caption)
                                                    .foregroundStyle(.purple)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if !unreachableContacts.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                Text("\(unreachableContacts.count) contact(s) have no email or phone number and cannot be notified.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Notification Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditMessage) {
                EditNotificationMessageView(messageTemplate: $messageTemplate, ownerFirstName: user.firstName)
            }
        }
    }
}

// MARK: - Edit message sheet

struct EditNotificationMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var messageTemplate: String
    let ownerFirstName: String

    var preview: String {
        messageTemplate
            .replacingOccurrences(of: "{ownerName}", with: ownerFirstName)
            .replacingOccurrences(of: "{contactName}", with: "Sarah")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message") {
                    TextEditor(text: $messageTemplate)
                        .frame(minHeight: 120)
                        .font(.body)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Placeholders:")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("{ownerName} — your first name")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("{contactName} — the contact's first name")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Preview") {
                    Text(preview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Reset to default") {
                        messageTemplate = NotificationPreviewView.defaultMessageTemplate
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
