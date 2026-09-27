//
//  DocumentsChecklistView.swift
//  FinalFarewell
//
//  A structured checklist of important documents and notes the designated
//  person will need access to after death. Stored as JSON on User.importantDocumentsData.
//  Grouped by category. Each item has a title, free-text notes field, and a
//  completion toggle.
//

import SwiftUI
import Combine
struct DocumentsChecklistView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var documents: [DocumentNote] = []
    @State private var editingId: UUID?
    @State private var showingAddItem = false
    @State private var newItemCategory = "Legal"
    @State private var newItemTitle = ""

    private let categories = ["Legal", "Finance", "Funeral", "Property", "Digital", "Other"]

    private var grouped: [(String, [DocumentNote])] {
        let order = ["Legal", "Finance", "Funeral", "Property", "Digital", "Other"]
        return order.compactMap { cat in
            let items = documents.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var completedCount: Int { documents.filter { $0.isComplete }.count }

    var body: some View {
        NavigationStack {
            List {
                progressSection

                ForEach(grouped, id: \.0) { category, items in
                    Section(category) {
                        ForEach(items) { item in
                            DocumentNoteRow(
                                item: binding(for: item),
                                isEditing: editingId == item.id,
                                onTapEdit: {
                                    editingId = editingId == item.id ? nil : item.id
                                }
                            )
                        }
                        .onDelete { indexSet in
                            deleteItems(in: category, at: indexSet)
                        }
                    }
                }

                Section {
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add document", systemImage: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Important documents")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { load() }
            .sheet(isPresented: $showingAddItem) {
                addItemSheet
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(completedCount) of \(documents.count) completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((Double(completedCount) / Double(max(documents.count, 1))) * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                ProgressView(value: Double(completedCount), total: Double(max(documents.count, 1)))
                    .tint(.green)
            }
            .padding(.vertical, 4)

            Text("Your designated person will receive access to these notes after they confirm your death notification.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Add item sheet

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $newItemCategory) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section("Title") {
                    TextField("e.g. Pension contact details", text: $newItemTitle)
                }
            }
            .navigationTitle("Add document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddItem = false
                        newItemTitle = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newItemTitle.isEmpty else { return }
                        documents.append(DocumentNote(
                            category: newItemCategory,
                            title: newItemTitle,
                            notes: ""
                        ))
                        save()
                        newItemTitle = ""
                        showingAddItem = false
                    }
                    .disabled(newItemTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func binding(for item: DocumentNote) -> Binding<DocumentNote> {
        Binding(
            get: { documents.first(where: { $0.id == item.id }) ?? item },
            set: { newVal in
                if let idx = documents.firstIndex(where: { $0.id == item.id }) {
                    documents[idx] = newVal
                }
            }
        )
    }

    private func deleteItems(in category: String, at offsets: IndexSet) {
        let catItems = documents.filter { $0.category == category }
        let idsToDelete = offsets.map { catItems[$0].id }
        documents.removeAll { idsToDelete.contains($0.id) }
        save()
    }

    private func load() {
        documents = userViewModel.currentUser?.importantDocuments ?? DocumentNote.defaults
    }

    private func save() {
        userViewModel.currentUser?.importantDocuments = documents
        if let encoded = userViewModel.currentUser?.importantDocumentsData {
            Task { await SupabaseService.shared.syncLegacyField(column: "important_documents_data", data: encoded) }
        }
    }
}

// MARK: - Document note row

struct DocumentNoteRow: View {
    @Binding var item: DocumentNote
    let isEditing: Bool
    let onTapEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    item.isComplete.toggle()
                } label: {
                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isComplete ? .green : .secondary)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(item.isComplete, color: .secondary)
                        .foregroundStyle(item.isComplete ? .secondary : .primary)

                    if !item.notes.isEmpty && !isEditing {
                        Text(item.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    onTapEdit()
                } label: {
                    Image(systemName: isEditing ? "chevron.up" : "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)

            if isEditing {
                TextField("Add notes, location, reference numbers...", text: $item.notes, axis: .vertical)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .padding(.top, 6)
                    .padding(.leading, 32)
            }
        }
    }
}
