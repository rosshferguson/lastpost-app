//
//  ContactConsentView.swift
//  FinalFarewell
//
//  Fixed: ConsentRow now uses a sheet to present ContactDetailView
//  instead of a NavigationLink, resolving the "cannot find in scope" error.
//

import SwiftUI

struct ContactConsentView: View {
    @EnvironmentObject var contactsViewModel: ContactsViewModel

    private var grouped: [(String, [Contact])] {
        let all = contactsViewModel.contacts
        let overdue = all.filter { $0.invitationAccepted && $0.needsVerification }
        let verified = all.filter { $0.invitationAccepted && !$0.needsVerification }
        let pending = all.filter { $0.invitationSent && !$0.invitationAccepted }
        let uninvited = all.filter { !$0.invitationSent }

        return [
            ("Overdue — needs reverification", overdue),
            ("Verified", verified),
            ("Invited — awaiting response", pending),
            ("Not yet invited", uninvited),
        ].filter { !$1.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                summaryRow

                ForEach(grouped, id: \.0) { title, contacts in
                    Section(title) {
                        ForEach(contacts) { contact in
                            ConsentRow(contact: contact)
                        }
                    }
                }

                if contactsViewModel.contacts.isEmpty {
                    ContentUnavailableView(
                        "No contacts yet",
                        systemImage: "person.slash",
                        description: Text("Add contacts to see their consent status here.")
                    )
                }
            }
            .navigationTitle("Consent overview")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var summaryRow: some View {
        let all = contactsViewModel.contacts
        let confirmed = all.filter { $0.invitationAccepted && !$0.needsVerification }.count
        let total = all.count

        return Section {
            HStack(spacing: 0) {
                SummaryPill(count: confirmed, label: "Ready", color: .green)
                SummaryPill(count: all.filter { $0.invitationAccepted && $0.needsVerification }.count, label: "Overdue", color: .orange)
                SummaryPill(count: all.filter { $0.invitationSent && !$0.invitationAccepted }.count, label: "Pending", color: .blue)
                SummaryPill(count: all.filter { !$0.invitationSent }.count, label: "Not invited", color: .gray)
            }
            .padding(.vertical, 4)

            if total > 0 {
                let pct = Int((Double(confirmed) / Double(total)) * 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(pct)% of your list is confirmed and up to date")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(confirmed), total: Double(max(total, 1)))
                        .tint(.green)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Summary pill

struct SummaryPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Individual consent row

struct ConsentRow: View {
    let contact: Contact
    @State private var showingDetail = false

    var statusIcon: String {
        if contact.invitationAccepted && !contact.needsVerification { return "checkmark.circle.fill" }
        if contact.invitationAccepted && contact.needsVerification { return "exclamationmark.circle.fill" }
        if contact.invitationSent { return "clock.fill" }
        return "circle"
    }

    var statusColor: Color {
        if contact.invitationAccepted && !contact.needsVerification { return .green }
        if contact.invitationAccepted && contact.needsVerification { return .orange }
        if contact.invitationSent { return .blue }
        return .gray
    }

    var statusLabel: String {
        if contact.invitationAccepted && !contact.needsVerification {
            if let date = contact.lastVerified {
                return "Verified \(date.formatted(.relative(presentation: .named)))"
            }
            return "Verified"
        }
        if contact.invitationAccepted { return "Verification overdue" }
        if contact.invitationSent { return "Invitation sent" }
        return "Not invited"
    }

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if contact.hasPersonalContent {
                    Image(systemName: "envelope.badge.fill")
                        .font(.caption)
                        .foregroundStyle(.purple.opacity(0.6))
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                ContactDetailView(contact: contact)
            }
        }
    }
}
