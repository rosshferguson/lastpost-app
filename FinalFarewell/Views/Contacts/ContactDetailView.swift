//
//  ContactDetailView.swift
//  FinalFarewell
//
//  Added:
//  - Voice memo button opening VoiceMemoView as a sheet
//  - Personal message and voice memo now shown as separate rows for clarity
//

import SwiftUI

struct ContactDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var contactsViewModel: ContactsViewModel

    let contact: Contact

    @State private var isEditing = false
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var wantsFuneralDetails = true
    @State private var showingDeleteConfirmation = false
    @State private var showingResendInvitation = false
    @State private var showingPersonalMessage = false

    var body: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(contact.firstName.prefix(1) + contact.lastName.prefix(1))
                                .font(.title)
                                .foregroundStyle(.blue)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(contact.fullName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(contact.relationship)
                            .foregroundStyle(.secondary)
                        statusBadge
                    }
                    .padding(.leading, 8)
                }
                .padding(.vertical, 8)
            }

            Section("Contact Information") {
                if isEditing {
                    TextField("Email", text: $editEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $editPhone)
                        .keyboardType(.phonePad)
                } else {
                    LabeledContent("Email", value: contact.email)
                    LabeledContent("Phone", value: contact.phoneNumber)
                }
            }

            Section("Personal messages") {
                Button {
                    showingPersonalMessage = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: contact.hasPersonalContent ? "envelope.fill" : "envelope")
                                .font(.system(size: 15))
                                .foregroundStyle(.purple)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.hasPersonalContent ? "Personal messages" : "Add personal messages")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                if let msg = contact.personalMessage, !msg.isEmpty {
                                    Label("Message", systemImage: "text.quote")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if contact.videoMessageData != nil {
                                    Label("Video", systemImage: "video.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !contact.hasPersonalContent {
                                    Text("Written message or video, delivered on notification")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section("Notification Preferences") {
                Toggle("Wants funeral details", isOn: $wantsFuneralDetails)
                    .onChange(of: wantsFuneralDetails) { _, newValue in
                        contact.wantsFuneralDetails = newValue
                    }
            }

            Section("Verification") {
                LabeledContent("Last verified") {
                    if let date = contact.lastVerified {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    } else {
                        Text("Never").foregroundStyle(.secondary)
                    }
                }
                if contact.needsVerification {
                    Button("Mark as verified") {
                        contactsViewModel.verifyContact(contact)
                    }
                }
            }

            Section {
                if !contact.invitationAccepted {
                    Button("Resend invitation") { showingResendInvitation = true }
                }
                Button("Remove from list", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }

            if !contact.notes.isEmpty {
                Section("Notes") { Text(contact.notes) }
            }
        }
        .navigationTitle("Contact details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        contact.email = editEmail
                        contact.phoneNumber = editPhone
                        contactsViewModel.updateContact(contact)
                    } else {
                        editEmail = contact.email
                        editPhone = contact.phoneNumber
                    }
                    isEditing.toggle()
                }
            }
        }
        .onAppear {
            editEmail = contact.email
            editPhone = contact.phoneNumber
            wantsFuneralDetails = contact.wantsFuneralDetails
        }
        .sheet(isPresented: $showingPersonalMessage) {
            PersonalMessageView(contact: contact)
        }
        .alert("Remove contact?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                contactsViewModel.deleteContact(contact)
                dismiss()
            }
        } message: {
            Text("This person will no longer be notified. This cannot be undone.")
        }
        .alert("Resend invitation", isPresented: $showingResendInvitation) {
            Button("Cancel", role: .cancel) { }
            Button("Send") { contactsViewModel.sendInvitation(to: contact) }
        } message: {
            Text("Send another invitation to \(contact.fullName)?")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if contact.invitationAccepted {
            Label("Confirmed", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
        } else if contact.invitationSent {
            Label("Invitation pending", systemImage: "clock.fill").font(.caption).foregroundStyle(.orange)
        } else {
            Label("Not invited", systemImage: "xmark.circle.fill").font(.caption).foregroundStyle(.red)
        }
    }
}
