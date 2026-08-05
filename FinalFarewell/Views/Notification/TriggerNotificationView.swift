//
//  TriggerNotificationView.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import SwiftUI

struct TriggerNotificationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationViewModel: NotificationViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    
    let forUser: User
    
    @State private var showingConfirmationFlow = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)
                    
                    Text("Notification Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("For \(forUser.fullName)")
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // Info card
                VStack(alignment: .leading, spacing: 12) {
                    Label("Important", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    
                    Text("This action will notify \(forUser.contacts.count) people that \(forUser.firstName) has passed away. This process includes multiple verification steps and a waiting period to prevent accidental triggers.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                // Stats
                VStack(spacing: 16) {
                    HStack {
                        StatItem(title: "Contacts", value: "\(forUser.contacts.count)")
                        StatItem(title: "Confirmed", value: "\(forUser.contacts.filter { $0.invitationAccepted }.count)")
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action button
                Button {
                    showingConfirmationFlow = true
                } label: {
                    Text("Begin Notification Process")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("Trigger Notification")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingConfirmationFlow) {
            ConfirmDeathView(forUser: forUser)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
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
