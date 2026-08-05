import Foundation
import SwiftUI

@MainActor
class DeepLinkService: ObservableObject {
    @Published var pendingDeepLink: DeepLink?
    
    enum DeepLink {
        case contactInvitation(contactId: UUID, fromUserId: UUID)
        case designatedPersonInvitation(personId: UUID, fromUserId: UUID)
        case acceptInvitation(type: String, id: UUID)
    }
    
    static let scheme = "finalfarewell"
    static let host = "app"
    
    static func generateInviteLink(forContactId contactId: UUID, fromUserId: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/invite/contact"
        components.queryItems = [
            URLQueryItem(name: "contactId", value: contactId.uuidString),
            URLQueryItem(name: "fromUserId", value: fromUserId.uuidString)
        ]
        return components.url!
    }
    
    static func generateDesignatedPersonLink(personId: UUID, fromUserId: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/invite/designated"
        components.queryItems = [
            URLQueryItem(name: "personId", value: personId.uuidString),
            URLQueryItem(name: "fromUserId", value: fromUserId.uuidString)
        ]
        return components.url!
    }
    
    func handleDeepLink(_ url: URL) {
        guard url.scheme == DeepLinkService.scheme else { return }
        
        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        switch path {
        case "/invite/contact":
            if let contactIdString = queryItems.first(where: { $0.name == "contactId" })?.value,
               let contactId = UUID(uuidString: contactIdString),
               let fromUserIdString = queryItems.first(where: { $0.name == "fromUserId" })?.value,
               let fromUserId = UUID(uuidString: fromUserIdString) {
                pendingDeepLink = .contactInvitation(contactId: contactId, fromUserId: fromUserId)
            }
            
        case "/invite/designated":
            if let personIdString = queryItems.first(where: { $0.name == "personId" })?.value,
               let personId = UUID(uuidString: personIdString),
               let fromUserIdString = queryItems.first(where: { $0.name == "fromUserId" })?.value,
               let fromUserId = UUID(uuidString: fromUserIdString) {
                pendingDeepLink = .designatedPersonInvitation(personId: personId, fromUserId: fromUserId)
            }
            
        default:
            break
        }
    }
}
