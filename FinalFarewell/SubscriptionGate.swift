//
//  SubscriptionGate.swift
//  FinalFarewell
//
//  Reusable helpers for gating premium features.
//  Drop-in ViewModifier + convenience View extension.
//

import SwiftUI

// MARK: - Paywall trigger modifier
// Usage:
//   Button("Add Contact") { addContact() }
//       .premiumGate(
//           isActive: !subscriptionService.canAddContact(currentCount: contacts.count),
//           reason: "You've reached the 5-contact free limit."
//       )

struct PremiumGateModifier: ViewModifier {
    @EnvironmentObject var subscriptionService: SubscriptionService
    let isActive: Bool
    let reason: String
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture().onEnded {
                if isActive { showPaywall = true }
            })
            .disabled(false)                    // keep tappable so gate can fire
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: reason)
                    .environmentObject(subscriptionService)
            }
    }
}

extension View {
    func premiumGate(isActive: Bool, reason: String) -> some View {
        modifier(PremiumGateModifier(isActive: isActive, reason: reason))
    }
}

// MARK: - Premium feature row
// Drop-in replacement for a NavigationLink / Button when a whole screen is premium-only.
// Example:
//   PremiumFeatureRow(
//       icon: "heart.fill",
//       title: "Welfare Check",
//       reason: "Welfare Check is a premium feature.",
//       isPremium: !subscriptionService.canUseWelfareCheck
//   ) {
//       WelfareCheckView()
//   }

struct PremiumFeatureRow<Destination: View>: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    let icon: String
    let title: String
    let reason: String
    let isPremium: Bool
    @ViewBuilder let destination: () -> Destination
    @State private var showPaywall = false

    var body: some View {
        Group {
            if isPremium {
                Button {
                    showPaywall = true
                } label: {
                    Label {
                        HStack {
                            Text(title)
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    } icon: {
                        Image(systemName: icon)
                    }
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView(reason: reason)
                        .environmentObject(subscriptionService)
                }
            } else {
                NavigationLink {
                    destination()
                } label: {
                    Label(title, systemImage: icon)
                }
            }
        }
    }
}
