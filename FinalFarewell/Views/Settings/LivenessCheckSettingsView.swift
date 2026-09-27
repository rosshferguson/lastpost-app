//
//  LivenessCheckSettingsView.swift
//  Last Post
//
//  Lets the user enable the liveness check and set how often they
//  want to check in. If they miss a check-in, their designated
//  person(s) are automatically notified.
//

import SwiftUI

struct LivenessCheckSettingsView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var enabled = false
    @State private var frequencyDays = 30
    @State private var isSaved = false

    let frequencies: [(label: String, days: Int)] = [
        ("Daily",     1),
        ("Weekly",    7),
        ("Monthly",   30),
        ("Quarterly", 90),
    ]

    var nextCheckDate: Date {
        Calendar.current.date(byAdding: .day, value: frequencyDays, to: Date()) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("When enabled, Last Post will remind you to check in periodically. If you miss a check-in, your designated person will be notified so they can make sure you're okay.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Enable routine check-in", isOn: $enabled)
                        .tint(.purple)
                }

                if enabled {
                    Section("Check-in frequency") {
                        ForEach(frequencies, id: \.days) { freq in
                            HStack {
                                Text(freq.label)
                                Spacer()
                                if frequencyDays == freq.days {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.purple)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { frequencyDays = freq.days }
                        }
                    }

                    Section {
                        LabeledContent("Next check-in due") {
                            Text(nextCheckDate.formatted(.dateTime.day().month(.wide).year()))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Text("You'll receive a notification when it's time to check in. You'll need to open Last Post and verify your identity to confirm you're well.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Save") {
                        save()
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)

                    if isSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Routine check-in")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let user = userViewModel.currentUser else { return }
        enabled = user.livenessCheckEnabled
        frequencyDays = user.livenessCheckFrequencyDays
    }

    private func save() {
        guard let user = userViewModel.currentUser else { return }
        user.livenessCheckEnabled = enabled
        user.livenessCheckFrequencyDays = frequencyDays
        user.nextLivenessCheckAt = enabled ? nextCheckDate : nil
        userViewModel.saveContext()

        Task {
            await SupabaseService.shared.updateLivenessCheckSchedule(
                enabled: enabled,
                frequencyDays: frequencyDays,
                nextCheckAt: enabled ? nextCheckDate : nil
            )
        }

        isSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isSaved = false }
    }
}
