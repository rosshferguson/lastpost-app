//
//  NotificationViewModel.swift
//  FinalFarewell
//
//  Added initiateDryRunAsOwner: fallback for when no designated person record
//  exists with a matching linkedUserId (e.g. single-device testing).
//

import Combine
import SwiftUI
import SwiftData
import UserNotifications

@MainActor
class NotificationViewModel: ObservableObject {
    @Published var currentNotification: DeathNotification?
    @Published var confirmationStep = 0
    @Published var errorMessage: String?
    @Published var isProcessing = false

    @Published var hasConfirmedIdentity = false
    @Published var hasConfirmedUnderstanding = false
    @Published var hasEnteredCode = false
    @Published var enteredCode = ""
    @Published var waitingPeriodRemaining: TimeInterval = 0

    private var modelContext: ModelContext?
    private var timer: Timer?

    #if DEBUG
    let requiredWaitingPeriod: TimeInterval = 10   // 10 seconds in debug builds for testing
    #else
    let requiredWaitingPeriod: TimeInterval = 24 * 60 * 60   // 24 hours in production
    #endif

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        restoreInProgressNotification()
    }

    private func restoreInProgressNotification() {
        guard let context = modelContext else { return }

        // In-progress notifications take priority
        let inProgressDescriptor = FetchDescriptor<DeathNotification>(
            predicate: #Predicate { !$0.isConfirmed && !$0.isDryRun },
            sortBy: [SortDescriptor(\.triggeredAt, order: .reverse)]
        )

        do {
            let inProgressNotifications = try context.fetch(inProgressDescriptor)
            if let inProgress = inProgressNotifications.first {
                currentNotification = inProgress
                confirmationStep = inProgress.confirmationStep

                if let waitingEnd = inProgress.waitingPeriodEnds, Date() < waitingEnd {
                    waitingPeriodRemaining = waitingEnd.timeIntervalSince(Date())
                    startWaitingPeriodTimer()
                } else {
                    waitingPeriodRemaining = 0
                }
                return
            }
        } catch {
            errorMessage = "Failed to restore notification state: \(error.localizedDescription)"
            return
        }

        // Also restore the most recent confirmed notification so post-confirmation
        // actions (like sending funeral details) remain accessible after app restart.
        let confirmedDescriptor = FetchDescriptor<DeathNotification>(
            predicate: #Predicate { $0.isConfirmed && !$0.isDryRun },
            sortBy: [SortDescriptor(\.confirmedAt, order: .reverse)]
        )
        if let confirmed = (try? context.fetch(confirmedDescriptor))?.first {
            currentNotification = confirmed
            confirmationStep = confirmed.confirmationStep
        }
    }

    // MARK: - Multi-designated-person awareness

    func fetchExistingNotification(forUserId userId: UUID) -> DeathNotification? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<DeathNotification>(
            predicate: #Predicate { $0.deceasedUserId == userId && !$0.isDryRun },
            sortBy: [SortDescriptor(\.triggeredAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Initiation

    func initiateDeathNotification(forUser user: User, triggeredBy designatedPerson: DesignatedPerson) {
        guard let context = modelContext else { return }
        if currentNotification != nil { return }

        let notification = DeathNotification(
            deceasedUserId: user.id,
            deceasedName: user.fullName,
            triggeredByUserId: designatedPerson.linkedUserId ?? UUID(),
            triggeredByName: designatedPerson.fullName
        )

        let code = generateConfirmationCode()
        notification.confirmationCode = code
        notification.waitingPeriodEnds = Date().addingTimeInterval(requiredWaitingPeriod)
        notification.appendAuditEntry(AuditEntry(
            timestamp: Date(),
            contactName: designatedPerson.fullName,
            contactEmail: designatedPerson.email,
            eventType: .notificationTriggered,
            note: "Triggered by \(designatedPerson.fullName)"
        ))

        // Send the confirmation code to the designated person via email/SMS.
        // Use the same fallback chain as the resend path in ConfirmDeathView so that
        // a missing email on the local DesignatedPerson model doesn't silently drop the send.
        let dpName  = designatedPerson.fullName
        let decName = user.fullName
        let dpEmail: String? = {
            if !designatedPerson.email.isEmpty { return designatedPerson.email }
            if let supabaseEmail = SupabaseService.shared.supabaseUserEmail,
               !supabaseEmail.isEmpty { return supabaseEmail }
            return nil
        }()
        let dpPhone: String? = designatedPerson.phoneNumber.isEmpty ? nil : designatedPerson.phoneNumber
        Task {
            await SupabaseService.shared.sendConfirmationCode(
                code: code,
                designatedPersonName: dpName,
                designatedPersonEmail: dpEmail,
                designatedPersonPhone: dpPhone,
                deceasedName: decName
            )
        }
        notification.appendAuditEntry(AuditEntry(
            timestamp: Date(),
            contactName: "",
            contactEmail: "",
            eventType: .waitingPeriodStarted,
            note: "\(Int(requiredWaitingPeriod / 3600) > 0 ? "24-hour" : "10-second") waiting period begun"
        ))

        context.insert(notification)

        do {
            try context.save()
            currentNotification = notification
            confirmationStep = 1
            startWaitingPeriodTimer()
            // Schedule a local push notification so the designated person is prompted
            // to open the app and complete the final confirmation when the period ends.
            if let waitingEnd = notification.waitingPeriodEnds {
                scheduleWaitingPeriodEndNotification(at: waitingEnd, deceasedName: user.fullName)
            }
        } catch {
            errorMessage = "Failed to initiate notification: \(error.localizedDescription)"
        }
    }

    // MARK: - Dry run

    func initiateDryRun(forUser user: User, triggeredBy designatedPerson: DesignatedPerson) {
        guard let context = modelContext else { return }

        let notification = DeathNotification(
            deceasedUserId: user.id,
            deceasedName: user.fullName,
            triggeredByUserId: designatedPerson.linkedUserId ?? UUID(),
            triggeredByName: designatedPerson.fullName,
            isDryRun: true
        )

        notification.confirmationCode = generateConfirmationCode()
        notification.waitingPeriodEnds = Date().addingTimeInterval(60)

        context.insert(notification)

        do {
            try context.save()
            currentNotification = notification
            confirmationStep = 1
            startWaitingPeriodTimer()
        } catch {
            errorMessage = "Failed to start dry run: \(error.localizedDescription)"
        }
    }

    /// Fallback for single-device testing: starts a dry run when no designated
    /// person record with a matching linkedUserId exists.
    func initiateDryRunAsOwner(forUser user: User, currentUser: User?) {
        guard let context = modelContext else { return }

        let notification = DeathNotification(
            deceasedUserId: user.id,
            deceasedName: user.fullName,
            triggeredByUserId: currentUser?.id ?? UUID(),
            triggeredByName: currentUser?.fullName ?? "Practice",
            isDryRun: true
        )

        notification.confirmationCode = generateConfirmationCode()
        notification.waitingPeriodEnds = Date().addingTimeInterval(60)

        context.insert(notification)

        do {
            try context.save()
            currentNotification = notification
            confirmationStep = 1
            startWaitingPeriodTimer()
        } catch {
            errorMessage = "Failed to start dry run: \(error.localizedDescription)"
        }
    }

    func completeDryRun() {
        guard let context = modelContext, let notification = currentNotification,
              notification.isDryRun else { return }

        notification.appendAuditEntry(AuditEntry(
            timestamp: Date(),
            contactName: "",
            contactEmail: "",
            eventType: .dryRunCompleted,
            note: "Dry run completed — no notifications were sent"
        ))

        context.delete(notification)
        saveContext()
        currentNotification = nil
        confirmationStep = 0
        timer?.invalidate()
        waitingPeriodRemaining = 0
    }

    // MARK: - Steps

    func proceedToNextStep() {
        confirmationStep += 1
        currentNotification?.confirmationStep = confirmationStep
        saveContext()
    }

    func verifyConfirmationCode(_ code: String) -> Bool {
        guard let notification = currentNotification else { return false }
        return notification.confirmationCode == code.uppercased().trimmingCharacters(in: .whitespaces)
    }

    func finalConfirmation() {
        guard let notification = currentNotification else { return }

        if let waitingEnd = notification.waitingPeriodEnds, Date() < waitingEnd {
            errorMessage = "Please wait for the confirmation period to end"
            return
        }

        isProcessing = true
        notification.isConfirmed = true
        notification.confirmedAt = Date()

        notification.appendAuditEntry(AuditEntry(
            timestamp: Date(),
            contactName: "",
            contactEmail: "",
            eventType: .waitingPeriodCompleted
        ))
        notification.appendAuditEntry(AuditEntry(
            timestamp: Date(),
            contactName: "",
            contactEmail: "",
            eventType: .notificationConfirmed,
            note: "All contacts notified"
        ))

        saveContext()
        sendDeathNotifications(for: notification)
        dispatchDeathNotificationsToServer(for: notification)
        timer?.invalidate()
        isProcessing = false
    }

    /// Sends real email + SMS notifications to all contacts via the Supabase edge function.
    /// Called after `finalConfirmation()` only on non-dry-run notifications.
    /// On the owner's device, contacts come from local SwiftData.
    /// On the designated person's device the shadow User has no local contacts, so we
    /// fall back to fetching them from Supabase's user_contacts table.
    private func dispatchDeathNotificationsToServer(for notification: DeathNotification) {
        guard !notification.isDryRun else { return }
        guard let context = modelContext else { return }
        let userId = notification.deceasedUserId
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
        guard let deceasedUser = (try? context.fetch(descriptor))?.first else { return }
        let contacts = deceasedUser.contacts.filter { !$0.email.isEmpty || !$0.phoneNumber.isEmpty }
        let deceasedName = deceasedUser.fullName
        let dpEmail      = SupabaseService.shared.supabaseUserEmail
        // Resolve the deceased's Supabase UUID (shadow users already use it as their local ID).
        let ownerSupabaseId = SupabaseService.shared.supabaseId(forLocalUserId: userId) ?? userId
        Task {
            if !contacts.isEmpty {
                await SupabaseService.shared.sendDeathNotificationsToContacts(
                    deceasedName: deceasedName,
                    contacts: contacts,
                    designatedPersonEmail: dpEmail,
                    ownerSupabaseId: ownerSupabaseId
                )
            } else {
                // Designated person's device: pass owner_id so the edge function
                // fetches contacts server-side using the service role key (bypasses RLS).
                await SupabaseService.shared.sendDeathNotificationsToContacts(
                    deceasedName: deceasedName,
                    contacts: [],
                    designatedPersonEmail: dpEmail,
                    ownerSupabaseId: ownerSupabaseId
                )
            }
        }
    }

    func addFuneralDetails(date: Date, location: String, details: String) {
        guard let notification = currentNotification else { return }
        notification.funeralDate = date
        notification.funeralLocation = location
        notification.funeralDetails = details
        notification.funeralDetailsAddedAt = Date()
        notification.appendAuditEntry(AuditEntry(
            timestamp: Date(),
            contactName: "",
            contactEmail: "",
            eventType: .funeralDetailsSent,
            note: location.isEmpty ? nil : "Location: \(location)"
        ))
        saveContext()
        sendFuneralNotifications(for: notification)
    }

    func cancelNotification() {
        guard let context = modelContext, let notification = currentNotification else { return }
        if !notification.isConfirmed {
            notification.appendAuditEntry(AuditEntry(
                timestamp: Date(),
                contactName: "",
                contactEmail: "",
                eventType: .notificationCancelled,
                note: "Cancelled during waiting period"
            ))
            context.delete(notification)
            saveContext()
            currentNotification = nil
            confirmationStep = 0
            timer?.invalidate()
            waitingPeriodRemaining = 0
            // Cancel the pending "waiting period ended" local notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["waiting-period-ended"])
        }
    }

    // MARK: - Sending

    private func sendDeathNotifications(for notification: DeathNotification) {
        guard let context = modelContext else { return }
        let userId = notification.deceasedUserId
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })

        do {
            let users = try context.fetch(descriptor)
            guard let deceasedUser = users.first else { return }

            for contact in deceasedUser.contacts {
                let hasContactMethod = !contact.email.isEmpty || !contact.phoneNumber.isEmpty
                guard hasContactMethod else {
                    notification.appendAuditEntry(AuditEntry(
                        timestamp: Date(),
                        contactId: contact.id,
                        contactName: contact.fullName,
                        contactEmail: contact.email,
                        eventType: .contactNotified,
                        note: "⚠️ Not notified — no email or phone number on file"
                    ))
                    continue
                }

                contact.hasBeenNotified = true
                contact.notifiedAt = Date()

                if !notification.isDryRun {
                    NotificationService.shared.sendDeathNotification(
                        to: contact, about: deceasedUser, message: contact.personalMessage
                    )
                }

                let channel = contact.invitationAccepted ? "in-app + email/SMS" : "email/SMS only (no app)"
                notification.appendAuditEntry(AuditEntry(
                    timestamp: Date(),
                    contactId: contact.id,
                    contactName: contact.fullName,
                    contactEmail: contact.email,
                    eventType: .contactNotified,
                    note: notification.isDryRun ? "Dry run — not actually sent" : "Notified via \(channel)"
                ))
            }

            if !notification.isDryRun {
                deceasedUser.isDeceased = true
                deceasedUser.deceasedDate = Date()
            }
            try context.save()
        } catch {
            errorMessage = "Failed to send notifications: \(error.localizedDescription)"
        }
    }

    private func sendFuneralNotifications(for notification: DeathNotification) {
        guard let context = modelContext else { return }
        let userId = notification.deceasedUserId
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })

        do {
            let users = try context.fetch(descriptor)
            guard let deceasedUser = users.first else { return }
            for contact in deceasedUser.contacts where contact.wantsFuneralDetails && contact.hasBeenNotified {
                if !notification.isDryRun {
                    NotificationService.shared.sendFuneralDetails(to: contact, notification: notification)
                }
                notification.appendAuditEntry(AuditEntry(
                    timestamp: Date(),
                    contactId: contact.id,
                    contactName: contact.fullName,
                    contactEmail: contact.email,
                    eventType: .funeralDetailsSent,
                    note: notification.isDryRun ? "Dry run — not actually sent" : nil
                ))
            }
            try context.save()
        } catch {
            errorMessage = "Failed to send funeral notifications: \(error.localizedDescription)"
        }
    }

    // MARK: - Local push: waiting period ended

    /// Schedules a local push notification to fire when the waiting period ends,
    /// so the designated person knows to open the app and complete the final confirmation.
    private func scheduleWaitingPeriodEndNotification(at date: Date, deceasedName: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Action required — Last Post"
            content.body = "The 24-hour waiting period for \(deceasedName)'s notification has ended. Open the app to complete the final confirmation and notify contacts."
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: "waiting-period-ended",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error { print("[scheduleWaitingPeriodEnd] \(error)") }
            }
        }
    }

    // MARK: - Timer

    private func generateConfirmationCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    private func startWaitingPeriodTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.updateWaitingPeriod() }
        }
    }

    private func updateWaitingPeriod() {
        guard let notification = currentNotification,
              let waitingEnd = notification.waitingPeriodEnds else {
            waitingPeriodRemaining = 0
            return
        }
        waitingPeriodRemaining = max(0, waitingEnd.timeIntervalSince(Date()))
        if waitingPeriodRemaining == 0 { timer?.invalidate() }
    }

    private func saveContext() {
        guard let context = modelContext else { return }
        do { try context.save() }
        catch { errorMessage = "Failed to save: \(error.localizedDescription)" }
    }
}
