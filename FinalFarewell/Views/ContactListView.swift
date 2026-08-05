import SwiftUI

struct ContactListView: View {
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @State private var showingAddContact = false
    @State private var searchText = ""
    
    var showOnlyUnverified: Bool = false
    
    var filteredContacts: [Contact] {
        let contacts = showOnlyUnverified 
            ? contactsViewModel.contactsNeedingVerification 
            : contactsViewModel.contacts
        
        if searchText.isEmpty {
            return contacts
        }
        
        return contacts.filter { contact in
            contact.fullName.localizedCaseInsensitiveContains(searchText) ||
            contact.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredContacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts",
                        systemImage: "person.2.slash",
                        description: Text("Add people you want notified when you pass.")
                    )
                } else {
                    ForEach(filteredContacts) { contact in
                        NavigationLink(destination: ContactDetailView(contact: contact)) {
                            ContactRow(contact: contact)
                        }
                    }
                    .onDelete(perform: deleteContacts)
                }
            }
            .navigationTitle(showOnlyUnverified ? "Verify Contacts" : "Notification List")
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactView()
            }
        }
    }
    
    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            contactsViewModel.deleteContact(filteredContacts[index])
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(contact.firstName.prefix(1) + contact.lastName.prefix(1))
                        .font(.headline)
                        .foregroundStyle(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName)
                    .font(.headline)
                
                Text(contact.relationship)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status indicators
            VStack(alignment: .trailing, spacing: 4) {
                if contact.invitationAccepted {
                    Label("Confirmed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if contact.invitationSent {
                    Label("Pending", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                if contact.needsVerification {
                    Label("Verify", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .labelStyle(.iconOnly)
        }
        .padding(.vertical, 4)
    }
}
