//
//  ContactsViewModel.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import Foundation
import SwiftUI
import SwiftData

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var contactsNeedingVerification: [Contact] = []
    
    private var modelContext: ModelContext?
    private var currentUser: User?
    
    func configure(context: ModelContext, user: User?) {
        self.modelContext = context
        self.currentUser = user
        loadContacts()
    }
    
    func loadContacts() {
        guard let user = currentUser else {
            contacts = []
            return
        }
        
        contacts = user.contacts.sorted { $0.lastName < $1.lastName }
        contactsNeedingVerification = contacts.filter { $0.needsVerification }
    }
    
    func addContact(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String,
        relationship: String,
        notes: String
    ) {
        guard let context = modelContext, let user = currentUser else { return }
        
        let contact = Contact(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            relationship: relationship,
            notes: notes
        )
        
        contact.owner = user
        user.contacts.append(contact)
        
        context.insert(contact)
        
        do {
            try context.save()
            loadContacts()
            
            // Send invitation
            sendInvitation(to: contact)
        } catch {
            errorMessage = "Failed to add contact: \(error.localizedDescription)"
        }
    }
    
    func updateContact(_ contact: Contact) {
        contact.lastUpdated = Date()
        saveContext()
        loadContacts()
    }
    
    func deleteContact(_ contact: Contact) {
        guard let context = modelContext else { return }
        
        context.delete(contact)
        saveContext()
        loadContacts()
    }
    
    func verifyContact(_ contact: Contact) {
        contact.lastVerified = Date()
        contact.lastUpdated = Date()
        saveContext()
        loadContacts()
    }
    
    func sendInvitation(to contact: Contact) {
        // Generate deep link
        let inviteLink = DeepLinkService.generateInviteLink(
            forContactId: contact.id,
            fromUserId: currentUser?.id ?? UUID()
        )
        
        // In production, send via email/SMS
        // For now, mark as sent
        contact.invitationSent = true
        contact.lastUpdated = Date()
        saveContext()
        
        print("Invitation link: \(inviteLink)")
    }
    
    func acceptContactInvitation(contactId: UUID) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Contact>(
            predicate: #Predicate { $0.id == contactId }
        )
        
        do {
            let contacts = try context.fetch(descriptor)
            if let contact = contacts.first {
                contact.invitationAccepted = true
                contact.hasApp = true
                contact.lastVerified = Date()
                contact.lastUpdated = Date()
                try context.save()
            }
        } catch {
            errorMessage = "Failed to accept invitation: \(error.localizedDescription)"
        }
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
