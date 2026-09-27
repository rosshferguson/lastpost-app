//
//  SubscriptionService.swift
//  FinalFarewell
//
//  StoreKit 2 subscription manager.
//  Product ID: RF.FinalFarewell.premium.annual
//

import Combine
import StoreKit
import SwiftUI

@MainActor
class SubscriptionService: ObservableObject {

    static let premiumProductId   = "RF.FinalFarewell.premium.annual"
    static let freeContactLimit   = 5
    static let freeDesignatedPersonLimit = 1

    @Published var isPremium  = false
    @Published var products: [Product] = []
    @Published var isLoading  = false
    @Published var errorMessage: String?

    /// Debug only — bypasses StoreKit so premium features can be tested without a subscription.
    @Published var debugOverridePremium: Bool = UserDefaults.standard.bool(forKey: "debug_override_premium") {
        didSet { UserDefaults.standard.set(debugOverridePremium, forKey: "debug_override_premium") }
    }

    var effectivelyPremium: Bool { isPremium || debugOverridePremium }

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Limits

    var canUseWelfareCheck:   Bool { effectivelyPremium }
    var canUseLegacyPlanning: Bool { effectivelyPremium }

    func canAddContact(currentCount: Int) -> Bool {
        effectivelyPremium || currentCount < Self.freeContactLimit
    }

    func canAddDesignatedPerson(currentCount: Int) -> Bool {
        effectivelyPremium || currentCount < Self.freeDesignatedPersonLimit
    }

    var formattedPrice: String {
        products.first?.displayPrice ?? "£19.99"
    }

    // MARK: - Load products

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.premiumProductId])
        } catch {
            errorMessage = "Could not load subscription options."
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase() async -> Bool {
        guard let product = products.first else {
            errorMessage = "No subscription product available."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isPremium = true
                    return true
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        return false
    }

    // MARK: - Restore

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshStatus()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Refresh status

    func refreshStatus() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.premiumProductId,
               transaction.revocationDate == nil {
                hasPremium = true
            }
        }
        isPremium = hasPremium
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Error> {
        // Use a non-detached Task so it inherits @MainActor — no need for
        // MainActor.run or weak self capture warnings in Swift 6.
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if transaction.productID == SubscriptionService.premiumProductId,
                       transaction.revocationDate == nil {
                        self?.isPremium = true
                    } else {
                        self?.isPremium = false
                    }
                    await transaction.finish()
                }
            }
        }
    }
}
