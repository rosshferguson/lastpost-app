//
//  HomeView.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import SwiftUI

struct HomeView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome header
                    welcomeHeader
                    
                    // Quick stats
                    statsSection
                    
                    // Alerts
                    if !contactsViewModel.contactsNeedingVerification.isEmpty {
                        verificationAlert
                    }
                    
                    // Quick actions
                    quickActions
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Final Farewell")
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let user = userViewModel.currentUser {
                Text("Hello, \(user.firstName)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your legacy is in order")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Contacts",
                value: "\(contactsViewModel.contacts.count)",
                icon: "person.2.fill",
                color: .blue
            )
            
            StatCard(
                title: "Designated",
                value: "\(userViewModel.currentUser?.designatedPersons.count ?? 0)",
                icon: "person.badge.key.fill",
                color: .purple
            )
            
            StatCard(
                title: "Memories",
                value: "\(userViewModel.currentUser?.sharedMedia.count ?? 0)",
                icon: "photo.fill",
                color: .orange
            )
        }
    }
    
    private var verificationAlert: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                Text("Contact Verification Needed")
                    .font(.headline)
            }
            
            Text("\(contactsViewModel.contactsNeedingVerification.count) contact(s) haven't been verified in over 6 months.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            NavigationLink {
                ContactListView(showOnlyUnverified: true)
            } label: {
                Text("Review Now")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                QuickActionButton(
                    title: "Add Contact",
                    icon: "person.badge.plus",
                    color: .blue
                ) {
                    // Navigation handled by parent
                }
                
                QuickActionButton(
                    title: "Add Memories",
                    icon: "photo.badge.plus",
                    color: .orange
                ) {
                    // Navigation handled by parent
                }
                
                QuickActionButton(
                    title: "Invite Designated",
                    icon: "envelope.fill",
                    color: .purple
                ) {
                    // Navigation handled by parent
                }
                
                QuickActionButton(
                    title: "Update Details",
                    icon: "pencil.circle.fill",
                    color: .green
                ) {
                    // Navigation handled by parent
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
