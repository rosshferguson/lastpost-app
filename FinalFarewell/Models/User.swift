//
//  User.swift
//  Last Post
//
//  Added:
//  - digitalAssetsData: JSON-encoded [DigitalAsset] for the digital asset inventory
//  - livenessCheckEnabled, livenessCheckFrequencyDays, lastLivenessCheckAt, nextLivenessCheckAt
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

    // Timestamps
    var lastMessageUpdated: Date?
    var annualCheckInDate: Date?

    // Documents checklist (JSON)
    var importantDocumentsData: Data?

    // Funeral wishes (JSON)
    var funeralWishesData: Data?

    // Digital asset inventory (JSON)
    var digitalAssetsData: Data?

    // Liveness check
    var livenessCheckEnabled: Bool
    var livenessCheckFrequencyDays: Int   // 7 = weekly, 30 = monthly, 90 = quarterly
    var lastLivenessCheckAt: Date?
    var nextLivenessCheckAt: Date?

    @Relationship(deleteRule: .cascade) var contacts: [Contact] = []
    @Relationship(deleteRule: .cascade) var designatedPersons: [DesignatedPerson] = []
    @Relationship(deleteRule: .cascade) var sharedMedia: [SharedMedia] = []
    @Relationship(deleteRule: .nullify) var appearsOnLists: [Contact] = []

    var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var importantDocuments: [DocumentNote] {
        get {
            guard let data = importantDocumentsData,
                  let decoded = try? JSONDecoder().decode([DocumentNote].self, from: data)
            else { return DocumentNote.defaults }
            return decoded
        }
        set { importantDocumentsData = try? JSONEncoder().encode(newValue) }
    }

    var digitalAssets: [DigitalAsset] {
        get {
            guard let data = digitalAssetsData,
                  let decoded = try? JSONDecoder().decode([DigitalAsset].self, from: data)
            else { return [] }
            return decoded
        }
        set { digitalAssetsData = try? JSONEncoder().encode(newValue) }
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
        self.livenessCheckEnabled = false
        self.livenessCheckFrequencyDays = 30
    }
}

// MARK: - Document note

struct DocumentNote: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var category: String
    var title: String
    var notes: String
    var isComplete: Bool = false

    static let defaults: [DocumentNote] = [
        DocumentNote(category: "Legal", title: "Will location", notes: ""),
        DocumentNote(category: "Legal", title: "Power of attorney", notes: ""),
        DocumentNote(category: "Finance", title: "Bank account contacts", notes: ""),
        DocumentNote(category: "Finance", title: "Insurance policies", notes: ""),
        DocumentNote(category: "Finance", title: "Pension or investments", notes: ""),
        DocumentNote(category: "Funeral", title: "Pre-paid funeral plan", notes: ""),
        DocumentNote(category: "Funeral", title: "Burial or cremation wishes", notes: ""),
        DocumentNote(category: "Property", title: "Mortgage or tenancy details", notes: ""),
        DocumentNote(category: "Property", title: "Vehicle ownership", notes: ""),
        DocumentNote(category: "Digital", title: "Password manager location", notes: ""),
        DocumentNote(category: "Digital", title: "Social media wishes", notes: ""),
    ]
}

// MARK: - Digital asset

struct DigitalAsset: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var category: DigitalAssetCategory
    var name: String            // e.g. "Lloyds Bank Current Account"
    var institution: String     // e.g. "Lloyds Bank"
    var accountHint: String     // e.g. "Last 4 digits: 4821" or "Joint account with Sarah"
    var accessNotes: String     // Where login details are kept, who has access
    var locationNotes: String   // Physical location (branch, documents drawer, etc.)
    var createdAt: Date = Date()
    var lastUpdated: Date = Date()

    enum DigitalAssetCategory: String, Codable, CaseIterable, Identifiable {
        var id: String { rawValue }
        case banking      = "Banking"
        case investments  = "Investments"
        case insurance    = "Insurance"
        case pension      = "Pension & Retirement"
        case property     = "Property"
        case crypto       = "Cryptocurrency"
        case socialMedia  = "Social Media"
        case email        = "Email Accounts"
        case passwords    = "Passwords"
        case subscriptions = "Subscriptions"
        case other        = "Other"

        var systemImage: String {
            switch self {
            case .banking:       return "building.columns"
            case .investments:   return "chart.line.uptrend.xyaxis"
            case .insurance:     return "shield.lefthalf.filled"
            case .pension:       return "person.badge.clock"
            case .property:      return "house"
            case .crypto:        return "bitcoinsign.circle"
            case .socialMedia:   return "bubble.left.and.bubble.right"
            case .email:         return "envelope"
            case .passwords:     return "key"
            case .subscriptions: return "repeat"
            case .other:         return "folder"
            }
        }
    }
}
