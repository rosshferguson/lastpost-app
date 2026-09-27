//
//  CheckInReminderView.swift
//  FinalFarewell
//
//  Two jobs:
//  1. Schedule an annual local reminder to prompt the user to review their settings.
//  2. Let the user complete a check-in — which records proof of life, resets the
//     wellness check timer, and syncs to Supabase so designated persons are not
//     unnecessarily alerted.
//

import SwiftUI

struct CheckInReminderView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("annualCheckInEnabled") private var isEnabled = false
    @State private var checkInDate = defaultDate()
    @State private var reminderSaved = false

    // Check-in completion
    @State private var isAuthenticating = false
    @State private var checkInComplete = false
    @State private var checkInError: String?
    @State private var lastCompletedAt: Date? = storedLastCompletedAt()

    private static func defaultDate() -> Date {
        var comps = Calendar.current.dateComponents([.month, .day], from: Date())
        comps.hour = 9; comps.minute = 0
        comps.year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: comps) ?? Date()
    }

    private static func storedLastCompletedAt() -> Date? {
        let ts = UserDefaults.standard.double(forKey: "lastAnnualCheckInCompletedAt")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Explainer
                Section {
                    Text("Once a year, Last Post will remind you to review your contacts, designated person, and personal message. Completing the check-in also resets your routine check-in timer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Complete check-in now
                Section("Check-in") {
                    if let last = lastCompletedAt {
                        LabeledContent("Last completed") {
                            Text(last.formatted(.dateTime.day().month(.wide).year()))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        performCheckIn()
                    } label: {
                        HStack {
                            Label(
                                checkInComplete ? "Check-in recorded" : "Complete check-in now",
                                systemImage: checkInComplete ? "checkmark.circle.fill" : "checkmark.shield.fill"
                            )
                            .foregroundStyle(checkInComplete ? .green : .primary)
                            Spacer()
                            if isAuthenticating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isAuthenticating || checkInComplete)

                    if let error = checkInError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Text("You'll be asked to authenticate with Face ID or your passcode to confirm you're well.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Annual reminder toggle
                Section("Annual reminder") {
                    Toggle("Remind me annually", isOn: $isEnabled)
                        .onChange(of: isEnabled) { _, enabled in
                            if !enabled { NotificationService.shared.cancelAnnualCheckIn() }
                        }
                }

                if isEnabled {
                    Section("Reminder date") {
                        DatePicker(
                            "Remind me on",
                            selection: $checkInDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)

                        Text("Fires on this date every year.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button("Save reminder") {
                            scheduleReminder()
                        }
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)

                        if reminderSaved {
                            Label("Reminder saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Annual check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadSavedDate() }
        }
    }

    // MARK: - Actions

    private func performCheckIn() {
        guard let user = userViewModel.currentUser else { return }
        isAuthenticating = true
        checkInError = nil

        LivenessCheckService.shared.confirmAlive(
            user: user,
            supabaseService: SupabaseService.shared,
            onSuccess: {
                let now = Date()
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastAnnualCheckInCompletedAt")
                lastCompletedAt = now
                isAuthenticating = false
                checkInComplete = true
                // Reset the success indicator after 3 seconds so it's tappable again next time
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    checkInComplete = false
                }
            },
            onFailure: { error in
                checkInError = error
                isAuthenticating = false
            }
        )
    }

    private func scheduleReminder() {
        guard let user = userViewModel.currentUser else { return }
        NotificationService.shared.scheduleAnnualCheckIn(on: checkInDate, userName: user.firstName)
        user.annualCheckInDate = checkInDate
        reminderSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { reminderSaved = false }
    }

    private func loadSavedDate() {
        if let saved = userViewModel.currentUser?.annualCheckInDate {
            checkInDate = saved
        }
    }
}
