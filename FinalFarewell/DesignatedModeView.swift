//
//  DesignatedModeView.swift
//  FinalFarewell
//
//  Provides a clean, focused experience for someone who is using the app
//  purely as a designated person — not as an account owner.
//  Shown when the user taps "I'm a designated person" on the launch screen,
//  or when the app detects they have no own account but are designated for others.
//
//  Updated: designated person can now view the full contact list before triggering.
//

import SwiftUI

struct DesignatedModeView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var notificationViewModel: NotificationViewModel
    @State private var selectedUser: User?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                designatedHeader

                if userViewModel.usersIAmDesignatedFor.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            Text("You are listed as a designated person for the following people. You can trigger their notification process here when the time comes.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Section("People you manage") {
                            ForEach(userViewModel.usersIAmDesignatedFor) { user in
                                let ownerSupabaseId = SupabaseService.shared.supabaseId(forLocalUserId: user.id) ?? user.id
                                DesignatedModeUserRow(
                                    user: user,
                                    notificationViewModel: notificationViewModel,
                                    ownerSupabaseId: ownerSupabaseId,
                                    onRemove: {
                                        await userViewModel.removeMyselfAsDesignatedPerson(ownerSupabaseId: ownerSupabaseId)
                                    }
                                )
                            }
                        }

                        Section {
                            Button {
                                UserDefaults.standard.set(false, forKey: "isInDesignatedMode")
                            } label: {
                                Label("Switch to my account", systemImage: "arrow.left.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var designatedHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.3, blue: 0.6), Color(red: 0.2, green: 0.45, blue: 0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Designated person")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text("Hello, \(userViewModel.currentUser?.firstName ?? "there")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.badge.key")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No accounts assigned")
                .font(.headline)
            Text("You haven't been added as a designated person for anyone yet. Ask the person who invited you to check their app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                UserDefaults.standard.set(false, forKey: "isInDesignatedMode")
            } label: {
                Label("Go to my account", systemImage: "arrow.left.circle")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Row for each person this user manages

struct DesignatedModeUserRow: View {
    let user: User
    @ObservedObject var notificationViewModel: NotificationViewModel
    let ownerSupabaseId: UUID
    var onRemove: (() async -> Void)? = nil
    @State private var showingTrigger = false
    @State private var showingFuneralDetails = false
    @State private var showingContacts = false
    @State private var showingLegacy = false
    @State private var showingRemoveAlert = false
    @State private var isRemoving = false

    var isConfirmed: Bool {
        notificationViewModel.currentNotification?.isConfirmed == true &&
        notificationViewModel.currentNotification?.deceasedUserId == user.id
    }

    var isInProgress: Bool {
        notificationViewModel.currentNotification != nil &&
        notificationViewModel.currentNotification?.isConfirmed == false &&
        notificationViewModel.currentNotification?.deceasedUserId == user.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Person header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 54, height: 54)
                    Text(user.firstName.prefix(1) + user.lastName.prefix(1))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(user.fullName)
                        .font(.headline)
                    HStack(spacing: 8) {
                        statusBadge
                        if !user.contacts.isEmpty {
                            Button {
                                showingContacts = true
                            } label: {
                                HStack(spacing: 3) {
                                    Text("\(user.contacts.count) contact\(user.contacts.count == 1 ? "" : "s") to notify")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.blue.opacity(0.7))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(.top, 6)

            // Trigger button — full width, more prominent
            if !isConfirmed {
                Button {
                    showingTrigger = true
                } label: {
                    HStack {
                        Spacer()
                        Label(
                            isInProgress ? "Continue notification" : "Initiate notification",
                            systemImage: isInProgress ? "arrow.right.circle.fill" : "bell.fill"
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 13)
                    .background(isInProgress ? Color.orange : Color.red.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)
            }

            // Post-confirmation actions
            if isConfirmed {
                VStack(spacing: 0) {
                    actionRow(
                        icon: notificationViewModel.currentNotification?.funeralDate != nil
                            ? "calendar.badge.checkmark" : "calendar.badge.plus",
                        iconColor: .blue,
                        title: notificationViewModel.currentNotification?.funeralDate != nil
                            ? "Update funeral details" : "Send funeral details"
                    ) { showingFuneralDetails = true }

                    Divider().padding(.leading, 50)

                    actionRow(
                        icon: "doc.text.magnifyingglass",
                        iconColor: .purple,
                        title: "View \(user.firstName)'s legacy information"
                    ) { showingLegacy = true }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 6)
            }

            // Remove myself button — inside the VStack, below other actions
            if onRemove != nil {
                Button(role: .destructive) {
                    showingRemoveAlert = true
                } label: {
                    HStack {
                        if isRemoving {
                            ProgressView().tint(.red)
                        } else {
                            Label("Remove myself as designated person", systemImage: "person.badge.minus")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                    }
                }
                .disabled(isRemoving)
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
        }
        .fullScreenCover(isPresented: $showingTrigger) {
            TriggerNotificationView(forUser: user)
        }
        .sheet(isPresented: $showingFuneralDetails) {
            SendFuneralDetailsView(ownerName: user.fullName, ownerSupabaseId: ownerSupabaseId)
        }
        .sheet(isPresented: $showingContacts) {
            DesignatedContactsListView(user: user)
        }
        .sheet(isPresented: $showingLegacy) {
            DesignatedLegacyView(ownerName: user.fullName, ownerId: ownerSupabaseId)
        }
        .alert("Remove yourself as \(user.firstName)'s designated person?", isPresented: $showingRemoveAlert) {
            Button("Remove", role: .destructive) {
                Task {
                    isRemoving = true
                    await onRemove?()
                    isRemoving = false
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(user.firstName) will need to add you again if you change your mind.")
        }
    }

    @ViewBuilder
    private func actionRow(icon: String, iconColor: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isConfirmed {
            Text("Notified")
                .font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.green.opacity(0.15)).foregroundStyle(.green)
                .clipShape(Capsule())
        } else if isInProgress {
            Text("In progress")
                .font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.orange.opacity(0.15)).foregroundStyle(.orange)
                .clipShape(Capsule())
        } else {
            Text("Waiting")
                .font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.blue.opacity(0.12)).foregroundStyle(.blue)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Read-only contact list for designated person

struct DesignatedContactsListView: View {
    @Environment(\.dismiss) private var dismiss
    let user: User

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("These are the people who will be notified when you initiate the notification for \(user.firstName).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                let confirmed = user.contacts.filter { $0.invitationAccepted }
                let pending   = user.contacts.filter { !$0.invitationAccepted }

                if !confirmed.isEmpty {
                    Section("Will be notified (\(confirmed.count))") {
                        ForEach(confirmed) { contact in
                            contactRow(contact, confirmed: true)
                        }
                    }
                }

                if !pending.isEmpty {
                    Section("Invitation pending (\(pending.count))") {
                        ForEach(pending) { contact in
                            contactRow(contact, confirmed: false)
                        }
                    }
                }

                if user.contacts.isEmpty {
                    Section {
                        Text("\(user.firstName) has not added any contacts yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(user.firstName)'s contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func contactRow(_ contact: Contact, confirmed: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(confirmed ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(contact.firstName.prefix(1) + contact.lastName.prefix(1))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(confirmed ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !contact.relationship.isEmpty {
                    Text(contact.relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !contact.email.isEmpty {
                    Text(contact.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: confirmed ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(confirmed ? .green : .orange)
                .font(.system(size: 16))
        }
        .padding(.vertical, 2)
    }
}
