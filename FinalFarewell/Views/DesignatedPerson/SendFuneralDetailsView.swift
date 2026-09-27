//
//  SendFuneralDetailsView.swift
//  Last Post
//
//  Allows a designated person to send funeral arrangement details
//  to all contacts who have already been notified of the death.
//  All fields are optional — they send whatever is currently known.
//

import SwiftUI

struct SendFuneralDetailsView: View {
    let ownerName: String
    let ownerSupabaseId: UUID

    @Environment(\.dismiss) private var dismiss

    @State private var includeDateAndTime = false
    @State private var funeralDate        = Date()
    @State private var funeralTime        = Date()
    @State private var venueName          = ""
    @State private var venueAddress       = ""
    @State private var additionalNotes    = ""

    @State private var isSending  = false
    @State private var didSend    = false
    @State private var errorText  = ""

    // Formatters
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Send funeral arrangement details to everyone who was notified of \(ownerName)'s passing. All fields are optional — share whatever is currently known.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Include date and time", isOn: $includeDateAndTime)
                        .tint(.purple)

                    if includeDateAndTime {
                        DatePicker("Date", selection: $funeralDate, displayedComponents: .date)
                        DatePicker("Time", selection: $funeralTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("When")
                }

                Section {
                    TextField("e.g. St Mary's Church", text: $venueName)
                    TextField("Address (optional)", text: $venueAddress, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Where")
                }

                Section {
                    TextField("Any other information for attendees", text: $additionalNotes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Additional notes")
                }

                if !errorText.isEmpty {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending {
                            HStack {
                                ProgressView()
                                Text("Sending…")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Send to all contacts")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSending || !hasAnyContent)
                }

                Section {
                    Text("This will send a follow-up email to everyone who was notified. You can send updates more than once as details become clearer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Funeral details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Details sent", isPresented: $didSend) {
                Button("Done") { dismiss() }
            } message: {
                Text("The funeral details have been sent to all contacts.")
            }
        }
    }

    // MARK: - Helpers

    private var hasAnyContent: Bool {
        includeDateAndTime || !venueName.isEmpty || !venueAddress.isEmpty || !additionalNotes.isEmpty
    }

    private func send() async {
        isSending = true
        errorText = ""

        var payload: [String: String] = ["owner_supabase_id": ownerSupabaseId.uuidString]

        if includeDateAndTime {
            payload["funeral_date"] = dateFormatter.string(from: funeralDate)
            payload["funeral_time"] = timeFormatter.string(from: funeralTime)
        }
        if !venueName.isEmpty       { payload["venue_name"]      = venueName }
        if !venueAddress.isEmpty    { payload["venue_address"]   = venueAddress }
        if !additionalNotes.isEmpty { payload["additional_notes"] = additionalNotes }

        do {
            try await SupabaseService.shared.sendFuneralDetails(payload: payload)
            didSend = true
        } catch {
            errorText = "Something went wrong. Please try again."
        }

        isSending = false
    }
}
