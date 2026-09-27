//
//  PaywallView.swift
//  FinalFarewell
//
//  Full-screen paywall shown when a user tries to access a premium feature.
//  Pass a `reason` string to highlight why they're seeing the paywall.
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionService: SubscriptionService

    var reason: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    if !reason.isEmpty { reasonBanner }
                    featuresSection
                    purchaseSection
                    footerSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .alert("Error", isPresented: .init(
                get: { subscriptionService.errorMessage != nil },
                set: { if !$0 { subscriptionService.errorMessage = nil } }
            )) {
                Button("OK") { subscriptionService.errorMessage = nil }
            } message: {
                Text(subscriptionService.errorMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.25, blue: 0.1), Color(red: 0.15, green: 0.35, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)

            VStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.yellow)
                Text("Last Post Premium")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text("Everything you need to plan ahead.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Reason banner

    private var reasonBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's included")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                featureRow(icon: "person.2.fill", color: .purple,
                    title: "Unlimited designated persons",
                    subtitle: "Free tier: 1 person",
                    isPremium: true)
                featureRow(icon: "person.crop.circle.fill.badge.plus", color: .blue,
                    title: "Unlimited contacts",
                    subtitle: "Free tier: up to 5 contacts",
                    isPremium: true)
                featureRow(icon: "heart.fill", color: .red,
                    title: "Routine check-in",
                    subtitle: "Scheduled check-ins so loved ones know all is well",
                    isPremium: true)
                featureRow(icon: "doc.text.fill", color: .green,
                    title: "Funeral wishes",
                    subtitle: "Record your preferences in detail",
                    isPremium: true)
                featureRow(icon: "checklist", color: .teal,
                    title: "Important documents",
                    subtitle: "Checklist shared with your designated person",
                    isPremium: true)
                featureRow(icon: "clock.fill", color: .orange,
                    title: "Life history",
                    subtitle: "Leave your story for those you love",
                    isPremium: true)
                featureRow(icon: "iphone.and.arrow.forward", color: .indigo,
                    title: "Digital asset inventory",
                    subtitle: "Accounts, subscriptions, and passwords",
                    isPremium: true)
                featureRow(icon: "bell.badge.fill", color: .gray,
                    title: "Death notification",
                    subtitle: "Always free — the core feature",
                    isPremium: false)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, color: Color, title: String, subtitle: String, isPremium: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isPremium {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 10)
        Divider()
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await subscriptionService.purchase() }
            } label: {
                if subscriptionService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    VStack(spacing: 4) {
                        Text("Start Premium")
                            .font(.headline)
                        Text("\(subscriptionService.formattedPrice) per year")
                            .font(.caption)
                            .opacity(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .background(Color(red: 0.1, green: 0.3, blue: 0.1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(subscriptionService.isLoading)

            Button("Restore purchase") {
                Task { await subscriptionService.restore() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("Subscription auto-renews annually. Cancel any time in Settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://lastpost.app/privacy")!)
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .padding(.bottom, 8)
    }
}
