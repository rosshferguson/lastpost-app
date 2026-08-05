import SwiftUI

struct DesignatedPersonView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var showingAddPerson = false
    
    var designatedPersons: [DesignatedPerson] {
        userViewModel.currentUser?.designatedPersons ?? []
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your designated person(s) will be responsible for triggering notifications to your contact list when you pass away.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if designatedPersons.isEmpty {
                    ContentUnavailableView(
                        "No Designated Person",
                        systemImage: "person.badge.key",
                        description: Text("Add someone you trust to manage notifications on your behalf.")
                    )
                } else {
                    Section("Your Designated People") {
                        ForEach(designatedPersons) { person in
                            DesignatedPersonRow(person: person)
                        }
                    }
                }
                
                // If current user is designated for others
                if !userViewModel.usersIAmDesignatedFor.isEmpty {
                    Section("You Are Designated For") {
                        ForEach(userViewModel.usersIAmDesignatedFor) { user in
                            NavigationLink {
                                TriggerNotificationView(forUser: user)
                            } label: {
                                DesignatedForRow(user: user)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Designated Person")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPerson = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddDesignatedPersonView()
            }
        }
    }
}

struct DesignatedPersonRow: View {
    let person: DesignatedPerson
    
    var body: some View {
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
                    Text(person.fullName)
                        .font(.headline)
                    
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
            }
            
            Spacer()
            
            if person.invitationAccepted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if person.invitationSent {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DesignatedForRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(user.firstName.prefix(1) + user.lastName.prefix(1))
                        .font(.headline)
                        .foregroundStyle(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.headline)
                
                Text("You can manage their notifications")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
