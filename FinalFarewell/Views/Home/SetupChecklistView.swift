//
//  SetupChecklistView.swift
//  FinalFarewell
//
//  A dismissable checklist shown on the home screen after onboarding
//  until all key setup steps are complete. Guides new users to a
//  useful state quickly.
//

import SwiftUI

struct SetupChecklistView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @Binding var selectedTab: Int

    @AppStorage("setupChecklistDismissed") private var isDismissed = false
    @AppStorage("appleLegacyContactDone") private var legacyContactDone = false

    @State private var showingCheckIn = false
    @State private var showingPersonalMessage = false
    @State private var showingLegacyContactGuide = false

    var steps: [SetupStep] {
        let user = userViewModel.currentUser
        return [
            SetupStep(
                title: "Add your first contact",
                description: "Add someone you want notified.",
                isComplete: !contactsViewModel.contacts.isEmpty,
                action: { selectedTab = 1 }
            ),
            SetupStep(
                title: "Choose a designated person",
                description: "Someone trusted to initiate notifications.",
                isComplete: !(user?.designatedPersons.isEmpty ?? true),
                action: { selectedTab = 2 }
            ),
            SetupStep(
                title: "Set your annual check-in date",
                description: "Get a yearly reminder to review your list.",
                isComplete: user?.annualCheckInDate != nil,
                action: { showingCheckIn = true }
            ),
            SetupStep(
                title: "Add your funeral wishes",
                description: "Record your preferences in advance.",
                isComplete: user?.funeralWishesData != nil,
                action: { showingPersonalMessage = true }
            ),
            SetupStep(
                title: "Set up Apple Legacy Contact",
                description: "Let a trusted person access your Apple account after you pass.",
                isComplete: legacyContactDone,
                action: { showingLegacyContactGuide = true }
            ),
        ]
    }

    var completedCount: Int { steps.filter { $0.isComplete }.count }
    var allComplete: Bool { completedCount == steps.count }

    var body: some View {
        if isDismissed || allComplete { EmptyView() } else { card }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get set up")
                        .font(.headline)
                    Text("\(completedCount) of \(steps.count) complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: Double(completedCount), total: Double(steps.count))
                .tint(.purple)

            VStack(spacing: 8) {
                ForEach(steps) { step in
                    Button {
                        if !step.isComplete { step.action() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.isComplete ? .green : .secondary)
                                .font(.system(size: 18))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.title)
                                    .font(.subheadline)
                                    .fontWeight(step.isComplete ? .regular : .medium)
                                    .foregroundStyle(step.isComplete ? .secondary : .primary)
                                    .strikethrough(step.isComplete)
                                Text(step.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if !step.isComplete {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(step.isComplete)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingCheckIn) { CheckInReminderView() }
        .sheet(isPresented: $showingPersonalMessage) { FuneralWishesView() }
        .sheet(isPresented: $showingLegacyContactGuide) {
            AppleLegacyContactGuideView(onDone: {
                legacyContactDone = true
                showingLegacyContactGuide = false
            })
        }
    }
}

// MARK: - Apple Legacy Contact guide

struct AppleLegacyContactGuideView: View {
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Apple's Legacy Contact feature lets a trusted person request access to your iCloud account, photos, and data after you pass away. It works independently of Last Post — so even if notifications fail, they can still access what they need.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("How to set it up") {
                    stepRow(number: "1", text: "Open the Settings app on your iPhone")
                    stepRow(number: "2", text: "Tap your name at the top")
                    stepRow(number: "3", text: "Tap Sign-In & Security")
                    stepRow(number: "4", text: "Tap Legacy Contact")
                    stepRow(number: "5", text: "Add the person you want — they'll receive an access key")
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                }

                Section {
                    Button {
                        onDone()
                    } label: {
                        HStack {
                            Spacer()
                            Text("I've set this up")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .tint(.green)
                }
            }
            .navigationTitle("Apple Legacy Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.purple)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Setup step model

struct SetupStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let isComplete: Bool
    let action: () -> Void
}
