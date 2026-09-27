//
//  AddContactView.swift
//  FinalFarewell
//

import SwiftUI

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @EnvironmentObject var userViewModel: UserViewModel

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    @State private var notes = ""
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    @ObservedObject private var supabaseService = SupabaseService.shared

    let relationships = [
        "Spouse", "Partner", "Parent", "Child", "Sibling",
        "Friend", "Colleague", "Extended Family", "Other"
    ]

    var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && (!email.isEmpty || !phoneNumber.isEmpty)
    }

    var isPhoneOnly: Bool {
        !phoneNumber.isEmpty && email.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if !supabaseService.isEmailConfirmed {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.badge.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Email not verified")
                                    .font(.subheadline).fontWeight(.semibold)
                                Text("This contact won't receive their invitation until you confirm your email address.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                    Picker("Relationship", selection: $relationship) {
                        Text("Select...").tag("")
                        ForEach(relationships, id: \.self) { rel in
                            Text(rel).tag(rel)
                        }
                    }
                }

                Section("Contact Details") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                if isPhoneOnly {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "phone.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Manual notification only")
                                    .font(.subheadline).fontWeight(.semibold)
                                Text("Without an email address this contact will only appear on your emergency instruction sheet — your designated person will need to call them directly. Add an email to notify them automatically.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Notes") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Text(isPhoneOnly
                         ? "This contact has no email address and will appear on your emergency instruction sheet for manual notification."
                         : "This person will receive an invitation email asking them to confirm they're happy to be notified.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addContact() }
                        .disabled(!isFormValid)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }

    private func addContact() {
        guard isFormValid else {
            validationMessage = "Please enter a name and at least one contact method."
            showingValidationError = true
            return
        }

        contactsViewModel.addContact(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            relationship: relationship,
            notes: notes
        )

        // Send invitation email + SMS — dismiss after so the Task isn't orphaned
        let ownerName = userViewModel.currentUser?.fullName ?? "Someone"
        let rel = relationship.isEmpty ? "Contact" : relationship
        let capturedEmail = email
        let capturedPhone = phoneNumber
        let capturedFirst = firstName
        let capturedLast = lastName
        let shouldNotify = !capturedEmail.isEmpty  // phone-only contacts stay local

        dismiss()

        if shouldNotify {
            Task.detached {
                await SupabaseService.shared.notifyContactAdded(
                    ownerName: ownerName,
                    contactFirstName: capturedFirst,
                    contactLastName: capturedLast,
                    contactEmail: capturedEmail,
                    contactPhone: capturedPhone,
                    relationship: rel
                )
            }
        }
    }
}
