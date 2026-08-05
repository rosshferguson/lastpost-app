import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // For designated person mode
    @Published var pendingNotifications: [DeathNotification] = []
    @Published var usersIAmDesignatedFor: [User] = []
    
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadCurrentUser()
    }
    
    func loadCurrentUser() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { !$0.isDeceased },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let users = try context.fetch(descriptor)
            currentUser = users.first
        } catch {
            errorMessage = "Failed to load user: \(error.localizedDescription)"
        }
    }
    
    func createUser(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String,
        dateOfBirth: Date?
    ) {
        guard let context = modelContext else { return }
        
        let user = User(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            dateOfBirth: dateOfBirth
        )
        
        context.insert(user)
        
        do {
            try context.save()
            currentUser = user
        } catch {
            errorMessage = "Failed to create user: \(error.localizedDescription)"
        }
    }
    
    func updateUser(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String
    ) {
        guard let user = currentUser else { return }
        
        user.firstName = firstName
        user.lastName = lastName
        user.email = email
        user.phoneNumber = phoneNumber
        user.lastUpdated = Date()
        
        saveContext()
    }
    
    func markUserAsDeceased() {
        guard let user = currentUser else { return }
        
        user.isDeceased = true
        user.deceasedDate = Date()
        
        saveContext()
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
