//
//  FuneralWishesView.swift
//  FinalFarewell
//
//  Lets the user record their own funeral preferences in advance.
//  Stored as JSON on User via a funeralWishesData field (add to User.swift).
//  The designated person receives access to these after confirmation.
//

import SwiftUI

// MARK: - Funeral wishes model

struct FuneralWishes: Codable {
    var dispositionType: DispositionType = .noPreference
    var serviceType: ServiceType = .noPreference
    var locationWishes: String = ""
    var musicWishes: String = ""
    var readingWishes: String = ""
    var donationCharity: String = ""
    var donationInLieuOfFlowers: Bool = false
    var flowerPreferences: String = ""
    var dressCode: String = ""
    var additionalWishes: String = ""
    var isPrivate: Bool = false

    enum DispositionType: String, Codable, CaseIterable {
        case noPreference = "No preference"
        case burial = "Burial"
        case cremation = "Cremation"
        case naturalBurial = "Natural/green burial"
        case donation = "Body donation to science"
        case other = "Other"
    }

    enum ServiceType: String, Codable, CaseIterable {
        case noPreference = "No preference"
        case religious = "Religious service"
        case secular = "Secular/civil service"
        case celebration = "Celebration of life"
        case graveside = "Graveside only"
        case privateOnly = "Private — family only"
        case noService = "No service"
    }
}

// MARK: - View

struct FuneralWishesView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var wishes = FuneralWishes()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Your wishes will be shared with your designated person after they confirm your death notification. They are not shared with your contacts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Disposition") {
                    Picker("Burial or cremation", selection: $wishes.dispositionType) {
                        ForEach(FuneralWishes.DispositionType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Service") {
                    Picker("Service type", selection: $wishes.serviceType) {
                        ForEach(FuneralWishes.ServiceType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Location wishes", text: $wishes.locationWishes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Music and readings") {
                    TextField("Music preferences", text: $wishes.musicWishes, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Readings or poems", text: $wishes.readingWishes, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Dress code", text: $wishes.dressCode)
                }

                Section("Flowers and donations") {
                    Toggle("Donations in lieu of flowers", isOn: $wishes.donationInLieuOfFlowers)
                    if wishes.donationInLieuOfFlowers {
                        TextField("Charity name or cause", text: $wishes.donationCharity)
                    } else {
                        TextField("Flower preferences", text: $wishes.flowerPreferences)
                    }
                }

                Section("Additional wishes") {
                    TextField("Anything else you'd like...", text: $wishes.additionalWishes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Toggle("Keep these wishes private", isOn: $wishes.isPrivate)
                    Text("If private, only your designated person will see these — not your contacts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }
            .navigationTitle("Funeral wishes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let data = userViewModel.currentUser?.funeralWishesData,
              let decoded = try? JSONDecoder().decode(FuneralWishes.self, from: data)
        else { return }
        wishes = decoded
    }

    private func save() {
        let encoded = try? JSONEncoder().encode(wishes)
        userViewModel.currentUser?.funeralWishesData = encoded
        if let encoded {
            Task { await SupabaseService.shared.syncLegacyField(column: "funeral_wishes_data", data: encoded) }
        }
    }
}
