//
//  SettingsView.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var showingEditProfile = false
    @State private var notificationFrequency = "Monthly"
    
    let frequencies = ["Weekly", "Monthly", "Quarterly", "Yearly"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    if let user = userViewModel.currentUser {
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(user.firstName.prefix(1) + user.lastName.prefix(1))
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                )
                            
                            VStack(alignment: .leading) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button("Edit Profile") {
                            showingEditProfile = true
                        }
                    }
                }
                
                Section("Verification Reminders") {
                    Picker("Remind to verify contacts", selection: $notificationFrequency) {
                        ForEach(frequencies, id: \.self) { freq in
                            Text(freq).tag(freq)
                        }
                    }
                }
                
                Section("Privacy & Security") {
                    NavigationLink("Data & Privacy") {
                        DataPrivacyView()
                    }
                    
                    NavigationLink("Security Settings") {
                        SecuritySettingsView()
                    }
                }
                
                Section("Support") {
                    Link("Help Center", destination: URL(string: "[example.com](https://example.com/help)")!)
                    Link("Contact Support", destination: URL(string: "mailto:support@example.com")!)
                    Link("Privacy Policy", destination: URL(string: "[example.com](https://example.com/privacy)")!)
                    Link("Terms of Service", destination: URL(string: "[example.com](https://example.com/terms)")!)
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }
                
                Section {
                    Button("Delete Account", role: .destructive) {
                        // Handle account deletion
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
                
                Section("Contact Information") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        userViewModel.updateUser(
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            phoneNumber: phoneNumber
                        )
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let user = userViewModel.currentUser {
                    firstName = user.firstName
                    lastName = user.lastName
                    email = user.email
                    phoneNumber = user.phoneNumber
                }
            }
        }
    }
}

struct DataPrivacyView: View {
    var body: some View {
        List {
            Section {
                Text("Your data is encrypted and stored securely. We never share your personal information with third parties.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Section("Your Data") {
                Button("Export My Data") {
                    // Handle data export
                }
                
                Button("Download Contact List") {
                    // Handle contact list download
                }
            }
        }
        .navigationTitle("Data & Privacy")
    }
}

struct SecuritySettingsView: View {
    @State private var useBiometrics = true
    @State private var requirePINForNotification = true
    
    var body: some View {
        List {
            Section("Authentication") {
                Toggle("Use Face ID / Touch ID", isOn: $useBiometrics)
                
                Toggle("Require PIN for Notifications", isOn: $requirePINForNotification)
            }
            
            Section("Additional Security") {
                Button("Change PIN") {
                    // Handle PIN change
                }
                
                Button("View Login Activity") {
                    // Handle activity view
                }
            }
        }
        .navigationTitle("Security")
    }
}
