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
    
    @Relationship(inverse: \User.designatedPersons)
    var owner: User?
    
    var fullName: String {
        "\(firstName) \(lastName)"
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
    }
}
