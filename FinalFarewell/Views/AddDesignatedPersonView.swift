import SwiftUI

struct AddDesignatedPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    @State private var isPrimary = false
    @State private var canAccessPhotos = false
    
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
                
                Section("Permissions") {
                    Toggle("Primary Designated Person", isOn: $isPrimary)
                    
                    Toggle("Can Access Photos & Memories", isOn: $canAccessPhotos)
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addDesignatedPerson()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private func addDesignatedPerson() {
        guard let user = userViewModel.currentUser else { return }
        
        let person = DesignatedPerson(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            relationship: relationship,
            isPrimary: isPrimary
        )
        person.canAccessPhotos = canAccessPhotos
        person.owner = user
        
        user.designatedPersons.append(person)
        modelContext.insert(person)
        
        // Send invitation
        let inviteLink = DeepLinkService.generateDesignatedPersonLink(
            personId: person.id,
            fromUserId: user.id
        )
        person.invitationSent = true
        
        print("Designated person invitation: \(inviteLink)")
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save: \(error)")
        }
    }
}
