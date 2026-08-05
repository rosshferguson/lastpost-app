//
//  NotificationPreviewView.swift
//  FinalFarewell
//
//  Shows the user a realistic preview of what their contacts will receive
//  when the death notification is triggered.
//

import SwiftUI

struct NotificationPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let user: User

    var confirmedContacts: [Contact] {
        user.contacts.filter { $0.invitationAccepted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Explanation header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This is a preview of what your contacts will receive when your designated person triggers your notifications.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Email preview
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
                                LabeledContent("From", value: "noreply@finalfarewell.app")
                                LabeledContent("To", value: "[Contact's email]")
                                LabeledContent("Subject", value: "A message from \(user.fullName)")
                            }
                            .font(.subheadline)

                            Divider()

                            Text("Dear [Contact Name],")
                                .fontWeight(.medium)

                            Text("We are writing to inform you that \(user.fullName) has passed away.")

                            Text("This message was prepared in advance by \(user.firstName) using the Final Farewell app, to ensure you were informed of their passing.")
                                .foregroundStyle(.secondary)

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

                            // Show if any contacts have personal messages
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.open")
                                    .foregroundStyle(.purple)
                                Text("Contacts with a personal message will also receive it privately.")
                                    .font(.subheadline)
                            }
                            .padding(10)
                            .background(Color.purple.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("With love and remembrance,\nThe Final Farewell Team on behalf of \(user.fullName)")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .padding()
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Who will receive it
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.green)
                            Text("Who Will Be Notified")
                                .font(.headline)
                        }

                        if confirmedContacts.isEmpty {
                            Text("No confirmed contacts yet. Contacts must accept their invitation before they can be notified.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(confirmedContacts) { contact in
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
                                            if contact.hasPersonalContent {
                                                Label("Personal message", systemImage: "envelope.badge")
                                                    .font(.caption)
                                                    .foregroundStyle(.purple)
                                            }
                                            if contact.wantsFuneralDetails {
                                                Label("Funeral details", systemImage: "calendar")
                                                    .font(.caption)
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if !user.contacts.filter({ !$0.invitationAccepted }).isEmpty {
                            Text("\(user.contacts.filter { !$0.invitationAccepted }.count) contact(s) haven't accepted yet and will not be notified.")
                                .font(.caption)
                                .foregroundStyle(.orange)
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
        }
    }
}
