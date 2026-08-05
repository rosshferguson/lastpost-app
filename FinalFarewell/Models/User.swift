//
//  User.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var dateOfBirth: Date?
    var createdAt: Date
    var lastUpdated: Date
    var isDeceased: Bool
    var deceasedDate: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade)
    var contacts: [Contact] = []
    
    @Relationship(deleteRule: .cascade)
    var designatedPersons: [DesignatedPerson] = []
    
    @Relationship(deleteRule: .cascade)
    var sharedMedia: [SharedMedia] = []
    
    // Lists where this user appears as a contact
    @Relationship(deleteRule: .nullify)
    var appearsOnLists: [Contact] = []
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        phoneNumber: String = "",
        dateOfBirth: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.dateOfBirth = dateOfBirth
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.isDeceased = false
    }
}
