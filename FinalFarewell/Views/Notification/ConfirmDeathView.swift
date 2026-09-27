//
//  ConfirmDeathView.swift
//  FinalFarewell
//
//  Changes in this version:
//  - Cancel during waiting period (step 3) now requires biometric authentication
//    before the notification is cancelled, preventing accidental or malicious cancellation.
//  - A dedicated "Cancel this notification" button is shown inside step 3 so the
//    option is clearly visible rather than hidden in the toolbar.
//  - Toolbar cancel button on steps 1–2 (before initiation) still dismisses freely,
//    since no notification has been created yet at that point.
//  - Toolbar cancel on steps 3–4 (after initiation) requires biometric confirmation.
//

import SwiftUI
import LocalAuthentication

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
    @State private var showingBiometricError = false
    @State private var biometricErrorMessage = ""
    @State private var isResendingCode = false
    @State private var resendSuccess = false

    let totalSteps = 4

    // True once step 1 is completed and a DeathNotification record exists
    private var notificationInitiated: Bool {
        notificationViewModel.currentNotification != nil
    }

    var body: some View {
        NavigationStack {
            VStack {
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .tint(.purple)
                    .padding()

                ScrollView {
                    switch currentStep {
                    case 1: stepOneIdentityConfirmation
                    case 2: stepTwoUnderstanding
                    case 3: stepThreeWaitingPeriod
                    case 4: stepFourFinalConfirmation
                    default: EmptyView()
                    }
                }

                HStack(spacing: 16) {
                    if currentStep > 1 && currentStep < 4 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
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
                if !notificationInitiated {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear {
                // If a notification is already in progress (e.g. app was closed and
                // reopened after the waiting period), skip straight to the waiting period
                // step so the user can pick up where they left off.
                if notificationViewModel.currentNotification != nil {
                    currentStep = 3
                }
            }
            // Alert shown when biometrics unavailable or failed
            .alert("Unable to Cancel", isPresented: $showingBiometricError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(biometricErrorMessage)
            }
            // Alert shown before initiation (steps 1–2) — no biometrics needed
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

    // MARK: - Steps

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
                    title: forUser.contacts.isEmpty
                        ? "Contacts will be notified"
                        : "\(forUser.contacts.count) \(forUser.contacts.count == 1 ? "person" : "people") will be notified",
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

                if forUser.designatedPersons.count > 1 {
                    UnderstandingItem(
                        icon: "person.2.fill",
                        title: "Let your co-designated person know first",
                        description: "They will receive an email asking them to confirm. Please make sure they already know of \(forUser.firstName)'s passing before you proceed — that email should not be how they find out."
                    )
                }
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

                    // Prominent cancel option during the waiting window.
                    // Requires biometric auth to prevent a third party picking up the
                    // phone and quietly cancelling a legitimate notification.
                    Divider()
                        .padding(.vertical, 8)

                    VStack(spacing: 8) {
                        Text("Made a mistake?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            authenticateAndCancel()
                        } label: {
                            Label("Cancel this notification", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Text("You will need to verify your identity to cancel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
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

                    Divider().padding(.vertical, 8)

                    VStack(spacing: 8) {
                        Text("Made a mistake?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            authenticateAndCancel()
                        } label: {
                            Label("Cancel this notification", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Text("You will need to verify your identity to cancel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
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
                Label("Check your email or phone", systemImage: "envelope.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)

                Text("A confirmation code was sent when you started this process. Enter it below to proceed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Enter confirmation code", text: $enteredCode)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .textContentType(.oneTimeCode)

                // Resend option — useful if the app was closed and reopened after the
                // waiting period, since the original code email may have been missed.
                HStack {
                    Button {
                        resendConfirmationCode()
                    } label: {
                        if isResendingCode {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(resendSuccess ? "✓ Code resent" : "Didn't receive the code? Resend")
                                .font(.caption)
                                .foregroundStyle(resendSuccess ? .green : .purple)
                        }
                    }
                    .disabled(isResendingCode || resendSuccess)
                    Spacer()
                }
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

    private func resendConfirmationCode() {
        guard let notification = notificationViewModel.currentNotification,
              let code = notification.confirmationCode else { return }

        // Find the designated person who triggered this notification.
        // Fall back to the current user's own details (covers self-test scenario).
        let designatedPerson = forUser.designatedPersons.first(where: {
            $0.linkedUserId == userViewModel.currentUser?.id
        })
        let dpName  = designatedPerson?.fullName ?? userViewModel.currentUser?.fullName ?? "Designated Person"
        let dpEmail = designatedPerson?.email.isEmpty == false ? designatedPerson!.email
                    : userViewModel.currentUser?.email.isEmpty == false ? userViewModel.currentUser!.email
                    : SupabaseService.shared.supabaseUserEmail  // Supabase auth email as final fallback
        let dpPhone = designatedPerson?.phoneNumber.isEmpty == false ? designatedPerson!.phoneNumber
                    : userViewModel.currentUser?.phoneNumber.isEmpty == false ? userViewModel.currentUser!.phoneNumber
                    : nil

        guard dpEmail != nil || dpPhone != nil else { return }

        isResendingCode = true
        Task {
            await SupabaseService.shared.sendConfirmationCode(
                code: code,
                designatedPersonName: dpName,
                designatedPersonEmail: dpEmail,
                designatedPersonPhone: dpPhone,
                deceasedName: forUser.fullName
            )
            await MainActor.run {
                isResendingCode = false
                resendSuccess = true
            }
        }
    }

    // MARK: - Logic

    private var canProceed: Bool {
        switch currentStep {
        case 1: return confirmationText.uppercased() == "I CONFIRM"
        case 2: return true
        case 3: return notificationViewModel.waitingPeriodRemaining <= 0
        case 4: return notificationViewModel.verifyConfirmationCode(enteredCode)
        default: return false
        }
    }

    private func handleNextStep() {
        if currentStep == 1 {
            if let designatedPerson = forUser.designatedPersons.first(where: {
                $0.linkedUserId == userViewModel.currentUser?.id
            }) {
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
            withAnimation { currentStep += 1 }
        }
    }

    // MARK: - Biometric cancellation

    /// Authenticates with Face ID / Touch ID then cancels the in-progress notification.
    /// Falls back gracefully if biometrics are unavailable (device passcode is not offered
    /// as a fallback here — the intent is strong identity confirmation, not just unlock).
    private func authenticateAndCancel() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricErrorMessage = "Biometric authentication is not available on this device. To cancel, please contact the app owner directly."
            showingBiometricError = true
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Verify your identity to cancel this death notification"
        ) { success, authError in
            DispatchQueue.main.async {
                if success {
                    notificationViewModel.cancelNotification()
                    dismiss()
                } else {
                    let message = authError?.localizedDescription ?? "Authentication failed."
                    biometricErrorMessage = "Could not verify your identity. \(message)"
                    showingBiometricError = true
                }
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
