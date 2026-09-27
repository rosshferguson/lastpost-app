//
//  DeathNotification.swift
//  FinalFarewell
//
//  Added:
//  - notifiedContacts: JSON-encoded audit log of who was notified and when
//  - isDryRun: flag for test/practice runs — no real notifications sent
//  - AuditEntry: Codable struct recording each notification event
//

import Foundation
import SwiftData

@Model
final class DeathNotification {
    @Attribute(.unique) var id: UUID
    var deceasedUserId: UUID
    var deceasedName: String
    var triggeredByUserId: UUID
    var triggeredByName: String
    var triggeredAt: Date
    var confirmedAt: Date?
    var isConfirmed: Bool

    // Multi-step confirmation
    var confirmationStep: Int
    var confirmationCode: String?
    var waitingPeriodEnds: Date?

    // Funeral details
    var funeralDate: Date?
    var funeralLocation: String?
    var funeralDetails: String?
    var funeralDetailsAddedAt: Date?

    // Message
    var personalMessage: String?

    // Dry run — no real notifications sent, record deleted after review
    var isDryRun: Bool

    // Audit log stored as JSON-encoded [AuditEntry]
    var auditLogData: Data?

    var auditLog: [AuditEntry] {
        get {
            guard let data = auditLogData,
                  let decoded = try? JSONDecoder().decode([AuditEntry].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            auditLogData = try? JSONEncoder().encode(newValue)
        }
    }

    func appendAuditEntry(_ entry: AuditEntry) {
        var log = auditLog
        log.append(entry)
        auditLog = log
    }

    init(
        id: UUID = UUID(),
        deceasedUserId: UUID,
        deceasedName: String,
        triggeredByUserId: UUID,
        triggeredByName: String,
        isDryRun: Bool = false
    ) {
        self.id = id
        self.deceasedUserId = deceasedUserId
        self.deceasedName = deceasedName
        self.triggeredByUserId = triggeredByUserId
        self.triggeredByName = triggeredByName
        self.triggeredAt = Date()
        self.isConfirmed = false
        self.confirmationStep = 0
        self.isDryRun = isDryRun
    }
}

// MARK: - Audit entry

struct AuditEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date
    var contactId: UUID?
    var contactName: String
    var contactEmail: String
    var eventType: AuditEventType
    var note: String?

    enum AuditEventType: String, Codable {
        case notificationTriggered = "Notification triggered"
        case waitingPeriodStarted = "Waiting period started"
        case waitingPeriodCompleted = "Waiting period completed"
        case notificationConfirmed = "Notification confirmed"
        case contactNotified = "Contact notified"
        case funeralDetailsSent = "Funeral details sent"
        case notificationCancelled = "Notification cancelled"
        case dryRunCompleted = "Dry run completed"
    }
}
