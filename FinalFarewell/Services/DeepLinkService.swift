//
//  DeepLinkService.swift
//  FinalFarewell
//
//  Fixed: pendingDeepLink was set but nothing in the UI observed it.
//  Added a processDeepLink() method that ViewModels call after a link is opened,
//  and a clear() method so the pending link is consumed after handling.
//

import Combine
import SwiftUI
import Supabase

@MainActor
class DeepLinkService: ObservableObject {
    @Published var pendingDeepLink: DeepLink?
    
    enum DeepLink: Equatable {
        case contactInvitation(contactId: UUID, fromUserId: UUID)
        case designatedPersonInvitation(personId: UUID, fromUserId: UUID)
        case acceptInvitation(type: String, id: UUID)
        case passwordReset(url: URL)
        case emailConfirmed      // email verification link was tapped and succeeded
        case emailConfirmError   // link was tapped but the exchange failed

        static func == (lhs: DeepLink, rhs: DeepLink) -> Bool {
            switch (lhs, rhs) {
            case (.contactInvitation(let a, let b), .contactInvitation(let c, let d)): return a == c && b == d
            case (.designatedPersonInvitation(let a, let b), .designatedPersonInvitation(let c, let d)): return a == c && b == d
            case (.acceptInvitation(let a, let b), .acceptInvitation(let c, let d)): return a == c && b == d
            case (.passwordReset(let a), .passwordReset(let b)): return a == b
            case (.emailConfirmed, .emailConfirmed): return true
            case (.emailConfirmError, .emailConfirmError): return true
            default: return false
            }
        }
    }
    
    static let scheme = "finalfarewell"
    static let host = "app"
    
    // MARK: - Link generation
    
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
    
    // MARK: - Link handling
    
    func handleDeepLink(_ url: URL) {
        guard url.scheme == DeepLinkService.scheme || url.scheme == "lastpost" else { return }

        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        // lastpost://reset-password — host is "reset-password", path is empty
        if url.scheme == "lastpost" && (url.host == "reset-password" || path == "/reset-password") {
            pendingDeepLink = .passwordReset(url: url)
            return
        }

        // lastpost://confirm-email — email verification link redirected back into the app
        if url.scheme == "lastpost" && url.host == "confirm-email" {
            Task { await exchangeConfirmationToken(url: url) }
            return
        }

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
    
    // FIX: Call this after the pending link has been handled to clear it,
    // preventing the acceptance sheet from re-appearing.
    func clearPendingLink() {
        pendingDeepLink = nil
    }

    // MARK: - Email confirmation token exchange

    /// Called when lastpost://confirm-email is opened.
    /// Exchanges the PKCE code (or implicit tokens) Supabase puts in the URL
    /// for a live session, then signals success/failure via pendingDeepLink.
    private func exchangeConfirmationToken(url: URL) async {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        do {
            // PKCE flow: ?code=xxx
            if let code = queryItems.first(where: { $0.name == "code" })?.value {
                _ = try await SupabaseService.shared.client.auth.exchangeCodeForSession(authCode: code)
                SupabaseService.shared.isEmailConfirmed = true
                pendingDeepLink = .emailConfirmed
                return
            }
            // Implicit flow: #access_token=xxx&refresh_token=xxx&type=signup
            if let fragment = url.fragment {
                var dict = [String: String]()
                for pair in fragment.split(separator: "&") {
                    let parts = pair.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 { dict[String(parts[0])] = String(parts[1]) }
                }
                if let access = dict["access_token"], let refresh = dict["refresh_token"] {
                    try await SupabaseService.shared.client.auth.setSession(
                        accessToken: access, refreshToken: refresh
                    )
                    SupabaseService.shared.isEmailConfirmed = true
                    pendingDeepLink = .emailConfirmed
                    return
                }
            }
            pendingDeepLink = .emailConfirmError
        } catch {
            print("[DeepLink] Email confirmation failed: \(error)")
            pendingDeepLink = .emailConfirmError
        }
    }
}
