//
//  UserViewModel.swift
//  FinalFarewell
//
//  Updated: added Supabase auth (sign up, sign in, sign out).
//
//  Changes from previous version:
//  - isAuthenticated and authError published properties added
//  - signUp() / signIn() / signOut() delegate to SupabaseService
//  - On sign up / sign in, the Supabase UUID is saved against the local
//    SwiftData user ID so NotificationViewModel can find it later
//  - updateLastSeen() called when the user signs in and on app foreground
//    (see FinalFarewellApp.swift)
//  - All existing local SwiftData logic is unchanged
//  - refreshDesignations() added for foreground refresh of designation state
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var pendingNotifications: [DeathNotification] = []
    @Published var usersIAmDesignatedFor: [User] = []

    // Auth state (mirrors SupabaseService, exposed here for convenience in views)
    @Published var isAuthenticated = false
    @Published var authError: String?

    var modelContext: ModelContext?
    private var supabaseCancellable: AnyCancellable?

    init() {
        // Subscribe to auth state immediately so ContentView's auth gate
        // reflects changes as soon as restoreSession() completes.
        supabaseCancellable = SupabaseService.shared.$isAuthenticated
            .receive(on: RunLoop.main)
            .sink { [weak self] authenticated in
                self?.isAuthenticated = authenticated
            }
        // Restore session in the background — updates isAuthenticated once done
        Task { await SupabaseService.shared.restoreSession() }
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadCurrentUser()
    }

    // MARK: - Supabase auth

    /// Creates a Supabase account and links it to the current local user.
    func signUp(email: String, password: String) async {
        guard let user = currentUser, let context = modelContext else {
            authError = "Please complete your profile before signing up."
            return
        }

        isLoading = true
        authError = nil

        do {
            try await SupabaseService.shared.signUp(
                email: email,
                password: password,
                firstName: user.firstName,
                lastName: user.lastName
            )

            // Link the new Supabase UUID to this device's local user
            SupabaseService.shared.saveSupabaseId(forLocalUserId: user.id)

            await SupabaseService.shared.updateLastSeen()

            // Accept any pending designations matching this email, then sync to local
            await SupabaseService.shared.linkPendingDesignations(userEmail: email)
            await SupabaseService.shared.fetchAndSyncDesignations(modelContext: context, currentUser: user)
            loadUsersIAmDesignatedFor()

            authError = nil
        } catch {
            authError = error.localizedDescription
        }

        isLoading = false
    }

    /// Signs in to an existing Supabase account and links it to the local user.
    func signIn(email: String, password: String) async {
        guard let user = currentUser, let context = modelContext else {
            authError = "No local profile found. Please complete onboarding first."
            return
        }

        isLoading = true
        authError = nil

        do {
            try await SupabaseService.shared.signIn(email: email, password: password)

            // Link the signed-in Supabase UUID to this device's local user
            SupabaseService.shared.saveSupabaseId(forLocalUserId: user.id)

            await SupabaseService.shared.updateLastSeen()

            // Reload the local profile — now that supabaseUserEmail is set,
            // loadCurrentUser() will prefer the User whose email matches.
            loadCurrentUser()

            // Accept any pending designations matching this email, then sync to local
            if let refreshedUser = currentUser {
                await SupabaseService.shared.linkPendingDesignations(userEmail: email)
                await SupabaseService.shared.fetchAndSyncDesignations(modelContext: context, currentUser: refreshedUser)
            }
            loadUsersIAmDesignatedFor()

            authError = nil
        } catch {
            authError = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() async {
        isLoading = true
        do {
            try await SupabaseService.shared.signOut()
            // Reset auth prompt so the sign-in screen is shown after sign-out
            UserDefaults.standard.set(false, forKey: "hasSeenAuthPrompt")
            authError = nil
        } catch {
            authError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Designation refresh

    /// Refreshes designation state from Supabase — call on app foreground and
    /// when entering DesignatedModeView so the list stays current without sign-out/in.
    func refreshDesignations() async {
        guard let context = modelContext,
              let user = currentUser,
              SupabaseService.shared.isAuthenticated,
              let email = SupabaseService.shared.supabaseUserEmail else { return }
        await SupabaseService.shared.linkPendingDesignations(userEmail: email)
        await SupabaseService.shared.fetchAndSyncDesignations(modelContext: context, currentUser: user)
        loadUsersIAmDesignatedFor()
    }

    /// Removes the current user as a designated person for the given owner,
    /// then re-syncs so DesignatedModeView reflects the change immediately.
    func removeMyselfAsDesignatedPerson(ownerSupabaseId: UUID) async {
        guard let context = modelContext, let user = currentUser else { return }
        await SupabaseService.shared.removeMyselfAsDesignatedPerson(ownerSupabaseId: ownerSupabaseId)
        await SupabaseService.shared.fetchAndSyncDesignations(modelContext: context, currentUser: user)
        loadUsersIAmDesignatedFor()
    }

    // MARK: - Local user loading

    func loadCurrentUser() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { !$0.isDeceased },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let users = try context.fetch(descriptor)
            // If we know which email is signed in, prefer the local profile that
            // matches — so switching Supabase accounts shows the right user.
            if let signedInEmail = SupabaseService.shared.supabaseUserEmail,
               let match = users.first(where: { $0.email.lowercased() == signedInEmail.lowercased() }) {
                currentUser = match
            } else {
                currentUser = users.first
            }
            // Sync the auth email into the local record so the profile always
            // reflects the signed-in account, even if the SwiftData record was
            // created before the email was stored or with a different email.
            if let user = currentUser,
               let authEmail = SupabaseService.shared.supabaseUserEmail,
               user.email.lowercased() != authEmail.lowercased() {
                user.email = authEmail
                try? context.save()
            }
            loadUsersIAmDesignatedFor()
        } catch {
            errorMessage = "Failed to load user: \(error.localizedDescription)"
        }
    }

    func loadUsersIAmDesignatedFor() {
        guard let context = modelContext, let currentUserId = currentUser?.id else {
            usersIAmDesignatedFor = []
            return
        }

        let targetId: UUID? = currentUserId
        let descriptor = FetchDescriptor<DesignatedPerson>(
            predicate: #Predicate { $0.linkedUserId == targetId && $0.invitationAccepted }
        )

        do {
            let designations = try context.fetch(descriptor)
            var seen = Set<UUID>()
            usersIAmDesignatedFor = designations.compactMap { person -> User? in
                guard let owner = person.owner, !seen.contains(owner.id) else { return nil }
                seen.insert(owner.id)
                return owner
            }
        } catch {
            errorMessage = "Failed to load designations: \(error.localizedDescription)"
        }
    }

    func acceptDesignatedPersonInvitation(personId: UUID, fromUserId: UUID) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<DesignatedPerson>(
            predicate: #Predicate { $0.id == personId }
        )

        do {
            let persons = try context.fetch(descriptor)
            if let person = persons.first {
                person.invitationAccepted = true
                person.hasApp = true
                person.linkedUserId = currentUser?.id
                try context.save()
                loadUsersIAmDesignatedFor()
            }
        } catch {
            errorMessage = "Failed to accept designated person invitation: \(error.localizedDescription)"
        }
    }

    // MARK: - User CRUD

    func createUser(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String,
        dateOfBirth: Date?
    ) {
        guard let context = modelContext else { return }

        let user = User(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            dateOfBirth: dateOfBirth
        )

        context.insert(user)

        do {
            try context.save()
            currentUser = user
        } catch {
            errorMessage = "Failed to create user: \(error.localizedDescription)"
        }
    }

    func updateUser(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String
    ) {
        guard let user = currentUser else { return }

        user.firstName = firstName.trimmingCharacters(in: .whitespaces)
        user.lastName = lastName.trimmingCharacters(in: .whitespaces)
        user.email = email.trimmingCharacters(in: .whitespaces)
        user.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
        user.lastUpdated = Date()

        saveContext()

        // Sync to Supabase in background
        Task {
            await SupabaseService.shared.updateProfile(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phoneNumber: phoneNumber
            )
        }
    }

    func markUserAsDeceased() {
        guard let user = currentUser else { return }
        user.isDeceased = true
        user.deceasedDate = Date()
        saveContext()
    }

    func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
