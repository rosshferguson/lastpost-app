//
//  DesignatedLegacyView.swift
//  Last Post
//
//  Read-only view of the owner's legacy data, shown to the designated
//  person after the death notification has been confirmed.
//  Data is fetched from Supabase via the get-legacy-data edge function.
//

import SwiftUI

struct DesignatedLegacyView: View {
    let ownerName: String
    let ownerId: UUID

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var funeralWishes: FuneralWishes?
    @State private var documents: [DocumentNote] = []
    @State private var digitalAssets: [DigitalAsset] = []
    @State private var lifeHistory: LifeHistory?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading legacy information…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let wishes = funeralWishes {
                            funeralWishesSection(wishes)
                        }
                        if !documents.isEmpty {
                            documentsSection
                        }
                        if !digitalAssets.isEmpty {
                            digitalAssetsSection
                        }
                        if let history = lifeHistory, history.hasAnyContent {
                            lifeHistorySection(history)
                        }
                    }
                }
            }
            .navigationTitle("\(ownerName)'s legacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadData() }
        }
    }

    // MARK: - Sections

    private func funeralWishesSection(_ w: FuneralWishes) -> some View {
        Section {
            if w.dispositionType != .noPreference {
                LegacyRow(label: "Burial / cremation", value: w.dispositionType.rawValue)
            }
            if w.serviceType != .noPreference {
                LegacyRow(label: "Service type", value: w.serviceType.rawValue)
            }
            if !w.locationWishes.isEmpty {
                LegacyRow(label: "Location", value: w.locationWishes)
            }
            if !w.musicWishes.isEmpty {
                LegacyRow(label: "Music", value: w.musicWishes)
            }
            if !w.readingWishes.isEmpty {
                LegacyRow(label: "Readings", value: w.readingWishes)
            }
            if !w.dressCode.isEmpty {
                LegacyRow(label: "Dress code", value: w.dressCode)
            }
            if w.donationInLieuOfFlowers {
                LegacyRow(label: "Donations in lieu of flowers", value: w.donationCharity.isEmpty ? "Yes" : w.donationCharity)
            } else if !w.flowerPreferences.isEmpty {
                LegacyRow(label: "Flowers", value: w.flowerPreferences)
            }
            if !w.additionalWishes.isEmpty {
                LegacyRow(label: "Additional wishes", value: w.additionalWishes)
            }
        } header: {
            Label("Funeral wishes", systemImage: "heart.text.square")
        }
    }

    private var documentsSection: some View {
        let categories = ["Legal", "Finance", "Funeral", "Property", "Digital", "Other"]
        let grouped = categories.compactMap { cat -> (String, [DocumentNote])? in
            let items = documents.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
        return ForEach(grouped, id: \.0) { category, items in
            Section {
                ForEach(items) { doc in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: doc.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(doc.isComplete ? .green : .secondary)
                                .font(.system(size: 16))
                            Text(doc.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        if !doc.notes.isEmpty {
                            Text(doc.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Label("Documents — \(category)", systemImage: "folder")
            }
        }
    }

    private var digitalAssetsSection: some View {
        let categories = DigitalAsset.DigitalAssetCategory.allCases.map(\.rawValue)
        let grouped = categories.compactMap { cat -> (String, [DigitalAsset])? in
            let items = digitalAssets.filter { $0.category.rawValue == cat }
            return items.isEmpty ? nil : (cat, items)
        }
        return ForEach(grouped, id: \.0) { category, items in
            Section {
                ForEach(items) { asset in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Image(systemName: asset.category.systemImage)
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text(asset.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        if !asset.institution.isEmpty {
                            Text(asset.institution)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 30)
                        }
                        if !asset.accountHint.isEmpty {
                            Text(asset.accountHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 30)
                        }
                        if !asset.accessNotes.isEmpty {
                            Text("Access: \(asset.accessNotes)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 30)
                        }
                        if !asset.locationNotes.isEmpty {
                            Text("Location: \(asset.locationNotes)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 30)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Label("Assets — \(category)", systemImage: "briefcase")
            }
        }
    }

    private func lifeHistorySection(_ h: LifeHistory) -> some View {
        let prompts: [(String, String)] = [
            ("Origins",           h.origins),
            ("Family",            h.family),
            ("Work & career",     h.career),
            ("Passions & hobbies",h.passions),
            ("Memorable moments", h.memorablemoments),
            ("Their legacy",      h.legacy),
            ("Final thoughts",    h.finalThoughts),
        ].filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return Section {
            ForEach(prompts, id: \.0) { title, text in
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Life history", systemImage: "text.book.closed")
        }
    }

    // MARK: - Data loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        guard let payload = await SupabaseService.shared.fetchLegacyData(forOwnerId: ownerId) else {
            errorMessage = "Could not load legacy information. Please check your connection and try again."
            isLoading = false
            return
        }

        if let data = payload.funeralWishesData {
            funeralWishes = try? JSONDecoder().decode(FuneralWishes.self, from: data)
        }
        if let data = payload.importantDocumentsData {
            documents = (try? JSONDecoder().decode([DocumentNote].self, from: data)) ?? []
        }
        if let data = payload.digitalAssetsData {
            digitalAssets = (try? JSONDecoder().decode([DigitalAsset].self, from: data)) ?? []
        }
        if let data = payload.lifeHistoryData {
            lifeHistory = try? JSONDecoder().decode(LifeHistory.self, from: data)
        }

        isLoading = false
    }
}

// MARK: - Helper row

private struct LegacyRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
