//
//  Contact.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
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
    
    // Owner of this contact entry
    @Relationship(inverse: \User.contacts)
    var owner: User?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var needsVerification: Bool {
        guard let lastVerified = lastVerified else { return true }
        let sixMonths: TimeInterval = 180 * 24 * 60 * 60
        return Date().timeIntervalSince(lastVerified) > sixMonths
    }
    
    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        phoneNumber: String = "",
        relationship: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.notes = notes
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.invitationSent = false
        self.invitationAccepted = false
        self.hasApp = false
        self.wantsFuneralDetails = true
        self.hasBeenNotified = false
    }
}
