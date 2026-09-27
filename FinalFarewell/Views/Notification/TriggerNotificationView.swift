//
//  TriggerNotificationView.swift
//  FinalFarewell
//
//  Added:
//  - On appear, checks if another designated person has already started a
//    notification for this user. If so, shows the in-progress state instead
//    of allowing a duplicate to be created.
//  - Dry run button added alongside the main trigger button.
//

import SwiftUI

struct TriggerNotificationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationViewModel: NotificationViewModel
    @EnvironmentObject var userViewModel: UserViewModel

    let forUser: User

    @State private var showingConfirmationFlow = false
    @State private var showingDryRun = false
    @State private var showingAuthError = false
    @State private var isAuthenticating = false
    @State private var existingNotification: DeathNotification?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)

                    Text("Notification management")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("For \(forUser.fullName)")
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Show in-progress banner if another designated person already started
                if let existing = existingNotification {
                    inProgressBanner(existing)
                } else {
                    warningBanner
                    statsRow
                    actionButtons
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Initiate notification")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingConfirmationFlow, onDismiss: checkForExistingNotification) {
            ConfirmDeathView(forUser: forUser)
        }
        .sheet(isPresented: $showingDryRun) {
            DryRunView(forUser: forUser)
        }
        .alert("Authentication required", isPresented: $showingAuthError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You must authenticate to proceed with this action.")
        }
        .onAppear { checkForExistingNotification() }
    }

    // MARK: - In-progress banner

    private func inProgressBanner(_ notification: DeathNotification) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notification already in progress")
                        .font(.headline)
                    Text("Started by \(notification.triggeredByName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if notification.isConfirmed {
                Label("Confirmed — contacts have been notified", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else if let waitingEnd = notification.waitingPeriodEnds {
                let waitingExpired = Date() >= waitingEnd

                if waitingExpired {
                    // Waiting period is over — final confirmation is needed now
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Waiting period complete — action needed", systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)

                        Text("The waiting period ended \(waitingEnd.formatted(date: .abbreviated, time: .shortened)). Complete the final confirmation to notify contacts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            // Open the confirmation flow WITHOUT cancelling — the existing
                            // notification and its code are still valid.
                            showingConfirmationFlow = true
                        } label: {
                            Text("Complete final confirmation")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)

                        Button {
                            Task { await takeOverNotification() }
                        } label: {
                            Text("Start over (sends a new code)")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Waiting period ends:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(waitingEnd.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text("Another designated person has already begun this process. You do not need to take any action unless they ask you to take over.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await takeOverNotification() }
                    } label: {
                        Text("Take over this notification")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Warning banner

    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Important", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(forUser.contacts.isEmpty
                ? "This action will notify \(forUser.firstName)'s contacts that they have passed away. This process includes multiple verification steps and a 24-hour waiting period."
                : "This action will notify \(forUser.contacts.filter { $0.invitationAccepted }.count) people that \(forUser.firstName) has passed away. This process includes multiple verification steps and a 24-hour waiting period."
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack {
            StatItem(title: "Contacts",  value: "\(forUser.contacts.count)")
            StatItem(title: "Confirmed", value: "\(forUser.contacts.filter { $0.invitationAccepted }.count)")
        }
        .padding(.horizontal)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await beginNotificationProcess() }
            } label: {
                if isAuthenticating {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else {
                    Text("Begin notification process")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.purple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(isAuthenticating)

            Button {
                showingDryRun = true
            } label: {
                Label("Practice dry run", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding(.horizontal)
    }

    // MARK: - Logic

    private func checkForExistingNotification() {
        // Check the in-memory notification first (covers mid-flow cancellations
        // before the record is fully persisted) then fall back to SwiftData.
        if let inMemory = notificationViewModel.currentNotification,
           inMemory.deceasedUserId == forUser.id,
           !inMemory.isDryRun {
            existingNotification = inMemory
        } else {
            existingNotification = notificationViewModel.fetchExistingNotification(forUserId: forUser.id)
        }
    }

    private func takeOverNotification() async {
        isAuthenticating = true
        let authenticated = await BiometricAuthHelper.authenticate(
            reason: "Verify your identity to take over this notification"
        )
        isAuthenticating = false

        guard authenticated else {
            showingAuthError = true
            return
        }

        // Cancel the existing in-progress notification so initiateDeathNotification
        // isn't blocked by the guard, then open the confirmation flow fresh.
        notificationViewModel.cancelNotification()
        existingNotification = nil
        showingConfirmationFlow = true
    }

    private func beginNotificationProcess() async {
        isAuthenticating = true
        let authenticated = await BiometricAuthHelper.authenticate(
            reason: "Verify your identity before notifying contacts"
        )
        isAuthenticating = false

        if authenticated {
            showingConfirmationFlow = true
        } else {
            showingAuthError = true
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
    }}
