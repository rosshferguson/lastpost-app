//
//  NotificationService.swift
//  FinalFarewell
//
//  Added:
//  - scheduleAnnualCheckIn: schedules a yearly UNCalendarNotificationTrigger
//    on the date the user picks. Replaces any existing check-in notification.
//  - cancelAnnualCheckIn: removes the scheduled check-in notification.
//  - scheduleDesignatedPersonReconfirmation: sends a local notification to
//    prompt the owner to ask their designated person to reconfirm.
//  - cancelReconfirmationRequest: removes a pending reconfirmation notification.
//

import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    // MARK: - Death notification

    func sendDeathNotification(to contact: Contact, about user: User, message: String?) {
        // In production, this sends a real email/SMS to the contact regardless
        // of whether they have the app installed — that's the entire point.
        // Local notification below is a stand-in for demo/testing on the
        // owner's own device only; it does NOT reach the contact's device.
        print("📧 Sending death notification to \(contact.fullName)")
        print("   Email: \(contact.email)")
        print("   Phone: \(contact.phoneNumber)")
        print("   About: \(user.fullName)")
        if let message = message { print("   Message: \(message)") }

        scheduleLocalNotification(
            title: "Final Farewell Notification",
            body: "We regret to inform you that \(user.fullName) has passed away.",
            identifier: "death-\(contact.id)"
        )
    }

    func sendFuneralDetails(to contact: Contact, notification: DeathNotification) {
        print("📧 Sending funeral details to \(contact.fullName)")
        scheduleLocalNotification(
            title: "Funeral Details",
            body: "Funeral for \(notification.deceasedName): \(notification.funeralLocation ?? "")",
            identifier: "funeral-\(contact.id)"
        )
    }

    func sendInvitation(to email: String, link: String) {
        print("📧 Sending invitation to \(email) — link: \(link)")
    }

    // MARK: - Verification reminders

    func scheduleVerificationReminder(for contacts: [Contact]) {
        for contact in contacts where contact.needsVerification {
            scheduleLocalNotification(
                title: "Contact verification needed",
                body: "Please verify \(contact.fullName)'s contact details.",
                identifier: "verify-\(contact.id)"
            )
        }
    }

    // MARK: - Annual check-in reminder

    static let annualCheckInIdentifier = "annual-checkin"

    /// Schedules a yearly calendar notification on the given date's day and month.
    /// Call this whenever the user picks or changes their check-in date.
    func scheduleAnnualCheckIn(on date: Date, userName: String) {
        cancelAnnualCheckIn()

        let calendar = Calendar.current
        var components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        components.hour = 9
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Time to review your Final Farewell"
        content.body = "It's been a year, \(userName). Check your contacts, designated person, and personal message are still up to date."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.annualCheckInIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Annual check-in scheduling error: \(error)") }
            else { print("✅ Annual check-in scheduled for \(components.month!)/\(components.day!) each year") }
        }
    }

    func cancelAnnualCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.annualCheckInIdentifier]
        )
    }

    // MARK: - Designated person reconfirmation

    /// Schedules a local notification prompting the owner to chase their designated person.
    /// In production this would send the designated person a deep-link email/SMS directly.
    func scheduleDesignatedPersonReconfirmation(for person: DesignatedPerson, ownerName: String) {
        let identifier = "reconfirm-\(person.id)"

        let content = UNMutableNotificationContent()
        content.title = "Check in with \(person.firstName)"
        content.body = "\(person.fullName) hasn't reconfirmed as your designated person in over a year. Ask them to open Final Farewell and confirm they're still willing."
        content.sound = .default

        // Fire tomorrow at 10am — in production would be a deep-link sent to the designated person
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 10
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Reconfirmation scheduling error: \(error)") }
            else { print("✅ Reconfirmation reminder scheduled for \(person.fullName)") }
        }
    }

    func cancelReconfirmationRequest(for personId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["reconfirm-\(personId)"]
        )
    }

    // MARK: - Private helper

    private func scheduleLocalNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
