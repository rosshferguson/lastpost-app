//
//  SupabaseService.swift
//  Last Post
//

import Foundation
import Combine
import SwiftData
import Supabase

// MARK: - Configuration

private let supabaseURL = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co")!
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5cHpiYnVwenVhdWtka2plZ2h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MjAyMjQsImV4cCI6MjA5ODM5NjIyNH0.BiK5Uq5CJQ2tJ6gZDKZDXPnn37OpAy2HVuFVw4BQzzI"

// MARK: - Result types

struct InitiateResult {
    let notificationId: String
    let waitingPeriodEnds: Date
    let isDryRun: Bool
    let dryRunCode: String?
}

struct LegacyDataPayload: Decodable {
    let funeralWishesData: Data?
    let importantDocumentsData: Data?
    let digitalAssetsData: Data?
    let lifeHistoryData: Data?

    enum CodingKeys: String, CodingKey {
        case funeralWishes      = "funeral_wishes_data"
        case importantDocuments = "important_documents_data"
        case digitalAssets      = "digital_assets_data"
        case lifeHistory        = "life_history_data"
    }

    init(funeralWishesData: Data?, importantDocumentsData: Data?, digitalAssetsData: Data?, lifeHistoryData: Data?) {
        self.funeralWishesData      = funeralWishesData
        self.importantDocumentsData = importantDocumentsData
        self.digitalAssetsData      = digitalAssetsData
        self.lifeHistoryData        = lifeHistoryData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        funeralWishesData      = (try? c.decode(AnyCodable.self, forKey: .funeralWishes)).flatMap { try? JSONEncoder().encode($0) }
        importantDocumentsData = (try? c.decode(AnyCodable.self, forKey: .importantDocuments)).flatMap { try? JSONEncoder().encode($0) }
        digitalAssetsData      = (try? c.decode(AnyCodable.self, forKey: .digitalAssets)).flatMap { try? JSONEncoder().encode($0) }
        lifeHistoryData        = (try? c.decode(AnyCodable.self, forKey: .lifeHistory)).flatMap { try? JSONEncoder().encode($0) }
    }
}

/// Wrapper to decode arbitrary JSON values for re-encoding as Data.
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues { $0.value } }
        else if let v = try? c.decode([AnyCodable].self) { value = v.map { $0.value } }
        else if let v = try? c.decode(String.self)  { value = v }
        else if let v = try? c.decode(Double.self)  { value = v }
        else if let v = try? c.decode(Bool.self)    { value = v }
        else { value = NSNull() }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as [String: Any]:
            try c.encode(v.mapValues { AnyCodable($0) })
        case let v as [Any]:
            try c.encode(v.map { AnyCodable($0) })
        case let v as String:  try c.encode(v)
        case let v as Double:  try c.encode(v)
        case let v as Bool:    try c.encode(v)
        default: try c.encodeNil()
        }
    }
}

struct ConfirmResult {
    let confirmed: Bool
    let isDryRun: Bool
    let contactsNotified: Int
    let totalContacts: Int
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case noUserReturned
    case notAuthenticated
    case ownerNotLinked

    var errorDescription: String? {
        switch self {
        case .noUserReturned:  return "No user was returned from the server."
        case .notAuthenticated: return "You must be signed in to perform this action."
        case .ownerNotLinked:  return "Could not find the Supabase account for this user."
        }
    }
}

// MARK: - In-memory auth storage
//
// By providing a pure in-memory AuthLocalStorage, the Supabase SDK initialises
// with NO stored session.  This prevents the SDK's background auto-restore task
// from firing, which is what triggers the IssueReporter.reportIssue crash in
// debug builds (supabase-swift / xctest-dynamic-overlay known issue).
//
// We handle session persistence ourselves: access + refresh tokens are written
// to UserDefaults after sign-in and restored via client.auth.setSession() on
// every subsequent launch.

private final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private var data: [String: Data] = [:]
    private let lock = NSLock()
    func store(key: String, value: Data) throws  { lock.lock(); data[key] = value; lock.unlock() }
    func retrieve(key: String) throws -> Data?   { lock.lock(); defer { lock.unlock() }; return data[key] }
    func remove(key: String) throws              { lock.lock(); data.removeValue(forKey: key); lock.unlock() }
}

// MARK: - Service

@MainActor
class SupabaseService: ObservableObject {

    static let shared = SupabaseService()

    let client: SupabaseClient

    @Published var isAuthenticated = false
    @Published var supabaseUserId: UUID?
    @Published var supabaseUserEmail: String?
    @Published var authError: String?
    /// False when the user has signed up but not yet clicked the confirmation link.
    @Published var isEmailConfirmed: Bool = true

    // UserDefaults keys for our own token persistence
    private static let accessTokenKey    = "ff_access_token"
    private static let refreshTokenKey   = "ff_refresh_token"
    private static let supabaseUserIdDefaultsKey = "currentSupabaseUserId"

    private init() {
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    storage: InMemoryAuthStorage()
                )
            )
        )
    }

    // MARK: - Session

    /// Restores the Supabase session from our own UserDefaults token store using
    /// client.auth.setSession(), which does NOT go through the auto-restore code
    /// path that triggers the IssueReporter crash.
    func restoreSession() async {
        let defaults = UserDefaults.standard
        let accessToken  = defaults.string(forKey: Self.accessTokenKey)
        let refreshToken = defaults.string(forKey: Self.refreshTokenKey)
        let storedUserId = defaults.string(forKey: Self.supabaseUserIdDefaultsKey)

        // Fast path: if we have tokens, restore the full session
        if let at = accessToken, let rt = refreshToken {
            do {
                let session = try await client.auth.setSession(accessToken: at, refreshToken: rt)
                isAuthenticated    = true
                supabaseUserId     = session.user.id
                supabaseUserEmail  = session.user.email
                isEmailConfirmed   = session.user.emailConfirmedAt != nil
                // Persist any refreshed tokens the SDK returned
                defaults.set(session.accessToken,  forKey: Self.accessTokenKey)
                defaults.set(session.refreshToken, forKey: Self.refreshTokenKey)
                defaults.set(session.user.id.uuidString, forKey: Self.supabaseUserIdDefaultsKey)
                return
            } catch {
                // Tokens fully expired — fall through to sign-out state
            }
        }

        // Fallback: no tokens (e.g., first time using this build).
        // Show user as authenticated if we have a stored ID so they aren't
        // unexpectedly signed out after an app update.
        if let idString = storedUserId, let uuid = UUID(uuidString: idString) {
            isAuthenticated = true
            supabaseUserId  = uuid
        } else {
            isAuthenticated = false
            supabaseUserId  = nil
        }
    }

    // MARK: - Auth

    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "first_name": .string(firstName),
                "last_name": .string(lastName)
            ],
            redirectTo: URL(string: "lastpost://confirm-email")
        )
        let user = response.user
        // signUp doesn't always return a session immediately (email confirmation flow)
        // so we only store what we have
        isAuthenticated   = true
        supabaseUserId    = user.id
        supabaseUserEmail = email
        isEmailConfirmed  = user.emailConfirmedAt != nil
        UserDefaults.standard.set(user.id.uuidString, forKey: Self.supabaseUserIdDefaultsKey)
        // Try to get a session if available
        if let session = response.session {
            UserDefaults.standard.set(session.accessToken,  forKey: Self.accessTokenKey)
            UserDefaults.standard.set(session.refreshToken, forKey: Self.refreshTokenKey)
        }
        authError = nil

        // Write name to profiles table — Auth metadata alone doesn't populate it
        await updateProfile(firstName: firstName, lastName: lastName, email: email, phoneNumber: "")
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        isAuthenticated   = true
        supabaseUserId    = session.user.id
        supabaseUserEmail = session.user.email
        isEmailConfirmed  = session.user.emailConfirmedAt != nil
        let defaults = UserDefaults.standard
        defaults.set(session.accessToken,        forKey: Self.accessTokenKey)
        defaults.set(session.refreshToken,       forKey: Self.refreshTokenKey)
        defaults.set(session.user.id.uuidString, forKey: Self.supabaseUserIdDefaultsKey)
        authError = nil
    }

    /// Asks Supabase to re-send the confirmation email to the current user's address.
    func resendConfirmationEmail() async throws {
        guard let email = supabaseUserEmail else { return }
        try await client.auth.resend(email: email, type: .signup)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        isAuthenticated   = false
        supabaseUserId    = nil
        supabaseUserEmail = nil
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.accessTokenKey)
        defaults.removeObject(forKey: Self.refreshTokenKey)
        defaults.removeObject(forKey: Self.supabaseUserIdDefaultsKey)
    }

    /// Calls the delete-account edge function to permanently remove the auth user and all
    /// Supabase DB rows, then clears local auth state.  Returns true on success.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard let userId = supabaseUserId
                ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey).flatMap(UUID.init)
        else { return false }

        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/delete-account") else { return false }
        let payload: [String: String] = ["user_id": userId.uuidString]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["deleted"] as? Bool == true
        else { return false }

        // Clear local auth state exactly like signOut
        isAuthenticated   = false
        supabaseUserId    = nil
        supabaseUserEmail = nil
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.accessTokenKey)
        defaults.removeObject(forKey: Self.refreshTokenKey)
        defaults.removeObject(forKey: Self.supabaseUserIdDefaultsKey)
        try? await client.auth.signOut()
        return true
    }

    // MARK: - Profile

    func updateLastSeen() async {
        guard isAuthenticated, let userId = supabaseUserId else { return }
        _ = try? await client
            .from("profiles")
            .update(["last_seen_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func updateProfile(firstName: String, lastName: String, email: String, phoneNumber: String) async {
        guard isAuthenticated, let userId = supabaseUserId else { return }

        struct ProfileUpdate: Encodable {
            let first_name: String
            let last_name: String
            let email: String
            let phone_number: String
        }

        _ = try? await client
            .from("profiles")
            .update(ProfileUpdate(
                first_name: firstName,
                last_name: lastName,
                email: email,
                phone_number: phoneNumber
            ))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Local ↔ Supabase ID mapping

    func saveSupabaseId(forLocalUserId localId: UUID) {
        guard let supabaseId = supabaseUserId else { return }
        var mapping = idMapping
        mapping[localId.uuidString] = supabaseId.uuidString
        UserDefaults.standard.set(mapping, forKey: "ff_supabase_ids")
    }

    func supabaseId(forLocalUserId localId: UUID) -> UUID? {
        guard let uuidString = idMapping[localId.uuidString] else { return nil }
        return UUID(uuidString: uuidString)
    }

    private var idMapping: [String: String] {
        UserDefaults.standard.dictionary(forKey: "ff_supabase_ids") as? [String: String] ?? [:]
    }

    /// Stores an arbitrary local→Supabase UUID mapping (used for shadow owner records).
    func storeIdMapping(localId: UUID, supabaseId: UUID) {
        var mapping = idMapping
        mapping[localId.uuidString] = supabaseId.uuidString
        UserDefaults.standard.set(mapping, forKey: "ff_supabase_ids")
    }

    // MARK: - Designated Person Sync

    /// Upserts the designated person record via an edge function (no live auth session needed).
    /// Returns the acceptance_token so the caller can embed it in the invitation email.
    func syncDesignatedPersonToSupabase(person: DesignatedPerson, ownerSupabaseId: UUID) async -> String? {
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/sync-designated-person") else { return nil }

        let payload: [String: Any] = [
            "owner_id":              ownerSupabaseId.uuidString,
            "first_name":            person.firstName,
            "last_name":             person.lastName,
            "email":                 person.email,
            "phone_number":          person.phoneNumber,
            "relationship":          person.relationship,
            "can_access_photos":     person.canAccessPhotos,
            "can_view_arrangements": person.canViewArrangements
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["acceptance_token"] as? String
    }

    /// Called on sign-in and app foreground: links designated_persons rows to this user's
    /// Supabase profile via the link-designations edge function (SERVICE_ROLE_KEY).
    /// Does not require a valid user session — works even after token expiry.
    func linkPendingDesignations(userEmail: String) async {
        guard let userId = supabaseUserId
                ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey).flatMap(UUID.init)
        else { return }

        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/link-designations") else { return }
        let payload: [String: String] = ["user_id": userId.uuidString, "user_email": userEmail]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        _ = try? await URLSession.shared.data(for: req)
    }

    /// Calls the remove-designation edge function so the owner's designated_persons row is deleted.
    /// After this, fetchAndSyncDesignations will remove the local shadow record automatically.
    func removeMyselfAsDesignatedPerson(ownerSupabaseId: UUID) async {
        guard let myId = supabaseUserId
                ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey).flatMap(UUID.init)
        else { return }
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/remove-designation") else { return }
        let payload: [String: String] = [
            "owner_id": ownerSupabaseId.uuidString,
            "designated_user_id": myId.uuidString
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        _ = try? await URLSession.shared.data(for: req)
    }

    /// Fetches all designations for the signed-in user from Supabase, then creates
    /// shadow User + DesignatedPerson records in SwiftData so usersIAmDesignatedFor works.
    /// Queries by both linked_profile_id AND email so unlinked-but-accepted rows are caught.
    func fetchAndSyncDesignations(modelContext: ModelContext, currentUser: User) async {
        guard let userId = supabaseUserId
                ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey).flatMap(UUID.init)
        else { return }
        let accessToken = (try? await client.auth.session.accessToken)
            ?? UserDefaults.standard.string(forKey: Self.accessTokenKey)
        guard let accessToken else { return }

        let userEmail = supabaseUserEmail ?? currentUser.email
        let selectFields = "id,owner_id,first_name,last_name,email,relationship,can_access_photos,can_view_arrangements"
        let commonHeaders: [(String, String)] = [
            ("Authorization", "Bearer \(accessToken)"),
            ("apikey", supabaseAnonKey),
            ("Accept", "application/json")
        ]

        var allRows: [[String: Any]] = []
        var seenOwnerIds = Set<String>()
        var queriesSucceeded = false   // guards stale-record cleanup

        func applyHeaders(_ req: inout URLRequest) {
            for (k, v) in commonHeaders { req.setValue(v, forHTTPHeaderField: k) }
        }

        // Query 1: rows explicitly linked to this user (primary)
        var c1 = URLComponents(string: "https://kypzbbupzuaukdkjeghu.supabase.co/rest/v1/designated_persons")!
        c1.queryItems = [
            URLQueryItem(name: "linked_profile_id", value: "eq.\(userId.uuidString)"),
            URLQueryItem(name: "invitation_accepted", value: "eq.true"),
            URLQueryItem(name: "select", value: selectFields)
        ]
        if let url1 = c1.url {
            var req1 = URLRequest(url: url1)
            applyHeaders(&req1)
            if let (data1, resp1) = try? await URLSession.shared.data(for: req1),
               (resp1 as? HTTPURLResponse)?.statusCode == 200,
               let rows1 = try? JSONSerialization.jsonObject(with: data1) as? [[String: Any]] {
                queriesSucceeded = true
                for row in rows1 {
                    guard let ownerId = row["owner_id"] as? String else { continue }
                    if seenOwnerIds.insert(ownerId).inserted { allRows.append(row) }
                }
            }
        }

        // Query 2: rows matching this user's email (catches rows not yet linked)
        if !userEmail.isEmpty {
            var c2 = URLComponents(string: "https://kypzbbupzuaukdkjeghu.supabase.co/rest/v1/designated_persons")!
            c2.queryItems = [
                URLQueryItem(name: "email", value: "eq.\(userEmail)"),
                URLQueryItem(name: "invitation_accepted", value: "eq.true"),
                URLQueryItem(name: "select", value: selectFields)
            ]
            if let url2 = c2.url {
                var req2 = URLRequest(url: url2)
                applyHeaders(&req2)
                if let (data2, resp2) = try? await URLSession.shared.data(for: req2),
                   (resp2 as? HTTPURLResponse)?.statusCode == 200,
                   let rows2 = try? JSONSerialization.jsonObject(with: data2) as? [[String: Any]] {
                    queriesSucceeded = true
                    for row in rows2 {
                        guard let ownerId = row["owner_id"] as? String else { continue }
                        if seenOwnerIds.insert(ownerId).inserted { allRows.append(row) }
                    }
                }
            }
        }

        let rows = allRows

        for row in rows {
            guard let ownerIdString = row["owner_id"] as? String,
                  let ownerSupabaseId = UUID(uuidString: ownerIdString) else { continue }

            // 2. Fetch owner's profile for their name
            var profileComponents = URLComponents(string: "https://kypzbbupzuaukdkjeghu.supabase.co/rest/v1/profiles")!
            profileComponents.queryItems = [
                URLQueryItem(name: "id", value: "eq.\(ownerIdString)"),
                URLQueryItem(name: "select", value: "first_name,last_name,email")
            ]
            guard let profileUrl = profileComponents.url else { continue }
            var profileReq = URLRequest(url: profileUrl)
            profileReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            profileReq.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            profileReq.setValue("application/json", forHTTPHeaderField: "Accept")
            guard let (profileData, _) = try? await URLSession.shared.data(for: profileReq),
                  let profiles = try? JSONSerialization.jsonObject(with: profileData) as? [[String: Any]],
                  let profile = profiles.first else { continue }

            let ownerFirstName = profile["first_name"] as? String ?? ""
            let ownerLastName  = profile["last_name"]  as? String ?? ""

            // 3. Find or create a shadow User record using the Supabase UUID as the local ID.
            // If the owner IS the current user (self-designation), use their real local record
            // so that forUser.contacts is populated correctly in the notification flow.
            let ownerUser: User
            if ownerSupabaseId == userId {
                ownerUser = currentUser
            } else {
                let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == ownerSupabaseId })
                let existingUsers = (try? modelContext.fetch(descriptor)) ?? []
                if let existing = existingUsers.first {
                    ownerUser = existing
                } else {
                    let shadow = User(id: ownerSupabaseId, firstName: ownerFirstName, lastName: ownerLastName)
                    modelContext.insert(shadow)
                    ownerUser = shadow
                }
            }

            // Store the local→Supabase mapping (same ID in this case)
            storeIdMapping(localId: ownerSupabaseId, supabaseId: ownerSupabaseId)

            // 4. Find or create the DesignatedPerson record linking this owner → currentUser
            let linkedId: UUID? = currentUser.id
            let dpDescriptor = FetchDescriptor<DesignatedPerson>(
                predicate: #Predicate { $0.linkedUserId == linkedId }
            )
            let existingDps = (try? modelContext.fetch(dpDescriptor)) ?? []
            let alreadyLinked = existingDps.contains { $0.owner?.id == ownerSupabaseId }

            if !alreadyLinked {
                let dp = DesignatedPerson(
                    firstName: currentUser.firstName,
                    lastName:  currentUser.lastName,
                    email:     currentUser.email
                )
                dp.linkedUserId       = currentUser.id
                dp.invitationAccepted = true
                dp.canAccessPhotos    = row["can_access_photos"] as? Bool ?? false
                dp.canViewArrangements = row["can_view_arrangements"] as? Bool ?? true
                dp.owner = ownerUser
                modelContext.insert(dp)
            }
        }

        // Cleanup: delete stale shadow DesignatedPerson records whose owner is no
        // longer in the Supabase rows (i.e. the owner removed us as their designee).
        // Only run if at least one query succeeded so we don't wipe records on network error.
        if queriesSucceeded {
            let activeOwnerIds = Set(rows.compactMap { $0["owner_id"] as? String }.compactMap(UUID.init))
            let linkedId: UUID? = currentUser.id
            let allDpDescriptor = FetchDescriptor<DesignatedPerson>(
                predicate: #Predicate { $0.linkedUserId == linkedId && $0.invitationAccepted }
            )
            let allLocalDps = (try? modelContext.fetch(allDpDescriptor)) ?? []
            for dp in allLocalDps {
                guard let ownerShadowId = dp.owner?.id else { continue }
                if !activeOwnerIds.contains(ownerShadowId) {
                    modelContext.delete(dp)
                }
            }
        }

        try? modelContext.save()
    }

    // MARK: - Contact Invitation Sync

    /// Calls the get-invitation-statuses edge function (service role) to check which contacts
    /// have responded, then updates local SwiftData. Works even when owner_id is NULL in the token.
    func syncContactInvitationStatuses(contacts: [Contact], modelContext: ModelContext) async {
        // Only sync contacts that are still pending
        let pendingContacts = contacts.filter { $0.invitationSent && !$0.invitationAccepted }
        guard !pendingContacts.isEmpty else { return }

        let emails = pendingContacts.compactMap { $0.email.isEmpty ? nil : $0.email }
        guard !emails.isEmpty else { return }

        let ownerIdString = supabaseUserId?.uuidString
            ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey)

        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/get-invitation-statuses") else { return }
        var payload: [String: Any] = ["emails": emails]
        if let ownerId = ownerIdString { payload["ownerSupabaseId"] = ownerId }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        // action nil or "accept" → accepted; "decline" → declined
        var acceptedEmails = Set<String>()
        var declinedEmails = Set<String>()
        for row in rows {
            guard let email = row["email"] as? String else { continue }
            let action = row["action"] as? String
            if action == "decline" { declinedEmails.insert(email) }
            else                   { acceptedEmails.insert(email) }
        }

        var changed = false
        for contact in contacts {
            if acceptedEmails.contains(contact.email) && !contact.invitationAccepted {
                contact.invitationAccepted = true
                contact.lastUpdated = Date()
                changed = true
            } else if declinedEmails.contains(contact.email) && !contact.invitationAccepted {
                // Declined — you may want to surface this differently; for now just leave as pending
            }
        }
        if changed { try? modelContext.save() }
    }

    /// Fetches the owner's designated_persons rows from Supabase and removes any local
    /// DesignatedPerson records that are no longer there (i.e. the person removed themselves).
    /// Only runs when the owner is authenticated and the HTTP response is 200, so a network
    /// failure can never accidentally wipe valid records.
    func syncOwnerDesignatedPersons(modelContext: ModelContext, currentUser: User) async {
        guard let userId = supabaseUserId
                ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey).flatMap(UUID.init)
        else { return }

        guard let accessToken = (try? await client.auth.session.accessToken)
                ?? UserDefaults.standard.string(forKey: Self.accessTokenKey)
        else { return }

        var components = URLComponents(string: "https://kypzbbupzuaukdkjeghu.supabase.co/rest/v1/designated_persons")!
        components.queryItems = [
            URLQueryItem(name: "owner_id", value: "eq.\(userId.uuidString)"),
            URLQueryItem(name: "select", value: "email,invitation_accepted")
        ]
        guard let url = components.url else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }

        // Emails still present in Supabase (active designees)
        let activeEmails = Set(rows.compactMap { $0["email"] as? String }.map { $0.lowercased() })

        // Remove local records for accepted designees who are no longer in Supabase
        var changed = false
        for dp in currentUser.designatedPersons {
            guard dp.invitationAccepted, !dp.email.isEmpty else { continue }
            if !activeEmails.contains(dp.email.lowercased()) {
                currentUser.designatedPersons.removeAll { $0.id == dp.id }
                modelContext.delete(dp)
                changed = true
            }
        }
        if changed { try? modelContext.save() }
    }

    /// Checks Supabase (via edge function) for which designated person emails have accepted,
    /// then updates matching local SwiftData objects. Works regardless of owner_id or session state.
    func syncDesignatedPersonStatuses(persons: [DesignatedPerson], modelContext: ModelContext) async {
        // Only check people we haven't already confirmed
        let pending = persons.filter { !$0.invitationAccepted && !$0.email.isEmpty }
        guard !pending.isEmpty else { return }

        let emails = pending.map { $0.email }
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/get-designated-statuses") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["emails": emails])

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let acceptedEmails = json["accepted"] as? [String] else { return }

        let acceptedSet = Set(acceptedEmails)
        var changed = false
        for person in pending where acceptedSet.contains(person.email) {
            person.invitationAccepted = true
            person.lastReconfirmedAt = person.lastReconfirmedAt ?? Date()
            changed = true
        }
        if changed { try? modelContext.save() }
    }

    // MARK: - Designated Person Revocation

    /// Called when the owner removes a designated person. Deletes the row from Supabase
    /// so their web trigger link and in-app access are both revoked immediately.
    func revokeDesignatedPerson(email: String) async {
        guard let ownerIdString = supabaseUserId?.uuidString
                ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey),
              !email.isEmpty
        else { return }

        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/rest/v1/designated_persons?owner_id=eq.\(ownerIdString)&email=eq.\(encoded)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Liveness Check

    func recordLivenessCheckIn(nextCheckAt: Date) async {
        guard isAuthenticated, let userId = supabaseUserId else { return }
        let iso = ISO8601DateFormatter().string(from: nextCheckAt)
        _ = try? await client
            .from("profiles")
            .update([
                "last_seen_at": ISO8601DateFormatter().string(from: Date()),
                "next_liveness_check_at": iso
            ])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func updateLivenessCheckSchedule(enabled: Bool, frequencyDays: Int, nextCheckAt: Date?) async {
        guard isAuthenticated, let userId = supabaseUserId else { return }
        var fields: [String: String] = [
            "liveness_check_enabled": enabled ? "true" : "false",
            "liveness_check_frequency_days": "\(frequencyDays)"
        ]
        if let next = nextCheckAt {
            fields["next_liveness_check_at"] = ISO8601DateFormatter().string(from: next)
        }
        _ = try? await client
            .from("profiles")
            .update(fields)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Legacy Data Sync

    /// Upload a single legacy JSON field to the profiles table.
    /// `column` must be one of: funeral_wishes_data, important_documents_data,
    /// digital_assets_data, life_history_data
    func syncLegacyField(column: String, data: Data) async {
        let userId = supabaseUserId
            ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey).flatMap(UUID.init)
        guard let userId else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return }
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/sync-legacy-data") else { return }

        let body: [String: Any] = ["owner_id": userId.uuidString, "column": column, "data": json]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Sends a welfare check request to all designated persons for the current user.
    func requestWelfareCheck(ownerName: String) async {
        let userId = supabaseUserId
            ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey).flatMap(UUID.init)
        guard let userId,
              let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/request-welfare-check")
        else { return }

        let body: [String: String] = ["owner_id": userId.uuidString, "owner_name": ownerName]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Fetch all legacy data for an owner. Called by the designated person after confirmation.
    func fetchLegacyData(forOwnerId ownerId: UUID) async -> LegacyDataPayload? {
        print("[fetchLegacyData] querying owner_id: \(ownerId.uuidString)")
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/get-legacy-data") else { return nil }

        let body: [String: String] = ["owner_id": ownerId.uuidString]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            print("[fetchLegacyData] Network error")
            return nil
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[fetchLegacyData] Status: \(statusCode), Body: \(String(data: data, encoding: .utf8) ?? "nil")")

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[fetchLegacyData] JSON parse failed")
            return nil
        }

        func toData(_ key: String) -> Data? {
            guard let value = json[key], !(value is NSNull) else { return nil }
            return try? JSONSerialization.data(withJSONObject: value)
        }

        return LegacyDataPayload(
            funeralWishesData:      toData("funeral_wishes_data"),
            importantDocumentsData: toData("important_documents_data"),
            digitalAssetsData:      toData("digital_assets_data"),
            lifeHistoryData:        toData("life_history_data")
        )
    }

    // MARK: - Edge Functions

    // MARK: - Contact Sync (for web trigger)

    /// Syncs the full contact list to Supabase so the web trigger can notify them
    /// without the iOS app being open. Called whenever contacts change.
    func syncContacts(_ contacts: [Contact]) async {
        let ownerId = supabaseUserId?.uuidString
            ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey)
        guard let ownerId,
              let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/sync-contacts")
        else { return }

        struct ContactRow: Encodable {
            let local_id:         String
            let first_name:       String
            let last_name:        String
            let email:            String
            let phone_number:     String
            let personal_message: String
            let group_name:       String?
        }

        struct Body: Encodable {
            let owner_id: String
            let contacts: [ContactRow]
        }

        // Only sync contacts who have accepted their invitation — contacts who haven't
        // accepted have not consented to their data being stored on our servers.
        let acceptedContacts = contacts.filter { $0.invitationAccepted }

        let rows = acceptedContacts.map { c in
            ContactRow(
                local_id:         c.id.uuidString,
                first_name:       c.firstName,
                last_name:        c.lastName,
                email:            c.email,
                phone_number:     c.phoneNumber,
                personal_message: c.personalMessage ?? "",
                group_name:       c.group
            )
        }

        guard let body = try? JSONEncoder().encode(Body(owner_id: ownerId, contacts: rows)) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }

    func notifyDesignatedPersonAdded(
        ownerName: String,
        designatedPersonName: String,
        designatedPersonEmail: String,
        designatedPersonPhone: String = "",
        relationship: String,
        inviteLink: String,
        ownerId: String? = nil,
        canAccessPhotos: Bool = false,
        canViewArrangements: Bool = true
    ) async {
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/notify-designated-person") else { return }
        // Resolve owner ID: in-memory first, then UserDefaults
        let resolvedOwnerId = ownerId
            ?? supabaseUserId?.uuidString
            ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey)
        var payload: [String: Any] = [
            "owner_name":               ownerName,
            "designated_person_name":   designatedPersonName,
            "designated_person_email":  designatedPersonEmail,
            "relationship":             relationship,
            "invite_link":              inviteLink,
            "can_access_photos":        canAccessPhotos,
            "can_view_arrangements":    canViewArrangements
        ]
        if !designatedPersonPhone.isEmpty {
            payload["designated_person_phone"] = designatedPersonPhone
        }
        if let id = resolvedOwnerId {
            payload["owner_id"] = id
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }

    func sendConfirmationCode(code: String, designatedPersonName: String, designatedPersonEmail: String?, designatedPersonPhone: String?, deceasedName: String) async {
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/send-confirmation-code") else { return }
        var payload: [String: String] = [
            "code": code,
            "designated_person_name": designatedPersonName,
            "deceased_name": deceasedName,
        ]
        if let email = designatedPersonEmail { payload["designated_person_email"] = email }
        if let phone = designatedPersonPhone { payload["designated_person_phone"] = phone }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[sendConfirmationCode] status: \(status) body: \(String(data: data, encoding: .utf8) ?? "")")
        } catch {
            print("[sendConfirmationCode] error: \(error)")
        }
    }

    func notifyContactAdded(ownerName: String, contactFirstName: String, contactLastName: String, contactEmail: String, contactPhone: String = "", relationship: String) async {
        print("[notifyContactAdded] called — email: '\(contactEmail)' phone: '\(contactPhone)'")
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/notify-contact-added") else { return }
        // Read owner ID from in-memory property OR UserDefaults fallback so we never send NULL
        // even if restoreSession() hasn't completed yet.
        let ownerIdString = supabaseUserId?.uuidString
            ?? UserDefaults.standard.string(forKey: Self.supabaseUserIdDefaultsKey)
        var payload: [String: String] = [
            "ownerName": ownerName,
            "contactFirstName": contactFirstName,
            "contactLastName": contactLastName,
            "contactName": "\(contactFirstName) \(contactLastName)".trimmingCharacters(in: .whitespaces),
            "contactEmail": contactEmail,
            "relationship": relationship
        ]
        if !contactPhone.isEmpty { payload["contactPhone"] = contactPhone }
        if let ownerId = ownerIdString {
            payload["ownerSupabaseId"] = ownerId
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        print("[notifyContactAdded] sending request to \(url)")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[notifyContactAdded] response status: \(status) body: \(String(data: data, encoding: .utf8) ?? "")")
        } catch {
            print("[notifyContactAdded] network error: \(error)")
        }
    }

    func sendFuneralDetails(payload: [String: String]) async throws {
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/send-funeral-details") else { return }
        guard let accessToken = (try? await client.auth.session.accessToken)
                ?? UserDefaults.standard.string(forKey: Self.accessTokenKey) else {
            throw SupabaseError.notAuthenticated
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = body
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw URLError(.badServerResponse)
        }
    }

    func initiateNotification(deceasedSupabaseId: UUID, isDryRun: Bool) async throws -> InitiateResult {
        guard isAuthenticated else { throw SupabaseError.notAuthenticated }

        struct Payload: Encodable {
            let owner_id: String
            let is_dry_run: Bool
        }

        struct Response: Decodable {
            let notification_id: String
            let waiting_period_ends: String
            let is_dry_run: Bool
            let dry_run_code: String?
        }

        let payload = Payload(owner_id: deceasedSupabaseId.uuidString, is_dry_run: isDryRun)
        let body = try JSONEncoder().encode(payload)

        let response: Response = try await client.functions.invoke(
            "initiate-notification",
            options: FunctionInvokeOptions(body: body)
        )

        let formatter = ISO8601DateFormatter()
        let waitingEnd = formatter.date(from: response.waiting_period_ends)
            ?? Date().addingTimeInterval(86400)

        return InitiateResult(
            notificationId: response.notification_id,
            waitingPeriodEnds: waitingEnd,
            isDryRun: response.is_dry_run,
            dryRunCode: response.dry_run_code
        )
    }

    // MARK: - Death notification (email + SMS to contacts)

    struct ContactNotificationPayload: Encodable {
        let name: String
        let email: String?
        let phone: String?
        let personal_message: String?
    }

    /// Fetches contacts from Supabase and sends death notifications.
    /// Used on the designated person's device where local SwiftData has no contacts for the deceased.
    func sendDeathNotificationsFromSupabase(
        ownerSupabaseId: UUID,
        deceasedName: String,
        designatedPersonEmail: String?
    ) async {
        let accessToken = (try? await client.auth.session.accessToken)
            ?? UserDefaults.standard.string(forKey: Self.accessTokenKey)
        guard let accessToken else { return }

        var components = URLComponents(string: "https://kypzbbupzuaukdkjeghu.supabase.co/rest/v1/user_contacts")!
        components.queryItems = [
            URLQueryItem(name: "owner_id", value: "eq.\(ownerSupabaseId.uuidString)"),
            URLQueryItem(name: "select",   value: "first_name,last_name,email,phone_number,personal_message")
        ]
        guard let url = components.url else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(supabaseAnonKey,          forHTTPHeaderField: "apikey")
        req.setValue("application/json",       forHTTPHeaderField: "Accept")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        let payloads: [ContactNotificationPayload] = rows.compactMap { row in
            let email = row["email"]        as? String ?? ""
            let phone = row["phone_number"] as? String ?? ""
            guard !email.isEmpty || !phone.isEmpty else { return nil }
            let firstName = row["first_name"] as? String ?? ""
            let lastName  = row["last_name"]  as? String ?? ""
            return ContactNotificationPayload(
                name:             "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces),
                email:            email.isEmpty ? nil : email,
                phone:            phone.isEmpty ? nil : phone,
                personal_message: row["personal_message"] as? String
            )
        }
        guard !payloads.isEmpty,
              let sendUrl = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/send-death-notifications") else { return }

        struct Body: Encodable {
            let deceased_name: String
            let contacts: [ContactNotificationPayload]
            let designated_person_email: String?
        }
        guard let body = try? JSONEncoder().encode(Body(
            deceased_name:            deceasedName,
            contacts:                 payloads,
            designated_person_email:  designatedPersonEmail
        )) else { return }

        var request = URLRequest(url: sendUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Sends the death notification email and SMS to each contact.
    /// Called after `finalConfirmation()` in NotificationViewModel.
    /// Pass `designatedPersonEmail` so contacts can reply directly to the designated person.
    func sendDeathNotificationsToContacts(deceasedName: String, contacts: [Contact], designatedPersonEmail: String? = nil, ownerSupabaseId: UUID? = nil) async {
        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/send-death-notifications") else { return }

        let payloads = contacts.map { c in
            ContactNotificationPayload(
                name:             c.fullName,
                email:            c.email.isEmpty ? nil : c.email,
                phone:            c.phoneNumber.isEmpty ? nil : c.phoneNumber,
                personal_message: c.personalMessage
            )
        }

        struct Body: Encodable {
            let deceased_name: String
            let contacts: [ContactNotificationPayload]
            let designated_person_email: String?
            let owner_id: String?
        }

        guard let body = try? JSONEncoder().encode(Body(
            deceased_name: deceasedName,
            contacts: payloads,
            designated_person_email: designatedPersonEmail,
            owner_id: ownerSupabaseId?.uuidString
        )) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }

    func confirmNotification(supabaseNotificationId: String, code: String) async throws -> ConfirmResult {
        guard isAuthenticated else { throw SupabaseError.notAuthenticated }

        struct Payload: Encodable {
            let notification_id: String
            let confirmation_code: String
        }

        struct Response: Decodable {
            let confirmed: Bool
            let is_dry_run: Bool
            let contacts_notified: Int
            let total_contacts: Int
        }

        let payload = Payload(notification_id: supabaseNotificationId, confirmation_code: code)
        let body = try JSONEncoder().encode(payload)

        let response: Response = try await client.functions.invoke(
            "confirm-notification",
            options: FunctionInvokeOptions(body: body)
        )

        return ConfirmResult(
            confirmed: response.confirmed,
            isDryRun: response.is_dry_run,
            contactsNotified: response.contacts_notified,
            totalContacts: response.total_contacts
        )
    }
}
