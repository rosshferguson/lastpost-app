//
//  LifeHistoryView.swift
//  FinalFarewell
//
//  Guided prompts for writing a short life history.
//  Reached from Settings → Legacy Planning.
//
//  To add to SettingsView, paste this NavigationLink in the
//  Legacy Planning section alongside DocumentsChecklistView etc.:
//
//    NavigationLink(destination: LifeHistoryView(userId: currentUser.id)) {
//        Label("Life History", systemImage: "text.book.closed")
//    }
//

import SwiftUI

struct LifeHistoryView: View {
    let userId: UUID

    @State private var history: LifeHistory = LifeHistory()
    @Environment(\.dismiss) private var dismiss

    private let prompts: [(title: String, prompt: String, keyPath: WritableKeyPath<LifeHistory, String>)] = [
        (
            "Origins",
            "Where were you born, and where did you grow up? What was life like there?",
            \.origins
        ),
        (
            "Family",
            "Tell us about your family — parents, siblings, and the people who shaped who you became.",
            \.family
        ),
        (
            "Work & career",
            "What did you do for work? What were you most proud of, or what will you be remembered for professionally?",
            \.career
        ),
        (
            "Passions & hobbies",
            "What were your greatest passions, hobbies, or interests outside of work?",
            \.passions
        ),
        (
            "Memorable moments",
            "What moments in your life meant the most to you — big or small?",
            \.memorablemoments
        ),
        (
            "Your legacy",
            "What do you most want people to remember about you?",
            \.legacy
        ),
        (
            "Final thoughts",
            "Is there anything else you'd like your loved ones to know?",
            \.finalThoughts
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Header
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Life History")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("\(history.completedCount) of \(LifeHistory.totalPrompts) answered")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 4)
                            Circle()
                                .trim(
                                    from: 0,
                                    to: CGFloat(history.completedCount) / CGFloat(LifeHistory.totalPrompts)
                                )
                                .stroke(Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int((CGFloat(history.completedCount) / CGFloat(LifeHistory.totalPrompts)) * 100))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .frame(width: 48, height: 48)
                        .animation(.easeInOut, value: history.completedCount)
                    }

                    Text("Answer as much or as little as you like. Your words will be kept here, ready to be shared with family when the time comes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(Color(.secondarySystemBackground))

                // Prompts
                VStack(spacing: 1) {
                    ForEach(Array(prompts.enumerated()), id: \.offset) { index, item in
                        PromptCard(
                            number: index + 1,
                            title: item.title,
                            prompt: item.prompt,
                            text: Binding(
                                get: { history[keyPath: item.keyPath] },
                                set: { history[keyPath: item.keyPath] = $0 }
                            ),
                            onSave: saveHistory
                        )
                    }
                }
                .padding(.top, 1)

            }
        }
        .navigationTitle("Life History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveHistory()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            history = LifeHistory.load(forUserId: userId)
        }
    }

    private func saveHistory() {
        history.save(forUserId: userId)
        if let encoded = try? JSONEncoder().encode(history) {
            Task { await SupabaseService.shared.syncLegacyField(column: "life_history_data", data: encoded) }
        }
    }
}

// MARK: - Prompt card

private struct PromptCard: View {
    let number: Int
    let title: String
    let prompt: String
    @Binding var text: String
    var onSave: () -> Void

    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    private var isAnswered: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row — tapping expands/collapses
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
                if isExpanded { isFocused = true }
            } label: {
                HStack(spacing: 14) {
                    // Number badge
                    ZStack {
                        Circle()
                            .fill(isAnswered ? Color.primary : Color(.systemGray5))
                            .frame(width: 28, height: 28)
                        if isAnswered {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color(UIColor.systemBackground))
                        } else {
                            Text("\(number)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if !isExpanded && isAnswered {
                            Text(text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded text editor
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.body)
                        .frame(minHeight: 140)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                        .onChange(of: isFocused) { _, focused in
                            if !focused { onSave() }
                        }
                }
                .padding(.bottom, 16)
                .background(Color(.systemBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
                .padding(.leading, 20)
        }
    }
}
