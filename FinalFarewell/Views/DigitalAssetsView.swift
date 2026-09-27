//
//  DigitalAssetsView.swift
//  Last Post
//

import SwiftUI

struct DigitalAssetsView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var showingAddSheet = false
    @State private var editingAsset: DigitalAsset? = nil

    var assets: [DigitalAsset] {
        userViewModel.currentUser?.digitalAssets ?? []
    }

    var grouped: [(String, [DigitalAsset])] {
        let categories = DigitalAsset.DigitalAssetCategory.allCases.map(\.rawValue)
        let dict = Dictionary(grouping: assets, by: { $0.category.rawValue })
        return categories.compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        List {
            if assets.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("No assets recorded yet")
                            .font(.headline)
                        Text("Add bank accounts, investments, subscriptions, and other assets so your designated person knows what exists and where to find it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(grouped, id: \.0) { category, items in
                    Section(category) {
                        ForEach(items) { asset in
                            AssetRow(asset: asset)
                                .contentShape(Rectangle())
                                .onTapGesture { editingAsset = asset }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteAsset(asset)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }

            Section {
                Text("This information is stored only on your device. It is never uploaded or shared unless you explicitly share it with your designated person.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Digital Assets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditAssetView(existingAsset: nil) { newAsset in
                saveAsset(newAsset)
            }
        }
        .sheet(item: $editingAsset) { asset in
            AddEditAssetView(existingAsset: asset) { updated in
                updateAsset(updated)
                editingAsset = nil
            }
        }
    }

    private func saveAsset(_ asset: DigitalAsset) {
        guard let user = userViewModel.currentUser else { return }
        var list = user.digitalAssets
        list.append(asset)
        user.digitalAssets = list
        userViewModel.saveContext()
        syncAssets()
    }

    private func updateAsset(_ asset: DigitalAsset) {
        guard let user = userViewModel.currentUser else { return }
        var list = user.digitalAssets
        if let idx = list.firstIndex(where: { $0.id == asset.id }) {
            list[idx] = asset
        }
        user.digitalAssets = list
        userViewModel.saveContext()
        syncAssets()
    }

    private func deleteAsset(_ asset: DigitalAsset) {
        guard let user = userViewModel.currentUser else { return }
        var list = user.digitalAssets
        list.removeAll { $0.id == asset.id }
        user.digitalAssets = list
        userViewModel.saveContext()
        syncAssets()
    }

    private func syncAssets() {
        if let encoded = userViewModel.currentUser?.digitalAssetsData {
            Task { await SupabaseService.shared.syncLegacyField(column: "digital_assets_data", data: encoded) }
        }
    }
}

// MARK: - Asset row

struct AssetRow: View {
    let asset: DigitalAsset

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: asset.category.systemImage)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name)
                    .font(.headline)
                if !asset.institution.isEmpty {
                    Text(asset.institution)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !asset.accountHint.isEmpty {
                    Text(asset.accountHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add / Edit sheet

struct AddEditAssetView: View {
    @Environment(\.dismiss) private var dismiss

    let existingAsset: DigitalAsset?
    let onSave: (DigitalAsset) -> Void

    @State private var category: DigitalAsset.DigitalAssetCategory = .banking
    @State private var name = ""
    @State private var institution = ""
    @State private var accountHint = ""
    @State private var accessNotes = ""
    @State private var locationNotes = ""

    var isFormValid: Bool { !name.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(DigitalAsset.DigitalAssetCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.systemImage).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Details") {
                    TextField("Name (e.g. Lloyds Current Account)", text: $name)
                    TextField("Institution (e.g. Lloyds Bank)", text: $institution)
                    TextField("Account hint (e.g. last 4 digits: 4821)", text: $accountHint)
                }

                Section("Access information") {
                    TextField(
                        "Where login details are stored, who has access...",
                        text: $accessNotes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section("Location notes") {
                    TextField(
                        "Branch address, physical documents location...",
                        text: $locationNotes,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                }

                Section {
                    Text("Do not enter actual passwords here. Note where they are kept instead (e.g. '1Password vault' or 'grey folder in my filing cabinet').")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existingAsset == nil ? "Add Asset" : "Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isFormValid)
                }
            }
            .onAppear {
                if let a = existingAsset {
                    category      = a.category
                    name          = a.name
                    institution   = a.institution
                    accountHint   = a.accountHint
                    accessNotes   = a.accessNotes
                    locationNotes = a.locationNotes
                }
            }
        }
    }

    private func save() {
        var asset = existingAsset ?? DigitalAsset(
            category: category,
            name: "",
            institution: "",
            accountHint: "",
            accessNotes: "",
            locationNotes: ""
        )
        asset.category      = category
        asset.name          = name
        asset.institution   = institution
        asset.accountHint   = accountHint
        asset.accessNotes   = accessNotes
        asset.locationNotes = locationNotes
        asset.lastUpdated   = Date()
        onSave(asset)
        dismiss()
    }
}
