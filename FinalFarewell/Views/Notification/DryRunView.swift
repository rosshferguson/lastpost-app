//
//  DryRunView.swift
//  FinalFarewell
//
//  Fixed handleNext(): falls back to initiateDryRunAsOwner when no designated
//  person record has a matching linkedUserId (single-device testing).
//

import SwiftUI

struct DryRunView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationViewModel: NotificationViewModel
    @EnvironmentObject var userViewModel: UserViewModel

    let forUser: User

    @State private var currentStep = 1
    @State private var confirmationText = ""
    @State private var enteredCode = ""
    @State private var showingSummary = false

    let totalSteps = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Practice mode — nothing will be sent")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))

                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .tint(.blue)
                    .padding()

                ScrollView {
                    switch currentStep {
                    case 1: stepOne
                    case 2: stepTwo
                    case 3: stepThree
                    case 4: stepFour
                    default: EmptyView()
                    }
                }

                HStack(spacing: 16) {
                    if currentStep > 1 {
                        Button("Back") { withAnimation { currentStep -= 1 } }
                            .buttonStyle(.bordered)
                    }

                    Button(currentStep == totalSteps ? "Complete dry run" : "Continue") {
                        handleNext()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!canProceed)
                }
                .padding()
            }
            .navigationTitle("Dry run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Exit") {
                        notificationViewModel.completeDryRun()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSummary) {
                DryRunSummaryView(forUser: forUser) {
                    notificationViewModel.completeDryRun()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Steps

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Step 1: Identity verification")
                .font(.title2).fontWeight(.bold)
            Text("In a real notification, you would confirm your identity as the designated person for \(forUser.fullName).")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("Type 'I CONFIRM' to continue:")
                    .font(.headline)
                TextField("I CONFIRM", text: $confirmationText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
            }
            Spacer()
        }
        .padding()
    }

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Step 2: Understanding the impact")
                .font(.title2).fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                DryRunItem(icon: "bell.badge.fill", color: .blue,
                    title: "\(forUser.contacts.count) contacts would be notified",
                    description: "All contacts on \(forUser.firstName)'s list with an email or phone number would receive a message.")
                DryRunItem(icon: "clock.fill", color: .orange,
                    title: "24-hour waiting period",
                    description: "In the real flow, you'd wait 24 hours before final confirmation. This dry run uses 60 seconds.")
                DryRunItem(icon: "arrow.triangle.2.circlepath", color: .red,
                    title: "This cannot be undone (in real use)",
                    description: "Once confirmed for real, notifications cannot be recalled.")
            }
            Spacer()
        }
        .padding()
    }

    private var stepThree: some View {
        VStack(spacing: 24) {
            Text("Step 3: Waiting period")
                .font(.title2).fontWeight(.bold)

            if notificationViewModel.waitingPeriodRemaining > 0 {
                VStack(spacing: 16) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 60)).foregroundStyle(.blue)
                    Text("Practice waiting period")
                        .font(.headline)
                    Text(formatTime(notificationViewModel.waitingPeriodRemaining))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                    Text("In a real notification this would be 24 hours.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60)).foregroundStyle(.blue)
                    Text("Waiting period complete")
                        .font(.headline)
                    Text("You can now proceed to the final step.")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
    }

    private var stepFour: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Step 4: Confirmation code")
                .font(.title2).fontWeight(.bold)

            Label("In a real notification, you'd receive a code via email or SMS", systemImage: "envelope.fill")
                .font(.subheadline).foregroundStyle(.blue)

            Text("For this dry run, your code is shown below so you can practise entering it.")
                .font(.subheadline).foregroundStyle(.secondary)

            if let code = notificationViewModel.currentNotification?.confirmationCode {
                VStack(spacing: 8) {
                    Text("Your practice code:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(code)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            TextField("Enter confirmation code", text: $enteredCode)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
                .textContentType(.oneTimeCode)

            Spacer()
        }
        .padding()
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

    private func handleNext() {
        if currentStep == 1 {
            // Try to find a linked designated person record; fall back to owner
            if let dp = forUser.designatedPersons.first(where: {
                $0.linkedUserId == userViewModel.currentUser?.id
            }) ?? forUser.designatedPersons.first {
                notificationViewModel.initiateDryRun(forUser: forUser, triggeredBy: dp)
            } else {
                notificationViewModel.initiateDryRunAsOwner(
                    forUser: forUser,
                    currentUser: userViewModel.currentUser
                )
            }
        }

        if currentStep == totalSteps {
            showingSummary = true
        } else {
            withAnimation { currentStep += 1 }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Dry run summary

struct DryRunSummaryView: View {
    let forUser: User
    let onDismiss: () -> Void

    var contactsToNotify: [Contact] {
        forUser.contacts.filter { !$0.email.isEmpty || !$0.phoneNumber.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Dry run complete", systemImage: "checkmark.circle.fill")
                            .font(.headline).foregroundStyle(.green)
                        Text("No real notifications were sent. Here's what would have happened:")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Contacts that would be notified (\(contactsToNotify.count))") {
                    if contactsToNotify.isEmpty {
                        Text("No contacts with an email or phone number — add contacts to see who would be notified.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(contactsToNotify) { contact in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(contact.firstName.prefix(1) + contact.lastName.prefix(1))
                                            .font(.subheadline).foregroundStyle(.blue)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.fullName).font(.subheadline).fontWeight(.medium)
                                    Text(contact.email.isEmpty ? contact.phoneNumber : contact.email)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if contact.wantsFuneralDetails {
                                    Image(systemName: "calendar")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("What happens next in a real notification") {
                    Label("Contacts receive an email or SMS", systemImage: "envelope")
                        .font(.subheadline)
                    Label("24-hour waiting period must elapse", systemImage: "clock")
                        .font(.subheadline)
                    Label("You enter the confirmation code sent to you", systemImage: "key")
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Funeral details can be sent separately", systemImage: "calendar")
                            .font(.subheadline)
                        Text("Once confirmed, a 'Send funeral details' option appears in your designated persons screen. Use it whenever funeral arrangements are known — you can send updates more than once.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }
                }
            }
            .navigationTitle("Dry run summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }
}

// MARK: - Dry run item

struct DryRunItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2).foregroundStyle(color).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
