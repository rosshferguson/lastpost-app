import SwiftUI

struct ContactDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    
    @Bindable var contact: Contact
    
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showingResendInvitation = false
    
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
                    TextField("Email", text: $contact.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone", text: $contact.phoneNumber)
                        .keyboardType(.phonePad)
                } else {
                    LabeledContent("Email", value: contact.email)
                    LabeledContent("Phone", value: contact.phoneNumber)
                }
            }
            
            Section("Notification Preferences") {
                Toggle("Wants funeral details", isOn: $contact.wantsFuneralDetails)
            }
            
            Section("Verification") {
                LabeledContent("Last Verified") {
                    if let date = contact.lastVerified {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    } else {
                        Text("Never")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if contact.needsVerification {
                    Button("Mark as Verified") {
                        contactsViewModel.verifyContact(contact)
                    }
                }
            }
            
            Section {
                if !contact.invitationAccepted {
                    Button("Resend Invitation") {
                        showingResendInvitation = true
                    }
                }
                
                Button("Remove from List", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
            
            if !contact.notes.isEmpty {
                Section("Notes") {
                    Text(contact.notes)
                }
            }
        }
        .navigationTitle("Contact Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        contactsViewModel.updateContact(contact)
                    }
                    isEditing.toggle()
                }
            }
        }
        .alert("Remove Contact?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                contactsViewModel.deleteContact(contact)
                dismiss()
            }
        } message: {
            Text("This person will no longer be notified. This cannot be undone.")
        }
        .alert("Resend Invitation", isPresented: $showingResendInvitation) {
            Button("Cancel", role: .cancel) { }
            Button("Send") {
                contactsViewModel.sendInvitation(to: contact)
            }
        } message: {
            Text("Send another invitation to \(contact.fullName)?")
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        if contact.invitationAccepted {
            Label("Confirmed", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else if contact.invitationSent {
            Label("Invitation Pending", systemImage: "clock.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Label("Not Invited", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
