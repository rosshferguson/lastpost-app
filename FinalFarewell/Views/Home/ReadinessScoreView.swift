//
//  ReadinessScoreView.swift
//  FinalFarewell
//
//  Calculates and displays a "readiness score" showing how complete
//  the user's setup is. Each item is worth points toward 100%.
//

import SwiftUI

struct ReadinessScore {
    let user: User
    let contacts: [Contact]

    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let complete: Bool
        let points: Int
        let suggestion: String?
    }

    var items: [Item] {
        [
            Item(
                title: "Profile complete",
                complete: !user.firstName.isEmpty && !user.email.isEmpty,
                points: 10,
                suggestion: "Add your name and email in Settings"
            ),
            Item(
                title: "At least one contact added",
                complete: !contacts.isEmpty,
                points: 20,
                suggestion: "Add someone to your notification list"
            ),
            Item(
                title: "At least one contact confirmed",
                complete: contacts.contains { $0.invitationAccepted },
                points: 20,
                suggestion: "Ask a contact to accept their invitation"
            ),
            Item(
                title: "Designated person added",
                complete: !user.designatedPersons.isEmpty,
                points: 25,
                suggestion: "Add someone to manage your notifications"
            ),
            Item(
                title: "Designated person confirmed",
                complete: user.designatedPersons.contains { $0.invitationAccepted },
                points: 15,
                suggestion: "Ask your designated person to accept"
            ),
            Item(
                title: "Memories added",
                complete: !user.sharedMedia.isEmpty,
                points: 5,
                suggestion: "Add photos in the Memories tab"
            ),
            Item(
                title: "Personal messages written",
                complete: contacts.contains { $0.hasPersonalContent },
                points: 5,
                suggestion: "Write a personal message to a contact"
            )
        ]
    }

    var totalPoints: Int { items.reduce(0) { $0 + $1.points } }
    var earnedPoints: Int { items.filter { $0.complete }.reduce(0) { $0 + $1.points } }
    var percentage: Int { totalPoints > 0 ? (earnedPoints * 100) / totalPoints : 0 }

    var scoreColor: Color {
        switch percentage {
        case 80...100: return .green
        case 50...79:  return .orange
        default:       return .red
        }
    }

    var nextSuggestion: String? {
        items.first { !$0.complete }?.suggestion
    }
}

// MARK: - Score widget for HomeView

struct ReadinessScoreView: View {
    let score: ReadinessScore
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 16) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: CGFloat(score.percentage) / 100)
                        .stroke(score.scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: score.percentage)

                    Text("\(score.percentage)%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(score.scoreColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Readiness Score")
                        .font(.headline)

                    if score.percentage == 100 {
                        Text("Your setup is complete")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else if let suggestion = score.nextSuggestion {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            ReadinessDetailView(score: score)
        }
    }
}

// MARK: - Full breakdown sheet

struct ReadinessDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let score: ReadinessScore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                                .frame(width: 120, height: 120)

                            Circle()
                                .trim(from: 0, to: CGFloat(score.percentage) / 100)
                                .stroke(score.scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 2) {
                                Text("\(score.percentage)%")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(score.scoreColor)
                                Text("Ready")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)

                        Text(score.percentage == 100
                            ? "Your legacy plan is complete."
                            : "Complete the steps below to ensure everything is in order.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Checklist") {
                    ForEach(score.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.complete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.complete ? .green : .gray)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.body)
                                    .foregroundStyle(item.complete ? .primary : .secondary)

                                if !item.complete, let suggestion = item.suggestion {
                                    Text(suggestion)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text("+\(item.points)%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(item.complete ? .green : .gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Readiness Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
