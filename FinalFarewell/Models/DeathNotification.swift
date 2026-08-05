//
//  DeathNotification.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
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
    
    init(
        id: UUID = UUID(),
        deceasedUserId: UUID,
        deceasedName: String,
        triggeredByUserId: UUID,
        triggeredByName: String
    ) {
        self.id = id
        self.deceasedUserId = deceasedUserId
        self.deceasedName = deceasedName
        self.triggeredByUserId = triggeredByUserId
        self.triggeredByName = triggeredByName
        self.triggeredAt = Date()
        self.isConfirmed = false
        self.confirmationStep = 0
    }
}
