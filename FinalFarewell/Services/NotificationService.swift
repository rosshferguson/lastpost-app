//
//  NotificationService.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
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
    
    func sendDeathNotification(to contact: Contact, about user: User, message: String?) {
        // In production, this would integrate with:
        // - Push notification service (APNs)
        // - Email service (SendGrid, AWS SES, etc.)
        // - SMS service (Twilio, etc.)
        
        print("📧 Sending death notification to \(contact.fullName)")
        print("   Email: \(contact.email)")
        print("   Phone: \(contact.phoneNumber)")
        print("   About: \(user.fullName)")
        if let message = message {
            print("   Message: \(message)")
        }
        
        // Schedule local notification for demo
        scheduleLocalNotification(
            title: "Final Farewell Notification",
            body: "We regret to inform you that \(user.fullName) has passed away.",
            identifier: "death-\(contact.id)"
        )
    }
    
    func sendFuneralDetails(to contact: Contact, notification: DeathNotification) {
        print("📧 Sending funeral details to \(contact.fullName)")
        print("   Date: \(notification.funeralDate?.formatted() ?? "TBD")")
        print("   Location: \(notification.funeralLocation ?? "TBD")")
        
        scheduleLocalNotification(
            title: "Funeral Details",
            body: "Funeral for \(notification.deceasedName): \(notification.funeralLocation ?? "")",
            identifier: "funeral-\(contact.id)"
        )
    }
    
    func sendInvitation(to email: String, link: String) {
        print("📧 Sending invitation to \(email)")
        print("   Link: \(link)")
    }
    
    func scheduleVerificationReminder(for contacts: [Contact]) {
        for contact in contacts where contact.needsVerification {
            scheduleLocalNotification(
                title: "Contact Verification Needed",
                body: "Please verify \(contact.fullName)'s contact details.",
                identifier: "verify-\(contact.id)"
            )
        }
    }
    
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
