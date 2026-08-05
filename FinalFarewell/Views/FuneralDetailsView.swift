import SwiftUI

struct FuneralDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationViewModel: NotificationViewModel
    
    @State private var funeralDate = Date()
    @State private var funeralLocation = ""
    @State private var funeralDetails = ""
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    DatePicker(
                        "Funeral Date",
                        selection: $funeralDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                
                Section("Location") {
                    TextField("Venue name", text: $funeralLocation)
                    
                    TextField("Additional details (address, parking, etc.)", text: $funeralDetails, axis: .vertical)
                        .lineLimit(4...8)
                }
                
                Section {
                    Text("These details will be sent to everyone who opted to receive funeral information.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Funeral Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        showingConfirmation = true
                    }
                    .disabled(funeralLocation.isEmpty)
                }
            }
            .alert("Send Funeral Details?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send") {
                    notificationViewModel.addFuneralDetails(
                        date: funeralDate,
                        location: funeralLocation,
                        details: funeralDetails
                    )
                    dismiss()
                }
            } message: {
                Text("This will notify all contacts who requested funeral information.")
            }
        }
    }
}
