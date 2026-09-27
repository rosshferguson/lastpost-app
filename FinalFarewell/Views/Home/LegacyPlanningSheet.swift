//
//  LegacyPlanningSheet.swift
//  FinalFarewell
//
//  Quick-access sheet for all four legacy planning sections,
//  reachable from the Home screen quick action.
//

import SwiftUI

struct LegacyPlanningSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userViewModel: UserViewModel

    @State private var showingFuneralWishes = false
    @State private var showingLifeHistory = false
    @State private var showingDocuments = false
    @State private var showingDigitalAssets = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Record your wishes and important information so your designated person has everything they need.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Your legacy") {
                    PlanningRow(
                        icon: "heart.text.clipboard.fill",
                        color: .pink,
                        title: "Funeral wishes",
                        description: "Burial, cremation, service preferences",
                        isComplete: userViewModel.currentUser?.funeralWishesData != nil
                    ) { showingFuneralWishes = true }

                    PlanningRow(
                        icon: "book.fill",
                        color: .indigo,
                        title: "Life history",
                        description: "Your story in your own words",
                        isComplete: LifeHistory.load(forUserId: userViewModel.currentUser?.id ?? UUID()).hasAnyContent
                    ) { showingLifeHistory = true }

                    PlanningRow(
                        icon: "doc.text.fill",
                        color: .blue,
                        title: "Important documents",
                        description: "Will, insurance, bank contacts",
                        isComplete: userViewModel.currentUser?.importantDocumentsData != nil
                    ) { showingDocuments = true }

                    PlanningRow(
                        icon: "key.fill",
                        color: .orange,
                        title: "Digital assets",
                        description: "Accounts, passwords, online assets",
                        isComplete: !(userViewModel.currentUser?.digitalAssets.isEmpty ?? true)
                    ) { showingDigitalAssets = true }
                }
            }
            .navigationTitle("Legacy planning")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingFuneralWishes) { FuneralWishesView() }
            .sheet(isPresented: $showingDocuments) { DocumentsChecklistView() }
            .sheet(isPresented: $showingDigitalAssets) { NavigationStack { DigitalAssetsView() } }
            .sheet(isPresented: $showingLifeHistory) {
                NavigationStack {
                    if let user = userViewModel.currentUser {
                        LifeHistoryView(userId: user.id)
                    }
                }
            }
        }
    }
}

struct PlanningRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.13))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                    Text(description)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isComplete ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: isComplete ? 18 : 12))
                    .foregroundStyle(isComplete ? Color.green : Color.secondary.opacity(0.5))
            }
            .padding(.vertical, 4)
        }
    }
}
