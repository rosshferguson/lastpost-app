//
//  AddDesignatedPersonView.swift
//  FinalFarewell
//
//  Updated: subscription gate + canViewArrangements permission toggle.
//

import SwiftData
import SwiftUI

struct AddDesignatedPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    @State private var isPrimary = false
    @State private var canAccessPhotos = false
    @State private var canViewArrangements = true
    @State private var showPaywall = false
    @ObservedObject private var supabaseService = SupabaseService.shared

    let relationships = [
        "Spouse", "Partner", "Parent", "Child", "Sibling",
        "Friend", "Solicitor", "Executor", "Other"
    ]

    var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty
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
                                Text("This person won't receive their invitation until you confirm your email address.")
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
                    TextField("Email (required)", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number (optional)", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email address is required")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("Your designated person needs an email address to receive their invitation and trigger link. Without it they cannot fulfil their role.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Permissions") {
                    Toggle("Primary Designated Person", isOn: $isPrimary)
                    Toggle("Can Access Photos & Memories", isOn: $canAccessPhotos)
                    Toggle("Can View Funeral Arrangements", isOn: $canViewArrangements)
                    if canViewArrangements {
                        Text("This person will be able to view your funeral wishes and important document checklist after confirming a notification.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Important", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.headline)
                        Text("This person will have the ability to notify your contacts of your passing. Choose someone you trust completely.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Designated Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addDesignatedPerson() }
                        .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: "Add more than 1 designated person with Last Post Premium.")
                    .environmentObject(subscriptionService)
            }
        }
    }

    private func addDesignatedPerson() {
        guard isFormValid, let user = userViewModel.currentUser else { return }

        // Subscription gate
        guard subscriptionService.canAddDesignatedPerson(currentCount: user.designatedPersons.count) else {
            showPaywall = true
            return
        }

        let person = DesignatedPerson(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            relationship: relationship,
            isPrimary: isPrimary
        )
        person.canAccessPhotos = canAccessPhotos
        person.canViewArrangements = canViewArrangements
        person.owner = user
        user.designatedPersons.append(person)
        modelContext.insert(person)

        let inviteLink = DeepLinkService.generateDesignatedPersonLink(
            personId: person.id,
            fromUserId: user.id
        )
        person.invitationSent = true

        do {
            try modelContext.save()

            // Sync to Supabase and send invitation email
            let ownerName = user.fullName
            let dpName = "\(firstName) \(lastName)"
            let rel = relationship.isEmpty ? "Trusted person" : relationship
            // Use supabaseUserId directly — supabaseId(forLocalUserId:) only maps shadow accounts
            let ownerSupabaseId = SupabaseService.shared.supabaseUserId
                ?? UserDefaults.standard.string(forKey: "currentSupabaseUserId").flatMap(UUID.init)
            Task {
                // Single call: the edge function upserts the DB row and sends the email
                // with the Accept button in one shot — no separate sync needed.
                await SupabaseService.shared.notifyDesignatedPersonAdded(
                    ownerName: ownerName,
                    designatedPersonName: dpName,
                    designatedPersonEmail: email,
                    designatedPersonPhone: phoneNumber,
                    relationship: rel,
                    inviteLink: inviteLink.absoluteString,
                    ownerId: ownerSupabaseId?.uuidString,
                    canAccessPhotos: canAccessPhotos,
                    canViewArrangements: canViewArrangements
                )
            }

            dismiss()
        } catch {
            print("Failed to save: \(error)")
        }
    }
}
