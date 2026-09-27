//
//  AddressBookMatchService.swift
//  FinalFarewell
//
//  Checks whether a given Contact (by email or phone) also exists in the
//  user's device address book. Used to show an "In your contacts" badge
//  on ContactRow, helping the user spot which entries were manually typed
//  vs already in their phone, and catch potential duplicates.
//
//  Requires NSContactsUsageDescription in Info.plist (already required by
//  ContactImportView's CNContactPickerViewController, though the picker
//  itself doesn't need the permission — direct CNContactStore queries do).
//

import Foundation
import Contacts
import Combine
@MainActor
class AddressBookMatchService: ObservableObject {
    static let shared = AddressBookMatchService()

    /// Cached sets of normalised emails and phone numbers from the device
    /// address book, built once per session and refreshed on demand.
    private var knownEmails: Set<String> = []
    private var knownPhones: Set<String> = []
    private var hasLoaded = false
    private var authorizationDenied = false

    private init() {}

    /// Call once (e.g. on ContactListView appear) to build the lookup sets.
    /// Safe to call repeatedly — only does work once per session unless
    /// refresh() is called explicitly.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized:
            await loadAddressBook(using: store)
        case .notDetermined:
            do {
                let granted = try await store.requestAccess(for: .contacts)
                if granted {
                    await loadAddressBook(using: store)
                } else {
                    authorizationDenied = true
                }
            } catch {
                authorizationDenied = true
            }
        default:
            authorizationDenied = true
        }

        hasLoaded = true
    }

    private func loadAddressBook(using store: CNContactStore) async {
        let keys = [CNContactEmailAddressesKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var emails: Set<String> = []
        var phones: Set<String> = []

        do {
            try store.enumerateContacts(with: request) { cnContact, _ in
                for email in cnContact.emailAddresses {
                    emails.insert(Self.normaliseEmail(email.value as String))
                }
                for phone in cnContact.phoneNumbers {
                    phones.insert(Self.normalisePhone(phone.value.stringValue))
                }
            }
            knownEmails = emails
            knownPhones = phones
        } catch {
            // Leave caches empty — matching will simply return false
        }
    }

    /// Returns true if the given contact's email or phone matches an entry
    /// already in the device address book.
    func isInAddressBook(email: String, phone: String) -> Bool {
        guard hasLoaded, !authorizationDenied else { return false }

        if !email.isEmpty, knownEmails.contains(Self.normaliseEmail(email)) {
            return true
        }
        if !phone.isEmpty, knownPhones.contains(Self.normalisePhone(phone)) {
            return true
        }
        return false
    }

    // MARK: - Normalisation

    private static func normaliseEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Strips everything except digits so formatting differences
    /// (spaces, dashes, country codes with/without +) don't cause false negatives.
    /// Compares the last 9 digits, which is enough to match most numbers
    /// reliably without over-matching short numbers.
    private static func normalisePhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        return String(digits.suffix(9))
    }
}
