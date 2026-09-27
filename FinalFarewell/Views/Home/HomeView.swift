//
//  HomeView.swift
//  FinalFarewell
//
//  Redesigned home screen:
//  - Taller hero with user avatar initial and readiness score overlay
//  - Removed redundant stats row (info already in readiness card)
//  - Cleaner quick actions grid
//  - Improved card spacing and visual hierarchy
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var contactsViewModel: ContactsViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Binding var selectedTab: Int

    @AppStorage("isInDesignatedMode") private var isInDesignatedMode = false
    @ObservedObject private var supabaseService = SupabaseService.shared

    @State private var showingNotificationPreview = false
    @State private var resendEmailSent = false
    @State private var resendEmailError = false
    @State private var showingConsentOverview = false
    @State private var showPaywall = false
    @State private var showingLegacyPlanning = false
    @State private var showingWellnessCheck = false
    @AppStorage("lastWelfareCheckSentAt") private var lastWelfareCheckSentAt: Double = 0
    @State private var showingWelfareCheckConfirm = false

    private static let welfareCheckCooldown: TimeInterval = 6 * 60 * 60 // 6 hours

    private var welfareCheckSent: Bool {
        guard lastWelfareCheckSentAt > 0 else { return false }
        return Date().timeIntervalSince1970 - lastWelfareCheckSentAt < Self.welfareCheckCooldown
    }

    private var welfareCheckCooldownLabel: String {
        guard welfareCheckSent else { return "" }
        let remaining = Self.welfareCheckCooldown - (Date().timeIntervalSince1970 - lastWelfareCheckSentAt)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "Can resend in \(hours)h \(minutes)m"
        } else {
            return "Can resend in \(minutes)m"
        }
    }
    @State private var showingCheckInConfirm = false
    @State private var checkInDone = false

    var readinessScore: ReadinessScore? {
        guard let user = userViewModel.currentUser else { return nil }
        return ReadinessScore(user: user, contacts: contactsViewModel.contacts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader

                    VStack(spacing: 12) {
                        if !supabaseService.isEmailConfirmed {
                            emailVerificationBanner
                        }

                        if let score = readinessScore {
                            ReadinessScoreView(score: score)
                        }

                        if !userViewModel.usersIAmDesignatedFor.isEmpty {
                            designatedModeCard
                        }

                        SetupChecklistView(selectedTab: $selectedTab)

                        if !contactsViewModel.contactsNeedingVerification.isEmpty {
                            verificationAlert
                        }

                        if let user = userViewModel.currentUser,
                           user.designatedPersons.contains(where: { $0.needsReconfirmation }) {
                            reconfirmationAlert
                        }

                        if !contactsViewModel.contacts.isEmpty {
                            consentOverviewCard
                        }

                        if !subscriptionService.effectivelyPremium {
                            premiumUpgradeCard
                        }

                        welfareCheckCard
                        quickActionsSection

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNotificationPreview) {
                if let user = userViewModel.currentUser {
                    NotificationPreviewView(user: user)
                }
            }
            .sheet(isPresented: $showingConsentOverview) { ContactConsentView() }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(subscriptionService)
            }
            .sheet(isPresented: $showingLegacyPlanning) { LegacyPlanningSheet() }
            .sheet(isPresented: $showingWellnessCheck) { LivenessCheckSettingsView() }
            .alert("Confirm check-in", isPresented: $showingCheckInConfirm) {
                Button("I'm well") {
                    guard let user = userViewModel.currentUser else { return }
                    let next = Calendar.current.date(
                        byAdding: .day, value: user.livenessCheckFrequencyDays, to: Date()
                    ) ?? Date()
                    user.lastLivenessCheckAt = Date()
                    user.nextLivenessCheckAt = next
                    userViewModel.saveContext()
                    Task {
                        await SupabaseService.shared.updateLivenessCheckSchedule(
                            enabled: user.livenessCheckEnabled,
                            frequencyDays: user.livenessCheckFrequencyDays,
                            nextCheckAt: next
                        )
                    }
                    checkInDone = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This confirms you're well and resets your check-in timer.")
            }
            .alert("Request wellness check?", isPresented: $showingWelfareCheckConfirm) {
                Button("Send alert") {
                    Task {
                        await SupabaseService.shared.requestWelfareCheck(
                            ownerName: userViewModel.currentUser?.fullName ?? "Someone"
                        )
                        lastWelfareCheckSentAt = Date().timeIntervalSince1970
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will send a message to your designated person asking them to check in with you. Use this if you need someone to reach out.")
            }
        }
    }

    // MARK: - Email verification banner

    private var emailVerificationBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verify your email address")
                        .font(.subheadline).fontWeight(.semibold)
                    Text("Until verified, notifications may not be sent if you pass away.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if resendEmailSent {
                Label("Email sent — check your inbox", systemImage: "checkmark.circle.fill")
                    .font(.caption).fontWeight(.medium).foregroundStyle(.green)
            } else {
                Button {
                    Task {
                        do {
                            try await SupabaseService.shared.resendConfirmationEmail()
                            await MainActor.run { resendEmailSent = true }
                        } catch {
                            await MainActor.run { resendEmailError = true }
                        }
                    }
                } label: {
                    Text("Resend confirmation email")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
        .alert("Couldn't send email", isPresented: $resendEmailError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please check your connection and try again.")
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.1, blue: 0.65),
                    Color(red: 0.48, green: 0.25, blue: 0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 210)

            // Subtle arc overlay for depth
            GeometryReader { geo in
                Ellipse()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: geo.size.width * 1.4, height: 120)
                    .offset(x: -geo.size.width * 0.2, y: 60)
            }
            .frame(height: 210)

            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(userViewModel.currentUser.map { "Hello, \($0.firstName)" } ?? "Welcome")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    Text(heroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                // Avatar with readiness ring
                if let score = readinessScore, let user = userViewModel.currentUser {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: CGFloat(score.percentage) / 100)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: score.percentage)

                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 52, height: 52)

                        Text(user.firstName.prefix(1) + user.lastName.prefix(1))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
    }

    private var heroSubtitle: String {
        let count = contactsViewModel.contacts.count
        if count == 0 { return "Let's get your legacy in order" }
        if count == 1 { return "1 person will be notified" }
        return "\(count) people will be notified"
    }

    // MARK: - Alerts

    private var verificationAlert: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(contactsViewModel.contactsNeedingVerification.count) contact\(contactsViewModel.contactsNeedingVerification.count == 1 ? "" : "s") need reverification")
                    .font(.subheadline).fontWeight(.medium)
                Text("Tap to review")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink {
                ContactListView(showOnlyUnverified: true)
            } label: {
                Text("Review")
                    .font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }

    private var reconfirmationAlert: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.key.fill")
                .foregroundStyle(.red)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text("Designated person needs to reconfirm")
                    .font(.subheadline).fontWeight(.medium)
                Text("Go to the Designated tab to send a reminder")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color.red.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.15), lineWidth: 1))
        .onTapGesture { selectedTab = 2 }
    }

    // MARK: - Consent card

    private var consentOverviewCard: some View {
        let all = contactsViewModel.contacts
        let ready = all.filter { $0.invitationAccepted && !$0.needsVerification }.count
        let total = all.count

        return Button { showingConsentOverview = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 17))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Consent overview")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                    Text("\(ready) of \(total) contacts confirmed")
                        .font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: Double(ready), total: Double(max(total, 1)))
                        .tint(ready == total ? .green : .blue)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Premium card

    private var premiumUpgradeCard: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 17))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Premium")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                    Text("Unlimited contacts, routine check-in & legacy planning")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.07), Color.orange.opacity(0.07)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Designated mode card

    private var designatedModeCard: some View {
        Button { isInDesignatedMode = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.badge.key.fill")
                        .foregroundStyle(.purple)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("You're a designated person")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                    Text("Tap to switch to designated person mode")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.purple)
                    .font(.system(size: 20))
            }
            .padding(14)
            .background(Color.purple.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Welfare check card

    private var welfareCheckCard: some View {
        Button {
            showingWelfareCheckConfirm = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.teal)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(welfareCheckSent ? "Wellness check sent" : "Request wellness check")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(welfareCheckSent ? .teal : .primary)
                    Text(welfareCheckSent
                         ? welfareCheckCooldownLabel
                         : "Ask your designated person to check in with you")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !welfareCheckSent {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(
                welfareCheckSent
                    ? Color.teal.opacity(0.08)
                    : Color(.secondarySystemGroupedBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(welfareCheckSent ? Color.teal.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(welfareCheckSent)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick actions")
                .font(.headline)
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ActionCard(icon: "person.badge.plus",    title: "Add contact",     color: .blue)   { selectedTab = 1 }
                ActionCard(icon: "checkmark.shield.fill", title: "Check in",       color: .green)  { showingCheckInConfirm = true }
                ActionCard(icon: "scroll.fill",          title: "Legacy planning", color: .indigo) {
                    if subscriptionService.isPremium { showingLegacyPlanning = true }
                    else { showPaywall = true }
                }
                ActionCard(icon: "heart.text.clipboard", title: "Routine check-in",  color: .pink) {
                    if subscriptionService.isPremium { showingWellnessCheck = true }
                    else { showPaywall = true }
                }
                ActionCard(icon: "photo.badge.plus",     title: "Add memory",      color: .orange) { selectedTab = 3 }
                ActionCard(icon: "eye.fill",             title: "Preview message", color: .teal)   { showingNotificationPreview = true }
            }
        }
    }
}

// MARK: - Supporting views

struct ActionCard: View {
    let icon: String; let title: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.13))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct StatPill: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.title).fontWeight(.bold).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Legacy aliases so other files that reference these still compile
struct SlimActionCard: View {
    let icon: String; let title: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
                }
                Text(title).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).fontWeight(.semibold).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 11).frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View { StatPill(value: value, label: title, color: color) }
}

struct QuickActionButton: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View { ActionCard(icon: icon, title: title, color: color, action: action) }
}
