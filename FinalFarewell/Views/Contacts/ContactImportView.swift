//
//  ContactImportView.swift
//  FinalFarewell
//
//  Wraps CNContactPickerViewController so the user can pick existing
//  iPhone contacts to import rather than typing details manually.
//  Multiple contacts can be selected in one pass.
//

import SwiftUI
import ContactsUI
import Contacts

// MARK: - UIViewControllerRepresentable wrapper

struct ContactPickerView: UIViewControllerRepresentable {
    var onSelect: ([CNContact]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Request the fields we need
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: ([CNContact]) -> Void

        init(onSelect: @escaping ([CNContact]) -> Void) {
            self.onSelect = onSelect
        }

        // Multiple selection
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onSelect(contacts)
        }

        // Single selection fallback
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect([contact])
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onSelect([])
        }
    }
}

// MARK: - Import review screen

struct ContactImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var contactsViewModel: ContactsViewModel

    @State private var showingPicker = false
    @State private var importCandidates: [ImportCandidate] = []
    @State private var isImporting = false
    @State private var importComplete = false

    let relationships = [
        "Spouse", "Partner", "Parent", "Child", "Sibling",
        "Friend", "Colleague", "Extended Family", "Other"
    ]

    struct ImportCandidate: Identifiable {
        let id = UUID()
        let contact: CNContact
        var selected: Bool = true
        var relationship: String = ""

        var firstName: String { contact.givenName }
        var lastName: String { contact.familyName }
        var email: String { contact.emailAddresses.first?.value as String? ?? "" }
        var phone: String { contact.phoneNumbers.first?.value.stringValue ?? "" }
        var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
        var hasContactInfo: Bool { !email.isEmpty || !phone.isEmpty }
    }

    var selectedCount: Int { importCandidates.filter { $0.selected }.count }

    var body: some View {
        NavigationStack {
            Group {
                if importCandidates.isEmpty {
                    // Initial state — prompt to open picker
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)

                        Text("Import Contacts")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Choose people from your iPhone contacts to add to your notification list.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button {
                            showingPicker = true
                        } label: {
                            Label("Choose Contacts", systemImage: "person.crop.circle.badge.plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 32)

                        Spacer()
                    }
                } else {
                    // Review and confirm selected contacts
                    List {
                        Section {
                            Text("Review the contacts below. Deselect any you don't want to add, and set their relationship to you.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Section("\(selectedCount) of \(importCandidates.count) selected") {
                            ForEach($importCandidates) { $candidate in
                                ImportCandidateRow(
                                    candidate: $candidate,
                                    relationships: relationships
                                )
                            }
                        }

                        Section {
                            Button {
                                showingPicker = true
                            } label: {
                                Label("Choose Different Contacts", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if !importCandidates.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import (\(selectedCount))") {
                            importSelected()
                        }
                        .disabled(selectedCount == 0 || isImporting)
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                ContactPickerView { cnContacts in
                    guard !cnContacts.isEmpty else { return }
                    importCandidates = cnContacts.map { ImportCandidate(contact: $0) }
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("Importing...")
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("Import Complete", isPresented: $importComplete) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(selectedCount) contact(s) added to your notification list.")
            }
        }
    }

    private func importSelected() {
        isImporting = true
        let toImport = importCandidates.filter { $0.selected && $0.hasContactInfo }

        for candidate in toImport {
            contactsViewModel.addContact(
                firstName: candidate.firstName,
                lastName: candidate.lastName,
                email: candidate.email,
                phoneNumber: candidate.phone,
                relationship: candidate.relationship,
                notes: ""
            )
        }

        isImporting = false
        importComplete = true
    }
}

// MARK: - Row view for each candidate

struct ImportCandidateRow: View {
    @Binding var candidate: ContactImportView.ImportCandidate
    let relationships: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: $candidate.selected) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(candidate.firstName.prefix(1) + candidate.lastName.prefix(1))
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.fullName.isEmpty ? "Unknown" : candidate.fullName)
                                .font(.headline)

                            if !candidate.email.isEmpty {
                                Text(candidate.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !candidate.phone.isEmpty {
                                Text(candidate.phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !candidate.hasContactInfo {
                                Text("No email or phone — cannot notify")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .disabled(!candidate.hasContactInfo)
            }

            if candidate.selected && candidate.hasContactInfo {
                Picker("Relationship", selection: $candidate.relationship) {
                    Text("Select relationship...").tag("")
                    ForEach(relationships, id: \.self) { rel in
                        Text(rel).tag(rel)
                    }
                }
                .pickerStyle(.menu)
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .opacity(candidate.hasContactInfo ? 1 : 0.4)
    }
}
