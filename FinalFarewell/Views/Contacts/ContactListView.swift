//
//  ContactListView.swift
//  FinalFarewell
//
//  Added:
//  - Grouped display: contacts shown by their group when grouping is enabled
//  - Toolbar toggle between flat and grouped views
//  - Group assignment accessible from ContactRow swipe actions
//

import SwiftUI

struct ContactListView: View {
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @StateObject private var addressBookMatch = AddressBookMatchService.shared
    @State private var showingAddContact = false
    @State private var showingImportContacts = false
    @State private var searchText = ""
    @State private var isGrouped = false
    @State private var contactToGroup: Contact?

    var showOnlyUnverified: Bool = false

    let defaultGroups = ["Family", "Friends", "Work", "Legal", "Medical", "Other"]

    var filteredContacts: [Contact] {
        let contacts = showOnlyUnverified
            ? contactsViewModel.contactsNeedingVerification
            : contactsViewModel.contacts
        if searchText.isEmpty { return contacts }
        return contacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedContacts: [(String, [Contact])] {
        let ungrouped = filteredContacts.filter { $0.group == nil || $0.group!.isEmpty }
        var groups: [(String, [Contact])] = defaultGroups.compactMap { group in
            let members = filteredContacts.filter { $0.group == group }
            return members.isEmpty ? nil : (group, members)
        }
        if !ungrouped.isEmpty { groups.append(("Ungrouped", ungrouped)) }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredContacts.isEmpty {
                    ContentUnavailableView(
                        "No contacts",
                        systemImage: "person.2.slash",
                        description: Text("Add people you want notified when you pass.")
                    )
                } else if isGrouped {
                    groupedList
                } else {
                    flatList
                }
            }
            .navigationTitle(showOnlyUnverified ? "Verify contacts" : "Notification list")
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddContact = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button { showingImportContacts = true } label: {
                        Label("Import", systemImage: "person.2.badge.plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        withAnimation { isGrouped.toggle() }
                    } label: {
                        Label(isGrouped ? "List view" : "Group view",
                              systemImage: isGrouped ? "list.bullet" : "rectangle.3.group")
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) { AddContactView() }
            .sheet(isPresented: $showingImportContacts) { ContactImportView() }
            .sheet(item: $contactToGroup) { contact in
                GroupPickerView(contact: contact, groups: defaultGroups) {
                    contactsViewModel.updateContact(contact)
                }
            }
            .task {
                // Do NOT auto-request contacts access — only load after the
                // user explicitly chooses to import from their address book.
                await contactsViewModel.syncInvitationStatuses()
            }
        }
    }

    // MARK: - Flat list

    private var flatList: some View {
        ForEach(filteredContacts) { contact in
            NavigationLink(destination: ContactDetailView(contact: contact)) {
                ContactRow(contact: contact, isInAddressBook: addressBookMatch.isInAddressBook(
                    email: contact.email, phone: contact.phoneNumber
                ))
            }
            .swipeActions(edge: .leading) {
                Button {
                    contactToGroup = contact
                } label: {
                    Label("Group", systemImage: "rectangle.3.group")
                }
                .tint(.blue)
            }
        }
        .onDelete(perform: deleteContacts)
    }

    // MARK: - Grouped list

    @ViewBuilder
    private var groupedList: some View {
        ForEach(groupedContacts, id: \.0) { groupName, contacts in
            Section(groupName) {
                ForEach(contacts) { contact in
                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                        ContactRow(contact: contact, isInAddressBook: addressBookMatch.isInAddressBook(
                            email: contact.email, phone: contact.phoneNumber
                        ))
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            contactToGroup = contact
                        } label: {
                            Label("Group", systemImage: "rectangle.3.group")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { offsets in
                    for i in offsets { contactsViewModel.deleteContact(contacts[i]) }
                }
            }
        }
    }

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets { contactsViewModel.deleteContact(filteredContacts[index]) }
    }
}

// MARK: - Group picker sheet

struct GroupPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var contact: Contact
    let groups: [String]
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("No group") {
                        contact.group = nil
                        onSave()
                        dismiss()
                    }
                    .foregroundStyle(contact.group == nil ? .purple : .primary)
                }

                Section("Groups") {
                    ForEach(groups, id: \.self) { group in
                        Button {
                            contact.group = group
                            onSave()
                            dismiss()
                        } label: {
                            HStack {
                                Text(group)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if contact.group == group {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.purple)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Contact row (unchanged)

struct ContactRow: View {
    let contact: Contact
    var isInAddressBook: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(contact.firstName.prefix(1) + contact.lastName.prefix(1))
                        .font(.headline).foregroundStyle(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contact.fullName).font(.headline)
                    if isInAddressBook {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .help("Also in your phone contacts")
                    }
                }
                Text(contact.relationship).font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if contact.email.isEmpty {
                    Label("Manual", systemImage: "phone.fill")
                        .font(.caption).foregroundStyle(.orange)
                } else if contact.invitationAccepted {
                    Label("Confirmed", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                } else if contact.invitationSent {
                    Label("Pending", systemImage: "clock.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                if contact.needsVerification {
                    Label("Verify", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
                if contact.hasPersonalContent {
                    Label("Message", systemImage: "envelope.fill")
                        .font(.caption).foregroundStyle(.purple)
                }
            }
            .labelStyle(.iconOnly)
        }
        .padding(.vertical, 4)
    }
}
