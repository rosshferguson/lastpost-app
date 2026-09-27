//
//  Contact.swift
//  FinalFarewell
//
//  Added:
//  - group: optional string for contact grouping (Family, Friends, Work, etc.)
//

import Foundation
import SwiftData

@Model
final class Contact {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var relationship: String
    var notes: String
    var createdAt: Date
    var lastUpdated: Date
    var lastVerified: Date?

    // Consent and status
    var invitationSent: Bool
    var invitationAccepted: Bool
    var hasApp: Bool
    var linkedUserId: UUID?

    // Notification preferences
    var wantsFuneralDetails: Bool
    var hasBeenNotified: Bool
    var notifiedAt: Date?

    // Per-contact personal content
    var personalMessage: String?
    var videoMessageData: Data?
    var videoMessageRecordedAt: Date?

    // Grouping
    var group: String?

    @Relationship(inverse: \User.contacts)
    var owner: User?

    var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var needsVerification: Bool {
        guard let lastVerified else { return true }
        let sixMonths: TimeInterval = 180 * 24 * 60 * 60
        return Date().timeIntervalSince(lastVerified) > sixMonths
    }

    var hasPersonalContent: Bool {
        (personalMessage != nil && !(personalMessage?.isEmpty ?? true)) ||
        videoMessageData != nil
    }

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        phoneNumber: String = "",
        relationship: String = "",
        notes: String = "",
        group: String? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.notes = notes
        self.group = group
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.invitationSent = false
        self.invitationAccepted = false
        self.hasApp = false
        self.wantsFuneralDetails = true
        self.hasBeenNotified = false
    }
}
