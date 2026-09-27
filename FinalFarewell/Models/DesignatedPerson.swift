//
//  DesignatedPerson.swift
//  FinalFarewell
//
//  Added canViewArrangements: per-person toggle controlling whether the
//  designated person can view funeral wishes before death is confirmed.
//

import Foundation
import SwiftData

@Model
final class DesignatedPerson {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var relationship: String
    var isPrimary: Bool
    var createdAt: Date
    var lastUpdated: Date

    // Status
    var invitationSent: Bool
    var invitationAccepted: Bool
    var hasApp: Bool
    var linkedUserId: UUID?

    // Permissions
    var canAccessPhotos: Bool
    var canTriggerNotification: Bool
    var canViewArrangements: Bool

    // Reconfirmation tracking
    var lastReconfirmedAt: Date?
    var reconfirmationRequestedAt: Date?

    @Relationship(inverse: \User.designatedPersons)
    var owner: User?

    var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var needsReconfirmation: Bool {
        guard invitationAccepted else { return false }
        let twelveMonths: TimeInterval = 365 * 24 * 60 * 60
        let referenceDate = lastReconfirmedAt ?? createdAt
        return Date().timeIntervalSince(referenceDate) > twelveMonths
    }

    var reconfirmationStatus: String {
        if !invitationAccepted { return "Pending" }
        if needsReconfirmation { return "Reconfirmation needed" }
        if let date = lastReconfirmedAt {
            return "Confirmed \(date.formatted(.relative(presentation: .named)))"
        }
        return "Accepted"
    }

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        phoneNumber: String = "",
        relationship: String = "",
        isPrimary: Bool = false
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.isPrimary = isPrimary
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.invitationSent = false
        self.invitationAccepted = false
        self.hasApp = false
        self.canAccessPhotos = false
        self.canTriggerNotification = true
        self.canViewArrangements = true
        self.lastReconfirmedAt = nil
        self.reconfirmationRequestedAt = nil
    }
}
