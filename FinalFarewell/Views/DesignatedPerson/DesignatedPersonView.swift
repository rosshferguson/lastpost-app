//
//  DesignatedPersonView.swift
//  FinalFarewell
//
//  Added:
//  - import SwiftData
//  - Swipe-to-delete via .onDelete on ForEach (more reliable than .swipeActions
//    when row content contains interactive buttons)
//  - Confirmation alert before deletion
//  - #if DEBUG "Accept for testing" button
//

import SwiftData
import SwiftUI

struct DesignatedPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var notificationViewModel: NotificationViewModel
    @AppStorage("isInDesignatedMode") private var isInDesignatedMode = false
    @State private var showingAddPerson = false
    @State private var personToDelete: DesignatedPerson?
    @State private var isEditing = false

    var designatedPersons: [DesignatedPerson] {
        userViewModel.currentUser?.designatedPersons ?? []
    }

    var overduePersons: [DesignatedPerson] {
        designatedPersons.filter { $0.needsReconfirmation }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your designated person(s) will be responsible for triggering notifications to your contact list when you pass away.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !overduePersons.isEmpty {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(overduePersons.count) designated person\(overduePersons.count == 1 ? "" : "s") need to reconfirm")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("It's been over a year since they confirmed their willingness.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if designatedPersons.isEmpty {
                    ContentUnavailableView(
                        "No designated person",
                        systemImage: "person.badge.key",
                        description: Text("Add someone you trust to manage notifications on your behalf.")
                    )
                } else {
                    Section("Your designated people") {
                        ForEach(designatedPersons) { person in
                            DesignatedPersonRow(
                                person: person,
                                onRequestReconfirmation: {
                                    requestReconfirmation(for: person)
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    personToDelete = person
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                personToDelete = designatedPersons[index]
                            }
                        }
                    }
                }

                if !userViewModel.usersIAmDesignatedFor.isEmpty {
                    Section("You are designated for") {
                        ForEach(userViewModel.usersIAmDesignatedFor) { user in
                            DesignatedForSection(
                                user: user,
                                notificationViewModel: notificationViewModel
                            )
                        }
                    }

                    Section {
                        Button {
                            isInDesignatedMode = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Switch to designated person mode", systemImage: "arrow.right.circle.fill")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .foregroundStyle(.purple)
                        .listRowBackground(Color.purple.opacity(0.07))
                    }
                }

                #if DEBUG
                Section("Testing") {
                    ForEach(designatedPersons) { person in
                        if !person.invitationAccepted {
                            Button("Accept for testing: \(person.firstName)") {
                                acceptForTesting(person)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
                #endif
            }
            .navigationTitle("My people")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddPerson = true } label: {
                        Image(systemName: "plus")
                    }
                }
                if !designatedPersons.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddDesignatedPersonView()
            }
            .task {
                if let user = userViewModel.currentUser {
                    // Sync owner side: remove any designees who removed themselves
                    await SupabaseService.shared.syncOwnerDesignatedPersons(
                        modelContext: modelContext,
                        currentUser: user
                    )
                    // Sync designee side: check acceptance status for pending invitations
                    await SupabaseService.shared.syncDesignatedPersonStatuses(
                        persons: designatedPersons,
                        modelContext: modelContext
                    )
                    // Sync roles we play for others
                    await SupabaseService.shared.fetchAndSyncDesignations(
                        modelContext: modelContext,
                        currentUser: user
                    )
                    userViewModel.loadUsersIAmDesignatedFor()
                }
            }
            .alert("Remove designated person?", isPresented: .init(
                get: { personToDelete != nil },
                set: { if !$0 { personToDelete = nil } }
            )) {
                Button("Remove", role: .destructive) {
                    if let person = personToDelete {
                        deleteDesignatedPerson(person)
                    }
                }
                Button("Cancel", role: .cancel) { personToDelete = nil }
            } message: {
                if let person = personToDelete {
                    if designatedPersons.count == 1 {
                        Text("Remove \(person.fullName) as a designated person?\n\nWarning: this is your only designated person. Without at least one, nobody will be able to notify your contacts when the time comes.")
                    } else {
                        Text("Remove \(person.fullName) as a designated person? They will no longer be able to initiate notifications on your behalf.")
                    }
                }
            }
        }
    }

    private func deleteDesignatedPerson(_ person: DesignatedPerson) {
        let email = person.email
        userViewModel.currentUser?.designatedPersons.removeAll { $0.id == person.id }
        modelContext.delete(person)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete designated person: \(error)")
        }
        personToDelete = nil
        // Revoke Supabase access so their web trigger link stops working
        Task { await SupabaseService.shared.revokeDesignatedPerson(email: email) }
    }

    private func requestReconfirmation(for person: DesignatedPerson) {
        guard let user = userViewModel.currentUser else { return }
        person.reconfirmationRequestedAt = Date()
        NotificationService.shared.scheduleDesignatedPersonReconfirmation(
            for: person,
            ownerName: user.fullName
        )
    }

    #if DEBUG
    private func acceptForTesting(_ person: DesignatedPerson) {
        guard let currentUser = userViewModel.currentUser else { return }
        person.invitationAccepted = true
        person.hasApp = true
        person.linkedUserId = currentUser.id
        userViewModel.saveContext()
        userViewModel.loadUsersIAmDesignatedFor()
    }
    #endif
}

// MARK: - Designated person row

struct DesignatedPersonRow: View {
    let person: DesignatedPerson
    let onRequestReconfirmation: () -> Void
    @State private var showingReconfirmAlert = false
    @State private var reconfirmSent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.badge.key.fill")
                            .foregroundStyle(.purple)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(person.fullName).font(.headline)
                        if person.isPrimary {
                            Text("Primary")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }
                    Text(person.relationship)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(person.reconfirmationStatus)
                        .font(.caption)
                        .foregroundStyle(person.needsReconfirmation ? Color.orange : Color.secondary)
                }

                Spacer()

                if person.invitationAccepted {
                    if person.needsReconfirmation {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    } else {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                } else if person.invitationSent {
                    Image(systemName: "clock.fill").foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)

            if person.needsReconfirmation && person.invitationAccepted {
                Button {
                    showingReconfirmAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle")
                            .foregroundStyle(.orange)
                        Text(reconfirmSent ? "Reminder sent" : "Request reconfirmation")
                            .font(.caption)
                            .foregroundStyle(reconfirmSent ? Color.secondary : Color.orange)
                    }
                    .padding(.leading, 56)
                    .padding(.bottom, 6)
                }
                .disabled(reconfirmSent)
                .alert("Request reconfirmation?", isPresented: $showingReconfirmAlert) {
                    Button("Send reminder") {
                        onRequestReconfirmation()
                        reconfirmSent = true
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will send \(person.firstName) a reminder to confirm they're still willing and able to act as your designated person.")
                }
            }
        }
    }
}

// MARK: - Designated for section

struct DesignatedForSection: View {
    let user: User
    @ObservedObject var notificationViewModel: NotificationViewModel
    @State private var showingFuneralDetails = false
    @State private var showingLegacy = false

    var ownerSupabaseId: UUID {
        // Try local→Supabase mapping first (set by fetchAndSyncDesignations at sign-in)
        if let mapped = SupabaseService.shared.supabaseId(forLocalUserId: user.id) {
            print("[ownerSupabaseId] using idMapping: \(mapped.uuidString)")
            return mapped
        }
        // Fallback: read current user's Supabase UUID from UserDefaults directly
        // (handles self-designation test scenario and session-restore timing issues)
        if let stored = UserDefaults.standard.string(forKey: "currentSupabaseUserId"),
           let uuid = UUID(uuidString: stored) {
            print("[ownerSupabaseId] using UserDefaults fallback: \(uuid.uuidString)")
            return uuid
        }
        print("[ownerSupabaseId] ⚠️ all fallbacks failed, returning local UUID: \(user.id.uuidString)")
        return user.id
    }

    var confirmedNotification: DeathNotification? {
        notificationViewModel.currentNotification?.isConfirmed == true
            ? notificationViewModel.currentNotification : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                TriggerNotificationView(forUser: user)
            } label: {
                DesignatedForRow(user: user)
            }

            if let notification = confirmedNotification,
               notification.deceasedUserId == user.id {

                Divider().padding(.leading, 62).padding(.top, 4)

                Button {
                    showingFuneralDetails = true
                } label: {
                    designatedActionRow(
                        icon: notification.funeralDate != nil ? "calendar.badge.checkmark" : "calendar.badge.plus",
                        iconColor: .blue,
                        title: notification.funeralDate != nil ? "Update funeral details" : "Send funeral details",
                        subtitle: notification.funeralDate != nil
                            ? "Details already sent — tap to update"
                            : "Notify contacts who requested funeral information"
                    )
                }

                Divider().padding(.leading, 62)

                Button {
                    showingLegacy = true
                } label: {
                    designatedActionRow(
                        icon: "doc.text.magnifyingglass",
                        iconColor: .purple,
                        title: "View \(user.firstName)'s legacy information",
                        subtitle: "Funeral wishes, documents, digital assets and more"
                    )
                }

                Divider().padding(.leading, 62)

                NavigationLink {
                    NotificationAuditLogView(notification: notification)
                } label: {
                    designatedActionRow(
                        icon: "list.clipboard",
                        iconColor: .gray,
                        title: "Notification log",
                        subtitle: "Full record of who was notified and when"
                    )
                }

                Divider().padding(.leading, 62).padding(.bottom, 4)
            }

            #if DEBUG
            Button("[DEBUG] View legacy info") {
                showingLegacy = true
            }
            .foregroundStyle(.orange)
            #endif
        }
        .sheet(isPresented: $showingFuneralDetails) {
            SendFuneralDetailsView(ownerName: user.fullName, ownerSupabaseId: ownerSupabaseId)
        }
        .sheet(isPresented: $showingLegacy) {
            DesignatedLegacyView(ownerName: user.fullName, ownerId: ownerSupabaseId)
        }
    }

    @ViewBuilder
    private func designatedActionRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Designated for row

struct DesignatedForRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 52, height: 52)
                Text(user.firstName.prefix(1) + user.lastName.prefix(1))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.headline)
                Text("Tap to manage their notifications")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
