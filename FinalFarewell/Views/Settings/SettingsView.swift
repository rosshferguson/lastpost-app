//
//  SettingsView.swift
//  FinalFarewell
//
//  Added:
//  - Annual check-in reminder link (CheckInReminderView)
//  - Emergency card link (EmergencyCardView)
//  - Important documents link (DocumentsChecklistView)
//  - Designated mode toggle (switches to DesignatedModeView)
//  - Staleness timestamp for personal message
//  - Designated person reconfirmation trigger
//  - Subscription section + premium gates on legacy planning features
//

import SwiftUI
import SwiftData
import LocalAuthentication

struct SettingsView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.modelContext) private var modelContext

    @State private var showingAuth = false
    @State private var showingEditProfile = false
    @State private var debugUUIDStatus = ""
    @State private var debugSyncStatus = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var showingDisclaimer = false
    @State private var showingInstructionSheet = false
    @State private var showingCheckIn = false
    @State private var showingEmergencyCard = false
    @State private var showingDocuments = false
    @State private var showingFuneralWishes = false
    @State private var showingLifeHistory = false
    @State private var showingDigitalAssets = false
    @State private var showingLivenessCheck = false
    @State private var showPaywall = false
    @State private var paywallReason = ""

    @AppStorage("verificationReminderFrequency") private var notificationFrequency = "Monthly"
    @AppStorage("isInDesignatedMode") private var isInDesignatedMode = false

    let frequencies = ["Weekly", "Monthly", "Quarterly", "Yearly"]

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                subscriptionSection
                planningSection
                remindersSection
                securityPrivacySection
                supportSection
                aboutSection
                #if DEBUG
                debugSection
                #endif
                dangerSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAuth) { AuthView() }
            .sheet(isPresented: $showingEditProfile) { EditProfileView() }
            .sheet(isPresented: $showingCheckIn) { CheckInReminderView() }
            .sheet(isPresented: $showingEmergencyCard) { EmergencyCardView() }
            .sheet(isPresented: $showingDocuments) { DocumentsChecklistView() }
            .sheet(isPresented: $showingFuneralWishes) { FuneralWishesView() }
            .sheet(isPresented: $showingDigitalAssets) { NavigationStack { DigitalAssetsView() } }
            .sheet(isPresented: $showingLivenessCheck) { LivenessCheckSettingsView() }
            .sheet(isPresented: $showingLifeHistory) {
                NavigationStack {
                    if let user = userViewModel.currentUser {
                        LifeHistoryView(userId: user.id)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: paywallReason)
                    .environmentObject(subscriptionService)
            }
            .alert("Delete Account?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete everything", role: .destructive) { deleteAccount() }
            } message: {
                Text("This will permanently delete your Last Post account and all data — contacts, designated persons, memories, and notifications. This cannot be undone.")
            }
            .alert("Delete failed", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Something went wrong while deleting your account. Please try again.")
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section("Profile") {
            if let user = userViewModel.currentUser {
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(user.firstName.prefix(1) + user.lastName.prefix(1))
                                .font(.title2)
                                .foregroundStyle(.blue)
                        )
                    VStack(alignment: .leading) {
                        Text(user.fullName).font(.headline)
                        Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Button("Edit profile") { showingEditProfile = true }

                if userViewModel.isAuthenticated {
                    Button(role: .destructive) {
                        Task { await userViewModel.signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    Button {
                        showingAuth = true
                    } label: {
                        Label("Sign in / create account", systemImage: "person.badge.key")
                    }
                }
            }
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            if subscriptionService.effectivelyPremium {
                HStack {
                    Label("Last Post Premium", systemImage: "star.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }
                Link("Manage subscription",
                     destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .foregroundStyle(.blue)
            } else {
                HStack {
                    Label("Free plan", systemImage: "person.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("1 designated · 5 contacts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    paywallReason = ""
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text("Upgrade to Premium — \(subscriptionService.formattedPrice)/year")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.primary)

                Button("Restore purchase") {
                    Task { await subscriptionService.restore() }
                }
                .foregroundStyle(.secondary)
                .font(.footnote)
            }
        }
    }

    private var planningSection: some View {
        Section("Legacy planning") {
            // Important documents — premium
            Button {
                if subscriptionService.canUseLegacyPlanning {
                    showingDocuments = true
                } else {
                    paywallReason = "Important documents is a Last Post Premium feature."
                    showPaywall = true
                }
            } label: {
                HStack {
                    Label {
                        HStack {
                            Text("Important documents")
                            if !subscriptionService.canUseLegacyPlanning {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    } icon: {
                        Image(systemName: "doc.text.fill")
                    }
                    Spacer()
                    if subscriptionService.canUseLegacyPlanning, let user = userViewModel.currentUser {
                        let docs = user.importantDocuments
                        let done = docs.filter { $0.isComplete }.count
                        Text("\(done)/\(docs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)

            // Funeral wishes — premium
            Button {
                if subscriptionService.canUseLegacyPlanning {
                    showingFuneralWishes = true
                } else {
                    paywallReason = "Funeral wishes is a Last Post Premium feature."
                    showPaywall = true
                }
            } label: {
                HStack {
                    Label {
                        HStack {
                            Text("Funeral wishes")
                            if !subscriptionService.canUseLegacyPlanning {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    } icon: {
                        Image(systemName: "leaf.fill")
                    }
                    Spacer()
                    if subscriptionService.canUseLegacyPlanning,
                       userViewModel.currentUser?.funeralWishesData != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .foregroundStyle(.primary)

            // Life history — premium
            Button {
                if subscriptionService.canUseLegacyPlanning {
                    showingLifeHistory = true
                } else {
                    paywallReason = "Life history is a Last Post Premium feature."
                    showPaywall = true
                }
            } label: {
                HStack {
                    Label {
                        HStack {
                            Text("Life history")
                            if !subscriptionService.canUseLegacyPlanning {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            }
                        }
                    } icon: {
                        Image(systemName: "text.book.closed.fill")
                    }
                }
            }
            .foregroundStyle(.primary)

            // Digital assets — premium
            Button {
                if subscriptionService.canUseLegacyPlanning {
                    showingDigitalAssets = true
                } else {
                    paywallReason = "Digital assets is a Last Post Premium feature."
                    showPaywall = true
                }
            } label: {
                HStack {
                    Label {
                        HStack {
                            Text("Digital assets")
                            if !subscriptionService.canUseLegacyPlanning {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            }
                        }
                    } icon: {
                        Image(systemName: "briefcase.fill")
                    }
                    Spacer()
                    if subscriptionService.canUseLegacyPlanning {
                        let count = userViewModel.currentUser?.digitalAssets.count ?? 0
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .foregroundStyle(.primary)

            // Emergency card — free
            Button {
                showingEmergencyCard = true
            } label: {
                Label("Emergency card", systemImage: "cross.case.fill")
            }
            .foregroundStyle(.primary)

            Button {
                showingInstructionSheet = true
            } label: {
                Label("Emergency instruction sheet", systemImage: "doc.text.fill")
            }
            .foregroundStyle(.primary)
            .sheet(isPresented: $showingInstructionSheet) {
                if let user = userViewModel.currentUser {
                    let allContacts = (try? modelContext.fetch(FetchDescriptor<Contact>())) ?? []
                    EmergencyInstructionSheetView(user: user, contacts: allContacts)
                }
            }

            if !userViewModel.usersIAmDesignatedFor.isEmpty {
                Button {
                    isInDesignatedMode = true
                } label: {
                    Label("Switch to designated person mode", systemImage: "person.badge.key.fill")
                }
                .foregroundStyle(.blue)
            }
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            Picker("Verify contacts", selection: $notificationFrequency) {
                ForEach(frequencies, id: \.self) { Text($0).tag($0) }
            }

            // Wellness check — premium
            Button {
                if subscriptionService.canUseWelfareCheck {
                    showingLivenessCheck = true
                } else {
                    paywallReason = "Routine check-in is a Last Post Premium feature."
                    showPaywall = true
                }
            } label: {
                HStack {
                    Label {
                        HStack {
                            Text("Routine check-in")
                            if !subscriptionService.canUseWelfareCheck {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            }
                        }
                    } icon: {
                        Image(systemName: "heart.text.square.fill")
                    }
                    Spacer()
                    if subscriptionService.canUseWelfareCheck,
                       let user = userViewModel.currentUser,
                       user.livenessCheckEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .foregroundStyle(.primary)

            Button {
                showingCheckIn = true
            } label: {
                HStack {
                    Label("Annual check-in", systemImage: "calendar.badge.clock")
                    Spacer()
                    if let date = userViewModel.currentUser?.annualCheckInDate {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not set")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private var securityPrivacySection: some View {
        Section("Privacy & Security") {
            NavigationLink("Data & Privacy") { DataPrivacyView() }
            NavigationLink("Security settings") { SecuritySettingsView() }
        }
    }

    private var supportSection: some View {
        Section("Support") {
            Link("Help Center", destination: URL(string: "mailto:lastposthelp@gmail.com")!)
            Link("Contact support", destination: URL(string: "mailto:lastposthelp@gmail.com")!)
            Link("Privacy policy", destination: URL(string: "https://lastpost.app/privacy.html")!)
            Link("Terms of service", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
            LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
            Button("Disclaimer") { showingDisclaimer = true }
                .sheet(isPresented: $showingDisclaimer) { DisclaimerView() }
        }
    }

    private var debugSection: some View {
        Section {
            Toggle("Premium override (testing only)", isOn: $subscriptionService.debugOverridePremium)
                .tint(.purple)
            Text("Bypasses StoreKit so premium features can be tested without a subscription. Turn off before submitting to the App Store.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await fetchAndStoreSupabaseUUID() }
            } label: {
                Label("Fetch & store Supabase UUID", systemImage: "arrow.clockwise.circle")
                    .foregroundStyle(.orange)
            }
            if !debugUUIDStatus.isEmpty {
                Text(debugUUIDStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await forceSyncAllLegacyData() }
            } label: {
                Label("Force sync legacy data to Supabase", systemImage: "icloud.and.arrow.up")
                    .foregroundStyle(.orange)
            }
            if !debugSyncStatus.isEmpty {
                Text(debugSyncStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Developer")
        }
    }

    private func forceSyncAllLegacyData() async {
        guard let user = userViewModel.currentUser else {
            debugSyncStatus = "No local user"
            return
        }
        debugSyncStatus = "Syncing…"
        var synced: [String] = []

        // Funeral wishes (stored on User SwiftData model)
        if let data = user.funeralWishesData {
            await SupabaseService.shared.syncLegacyField(column: "funeral_wishes_data", data: data)
            synced.append("funeral wishes")
        }

        // Important documents (stored on User SwiftData model)
        if let data = user.importantDocumentsData {
            await SupabaseService.shared.syncLegacyField(column: "important_documents_data", data: data)
            synced.append("documents")
        }

        // Digital assets (stored on User SwiftData model)
        if let data = user.digitalAssetsData {
            await SupabaseService.shared.syncLegacyField(column: "digital_assets_data", data: data)
            synced.append("digital assets")
        }

        // Life history (stored in UserDefaults keyed by local user UUID)
        let history = LifeHistory.load(forUserId: user.id)
        if history.hasAnyContent, let data = try? JSONEncoder().encode(history) {
            await SupabaseService.shared.syncLegacyField(column: "life_history_data", data: data)
            synced.append("life history")
        }

        debugSyncStatus = synced.isEmpty ? "Nothing to sync" : "Synced: \(synced.joined(separator: ", "))"
    }

    private func fetchAndStoreSupabaseUUID() async {
        guard let email = userViewModel.currentUser?.email else {
            debugUUIDStatus = "No local user email found"
            return
        }
        debugUUIDStatus = "Looking up \(email)…"

        guard let url = URL(string: "https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/get-profile-id") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5cHpiYnVwenVhdWtka2plZ2h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU5NDU0NjYsImV4cCI6MjA2MTUyMTQ2Nn0.2aE9nAGkEOI4hHqkHBgA6DHMbj1AHU6FxAMmN3okYJw", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email])

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idString = json["id"] as? String,
              let uuid = UUID(uuidString: idString) else {
            debugUUIDStatus = "Failed — check console"
            return
        }

        UserDefaults.standard.set(uuid.uuidString, forKey: "currentSupabaseUserId")
        SupabaseService.shared.supabaseUserId = uuid
        SupabaseService.shared.isAuthenticated = true
        userViewModel.loadUsersIAmDesignatedFor()
        debugUUIDStatus = "Stored: \(uuid.uuidString)"
    }

    private var dangerSection: some View {
        Section {
            Button("Delete account", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }

    // MARK: - Delete account

    private func deleteAccount() {
        guard let user = userViewModel.currentUser else { return }

        Task {
            // 1. Delete from Supabase (auth user + all DB rows) if signed in
            if SupabaseService.shared.isAuthenticated {
                let success = await SupabaseService.shared.deleteAccount()
                if !success {
                    await MainActor.run { showingDeleteError = true }
                    return
                }
            }

            // 2. Wipe local SwiftData
            await MainActor.run {
                do {
                    // Delete designated person shadow records for this user
                    let userId: UUID = user.id
                    let dpDescriptor = FetchDescriptor<DesignatedPerson>(
                        predicate: #Predicate { $0.linkedUserId == userId }
                    )
                    let dps = (try? modelContext.fetch(dpDescriptor)) ?? []
                    for dp in dps { modelContext.delete(dp) }

                    // Delete death notifications
                    let dnDescriptor = FetchDescriptor<DeathNotification>(
                        predicate: #Predicate { $0.deceasedUserId == userId }
                    )
                    let notifications = (try? modelContext.fetch(dnDescriptor)) ?? []
                    for n in notifications { modelContext.delete(n) }

                    modelContext.delete(user)
                    try modelContext.save()

                    // 3. Reset all flags so onboarding/auth flow restarts cleanly
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    UserDefaults.standard.set(false, forKey: "hasSeenAuthPrompt")
                    UserDefaults.standard.set(false, forKey: "isInDesignatedMode")
                } catch {
                    showingDeleteError = true
                }
            }
        }
    }
}

// MARK: - Edit Profile

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userViewModel: UserViewModel

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal information") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }
                Section("Contact information") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        userViewModel.updateUser(
                            firstName: firstName, lastName: lastName,
                            email: email, phoneNumber: phoneNumber
                        )
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let user = userViewModel.currentUser {
                    firstName = user.firstName; lastName = user.lastName
                    email = user.email; phoneNumber = user.phoneNumber
                }
            }
        }
    }
}

// MARK: - Data & Privacy

struct DataPrivacyView: View {
    @EnvironmentObject var userViewModel: UserViewModel

    var body: some View {
        List {
            Section {
                Text("Your data is stored securely on your device. We never share your personal information with third parties.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Your data") {
                Button("Export my data") { exportData() }
                Button("Download contact list") { exportContactList() }
            }
        }
        .navigationTitle("Data & Privacy")
    }

    private func exportData() {
        guard let user = userViewModel.currentUser else { return }
        var lines = ["=== Last Post Data Export ===", ""]
        lines.append("Name: \(user.fullName)")
        lines.append("Email: \(user.email)")
        lines.append("Phone: \(user.phoneNumber)")
        lines.append("Created: \(user.createdAt.formatted())")
        lines.append("")
        lines.append("--- Contacts (\(user.contacts.count)) ---")
        for c in user.contacts {
            lines.append("\(c.fullName) | \(c.relationship) | \(c.email) | \(c.phoneNumber)")
        }
        lines.append("")
        lines.append("--- Designated persons (\(user.designatedPersons.count)) ---")
        for p in user.designatedPersons {
            lines.append("\(p.fullName) | \(p.relationship) | \(p.email)")
        }
        share(items: [lines.joined(separator: "\n")])
    }

    private func exportContactList() {
        guard let user = userViewModel.currentUser else { return }
        var rows = ["Name,Email,Phone,Relationship,Status"]
        for c in user.contacts {
            let status = c.invitationAccepted ? "Confirmed" : c.invitationSent ? "Pending" : "Not Invited"
            rows.append("\"\(c.fullName)\",\"\(c.email)\",\"\(c.phoneNumber)\",\"\(c.relationship)\",\"\(status)\"")
        }
        share(items: [rows.joined(separator: "\n")])
    }

    private func share(items: [Any]) {
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Security Settings

struct SecuritySettingsView: View {
    @AppStorage("useBiometrics") private var useBiometrics = true
    @AppStorage("requirePINForNotification") private var requirePINForNotification = true
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var showingBiometricError = false
    @State private var biometricErrorMessage = ""

    var body: some View {
        List {
            Section("App lock") {
                Toggle("Lock app on background", isOn: $appLockEnabled)
                Text("When enabled, Face ID or Touch ID is required every time you open the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Authentication") {
                Toggle("Use Face ID / Touch ID", isOn: $useBiometrics)
                    .onChange(of: useBiometrics) { _, enabled in
                        if enabled {
                            let context = LAContext()
                            var error: NSError?
                            if !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                                useBiometrics = false
                                biometricErrorMessage = error?.localizedDescription ?? "Face ID / Touch ID is not available."
                                showingBiometricError = true
                            }
                        }
                    }
                Toggle("Require authentication for notifications", isOn: $requirePINForNotification)
            }
            if useBiometrics {
                Section {
                    Label("Biometric authentication is active", systemImage: "faceid")
                        .font(.caption).foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Security")
        .alert("Biometrics unavailable", isPresented: $showingBiometricError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(biometricErrorMessage)
        }
    }
}

// MARK: - Biometric Auth Helper

struct BiometricAuthHelper {
    static func authenticate(reason: String) async -> Bool {
        guard UserDefaults.standard.bool(forKey: "requirePINForNotification") else { return true }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
