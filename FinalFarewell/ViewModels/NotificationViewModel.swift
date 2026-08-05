import Foundation
import SwiftUI
import SwiftData

@MainActor
class NotificationViewModel: ObservableObject {
    @Published var currentNotification: DeathNotification?
    @Published var confirmationStep = 0
    @Published var errorMessage: String?
    @Published var isProcessing = false
    
    // Confirmation steps
    @Published var hasConfirmedIdentity = false
    @Published var hasConfirmedUnderstanding = false
    @Published var hasEnteredCode = false
    @Published var enteredCode = ""
    @Published var waitingPeriodRemaining: TimeInterval = 0
    
    private var modelContext: ModelContext?
    private var timer: Timer?
    
    let requiredWaitingPeriod: TimeInterval = 24 * 60 * 60 // 24 hours
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func initiateDeathNotification(
        forUser user: User,
        triggeredBy designatedPerson: DesignatedPerson
    ) {
        guard let context = modelContext else { return }
        
        let notification = DeathNotification(
            deceasedUserId: user.id,
            deceasedName: user.fullName,
            triggeredByUserId: designatedPerson.linkedUserId ?? UUID(),
            triggeredByName: designatedPerson.fullName
        )
        
        // Generate confirmation code
        notification.confirmationCode = generateConfirmationCode()
        
        // Set waiting period
        notification.waitingPeriodEnds = Date().addingTimeInterval(requiredWaitingPeriod)
        
        context.insert(notification)
        
        do {
            try context.save()
            currentNotification = notification
            confirmationStep = 1
            startWaitingPeriodTimer()
        } catch {
            errorMessage = "Failed to initiate notification: \(error.localizedDescription)"
        }
    }
    
    func proceedToNextStep() {
        confirmationStep += 1
        currentNotification?.confirmationStep = confirmationStep
        saveContext()
    }
    
    func verifyConfirmationCode(_ code: String) -> Bool {
        guard let notification = currentNotification else { return false }
        return notification.confirmationCode == code
    }
    
    func finalConfirmation() {
        guard let notification = currentNotification else { return }
        
        // Verify waiting period has passed
        if let waitingEnd = notification.waitingPeriodEnds, Date() < waitingEnd {
            errorMessage = "Please wait for the confirmation period to end"
            return
        }
        
        isProcessing = true
        
        notification.isConfirmed = true
        notification.confirmedAt = Date()
        
        saveContext()
        
        // Trigger notifications to all contacts
        sendDeathNotifications(for: notification)
        
        isProcessing = false
    }
    
    func addFuneralDetails(
        date: Date,
        location: String,
        details: String
    ) {
        guard let notification = currentNotification else { return }
        
        notification.funeralDate = date
        notification.funeralLocation = location
        notification.funeralDetails = details
        notification.funeralDetailsAddedAt = Date()
        
        saveContext()
        
        // Send funeral details to those who opted in
        sendFuneralNotifications(for: notification)
    }
    
    func cancelNotification() {
        guard let context = modelContext, let notification = currentNotification else { return }
        
        if !notification.isConfirmed {
            context.delete(notification)
            saveContext()
            currentNotification = nil
            confirmationStep = 0
            timer?.invalidate()
        }
    }
    
    private func sendDeathNotifications(for notification: DeathNotification) {
        guard let context = modelContext else { return }
        
        // Fetch the deceased user's contacts
        let userId = notification.deceasedUserId
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == userId }
        )
        
        do {
            let users = try context.fetch(descriptor)
            guard let deceasedUser = users.first else { return }
            
            for contact in deceasedUser.contacts where contact.invitationAccepted {
                // Mark as notified
                contact.hasBeenNotified = true
                contact.notifiedAt = Date()
                
                // In production, send actual notification via push/email/SMS
                NotificationService.shared.sendDeathNotification(
                    to: contact,
                    about: deceasedUser,
                    message: notification.personalMessage
                )
            }
            
            // Mark user as deceased
            deceasedUser.isDeceased = true
            deceasedUser.deceasedDate = Date()
            
            // Remove deceased user from others' notification lists
            removeFromOthersLists(user: deceasedUser)
            
            try context.save()
        } catch {
            errorMessage = "Failed to send notifications: \(error.localizedDescription)"
        }
    }
    
    private func sendFuneralNotifications(for notification: DeathNotification) {
        guard let context = modelContext else { return }
        
        let userId = notification.deceasedUserId
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == userId }
        )
        
        do {
            let users = try context.fetch(descriptor)
            guard let deceasedUser = users.first else { return }
            
            for contact in deceasedUser.contacts where contact.wantsFuneralDetails && contact.hasBeenNotified {
                NotificationService.shared.sendFuneralDetails(
                    to: contact,
                    notification: notification
                )
            }
            
            try context.save()
        } catch {
            errorMessage = "Failed to send funeral notifications: \(error.localizedDescription)"
        }
    }
    
    private func removeFromOthersLists(user: User) {
        // In production, this would update linked records across users
        // For now, handled via the linkedUserId relationship
    }
    
    private func generateConfirmationCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    private func startWaitingPeriodTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateWaitingPeriod()
            }
        }
    }
    
    private func updateWaitingPeriod() {
        guard let notification = currentNotification,
              let waitingEnd = notification.waitingPeriodEnds else {
            waitingPeriodRemaining = 0
            return
        }
        
        waitingPeriodRemaining = max(0, waitingEnd.timeIntervalSince(Date()))
    }
    
    private func saveContext() {
        guard let context = modelContext else { return }
        
        do {
            try context.save()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
