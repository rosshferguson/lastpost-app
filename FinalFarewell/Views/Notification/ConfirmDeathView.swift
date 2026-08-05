//
//  ConfirmDeathView.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import SwiftUI

struct ConfirmDeathView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationViewModel: NotificationViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    
    let forUser: User
    
    @State private var currentStep = 1
    @State private var confirmationText = ""
    @State private var enteredCode = ""
    @State private var personalMessage = ""
    @State private var showingCancelAlert = false
    
    let totalSteps = 4
    
    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .tint(.purple)
                    .padding()
                
                // Step content
                ScrollView {
                    switch currentStep {
                    case 1:
                        stepOneIdentityConfirmation
                    case 2:
                        stepTwoUnderstanding
                    case 3:
                        stepThreeWaitingPeriod
                    case 4:
                        stepFourFinalConfirmation
                    default:
                        EmptyView()
                    }
                }
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 1 && currentStep < 4 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(currentStep == totalSteps ? "Confirm & Notify" : "Continue") {
                        handleNextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!canProceed)
                }
                .padding()
            }
            .navigationTitle("Confirm Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCancelAlert = true
                    }
                }
            }
            .alert("Cancel Notification?", isPresented: $showingCancelAlert) {
                Button("Continue Process", role: .cancel) { }
                Button("Cancel", role: .destructive) {
                    notificationViewModel.cancelNotification()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to cancel the notification process?")
            }
        }
    }
    
    private var stepOneIdentityConfirmation: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Step 1: Identity Verification")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Please confirm your identity as the designated person for \(forUser.fullName).")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Type 'I CONFIRM' to proceed:")
                    .font(.headline)
                
                TextField("I CONFIRM", text: $confirmationText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var stepTwoUnderstanding: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Step 2: Understanding the Impact")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                UnderstandingItem(
                    icon: "bell.badge.fill",
                    title: "\(forUser.contacts.count) people will be notified",
                    description: "All confirmed contacts on \(forUser.firstName)'s list will receive a notification."
                )
                
                UnderstandingItem(
                    icon: "arrow.triangle.2.circlepath",
                    title: "This cannot be undone",
                    description: "Once confirmed, notifications will be sent and cannot be recalled."
                )
                
                UnderstandingItem(
                    icon: "clock.fill",
                    title: "24-hour waiting period",
                    description: "A waiting period will begin to ensure this is not triggered in error."
                )
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var stepThreeWaitingPeriod: some View {
        VStack(spacing: 24) {
            Text("Step 3: Waiting Period")
                .font(.title2)
                .fontWeight(.bold)
            
            if notificationViewModel.waitingPeriodRemaining > 0 {
                VStack(spacing: 16) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    
                    Text("Please wait")
                        .font(.headline)
                    
                    Text(formatTimeRemaining(notificationViewModel.waitingPeriodRemaining))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                    
                    Text("This waiting period helps prevent accidental notifications.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    
                    Text("Waiting period complete")
                        .font(.headline)
                    
                    Text("You may now proceed to final confirmation.")
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var stepFourFinalConfirmation: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Step 4: Final Confirmation")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter the confirmation code:")
                    .font(.headline)
                
                Text("Code: \(notificationViewModel.currentNotification?.confirmationCode ?? "------")")
                    .font(.system(.title2, design: .monospaced))
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                TextField("Enter code", text: $enteredCode)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a personal message (optional):")
                    .font(.headline)
                
                TextField("Your message...", text: $personalMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return confirmationText.uppercased() == "I CONFIRM"
        case 2:
            return true
        case 3:
            return notificationViewModel.waitingPeriodRemaining <= 0
        case 4:
            return notificationViewModel.verifyConfirmationCode(enteredCode)
        default:
            return false
        }
    }
    
    private func handleNextStep() {
        if currentStep == 1 {
            // Initialize the notification
            if let designatedPerson = forUser.designatedPersons.first(where: { $0.linkedUserId == userViewModel.currentUser?.id }) {
                notificationViewModel.initiateDeathNotification(
                    forUser: forUser,
                    triggeredBy: designatedPerson
                )
            }
        }
        
        if currentStep == totalSteps {
            notificationViewModel.currentNotification?.personalMessage = personalMessage
            notificationViewModel.finalConfirmation()
            dismiss()
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

struct UnderstandingItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
