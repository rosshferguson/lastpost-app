//
//  NotificationAuditLogView.swift
//  FinalFarewell
//
//  Read-only audit log of the death notification process.
//  Shows each event in chronological order with timestamp, type, and details.
//  Accessible from DesignatedPersonView after a notification is confirmed.
//

import SwiftUI

struct NotificationAuditLogView: View {
    let notification: DeathNotification

    var body: some View {
        List {
            summarySection
            logSection
        }
        .navigationTitle("Notification log")
        .navigationBarTitleDisplayMode(.large)
    }

    private var summarySection: some View {
        Section {
            LabeledContent("For", value: notification.deceasedName)
            LabeledContent("Triggered by", value: notification.triggeredByName)
            LabeledContent("Triggered", value: notification.triggeredAt.formatted(date: .abbreviated, time: .shortened))
            if let confirmed = notification.confirmedAt {
                LabeledContent("Confirmed", value: confirmed.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("Status", value: notification.isConfirmed ? "Confirmed" : "In progress")
        }
    }

    private var logSection: some View {
        Section("Event log") {
            if notification.auditLog.isEmpty {
                Text("No events recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notification.auditLog.sorted { $0.timestamp < $1.timestamp }) { entry in
                    AuditEntryRow(entry: entry)
                }
            }
        }
    }
}

// MARK: - Audit entry row

struct AuditEntryRow: View {
    let entry: AuditEntry

    var iconName: String {
        switch entry.eventType {
        case .notificationTriggered: return "bolt.fill"
        case .waitingPeriodStarted: return "clock.fill"
        case .waitingPeriodCompleted: return "clock.badge.checkmark.fill"
        case .notificationConfirmed: return "checkmark.seal.fill"
        case .contactNotified: return "envelope.fill"
        case .funeralDetailsSent: return "calendar.badge.checkmark"
        case .notificationCancelled: return "xmark.circle.fill"
        case .dryRunCompleted: return "play.circle.fill"
        }
    }

    var iconColor: Color {
        switch entry.eventType {
        case .notificationTriggered: return .purple
        case .waitingPeriodStarted: return .orange
        case .waitingPeriodCompleted: return .green
        case .notificationConfirmed: return .green
        case .contactNotified: return .blue
        case .funeralDetailsSent: return .teal
        case .notificationCancelled: return .red
        case .dryRunCompleted: return .blue
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.eventType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !entry.contactName.isEmpty {
                    Text(entry.contactName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
