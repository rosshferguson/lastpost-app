//
//  PersonalMessageView.swift
//  FinalFarewell
//
//  Allows the user to write a personal message and record a video message
//  for a specific contact. Both are stored on the Contact model.
//

import SwiftUI
import AVFoundation
import AVKit

// MARK: - Personal Message + Video hub for a contact

struct PersonalMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var contact: Contact

    @State private var showingVideoRecorder = false
    @State private var showingVideoPlayer = false
    @State private var showingDeleteVideoAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Written message section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This message will only be delivered to \(contact.firstName) when your designated person triggers notifications.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            "Write a personal message to \(contact.firstName)...",
                            text: Binding(
                                get: { contact.personalMessage ?? "" },
                                set: { contact.personalMessage = $0.isEmpty ? nil : $0 }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(6...12)
                        .font(.body)

                        if let message = contact.personalMessage, !message.isEmpty {
                            Text("\(message.count) / \(AppConstants.Limits.maxMessageLength)")
                                .font(.caption2)
                                .foregroundStyle(message.count > AppConstants.Limits.maxMessageLength ? .red : .secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                } header: {
                    Label("Personal Message", systemImage: "text.quote")
                }

                // Video message section
                Section {
                    if let videoData = contact.videoMessageData {
                        // Video exists — show preview and options
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "video.fill")
                                    .foregroundStyle(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Video message recorded")
                                        .font(.headline)
                                    if let date = contact.videoMessageRecordedAt {
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    showingVideoPlayer = true
                                } label: {
                                    Label("Preview", systemImage: "play.circle")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.purple.opacity(0.1))
                                        .foregroundStyle(.purple)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Button {
                                    showingVideoRecorder = true
                                } label: {
                                    Label("Re-record", systemImage: "video.badge.plus")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }

                            Button(role: .destructive) {
                                showingDeleteVideoAlert = true
                            } label: {
                                Label("Delete Video", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                        .sheet(isPresented: $showingVideoPlayer) {
                            VideoPlayerView(videoData: videoData)
                        }
                    } else {
                        // No video yet
                        VStack(spacing: 12) {
                            Text("Record a personal video message for \(contact.firstName). This will only be shared with them after your notification is triggered.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                showingVideoRecorder = true
                            } label: {
                                Label("Record Video Message", systemImage: "video.badge.plus")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                } header: {
                    Label("Video Message", systemImage: "video.fill")
                }
            }
            .navigationTitle("\(contact.firstName)'s Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingVideoRecorder) {
                VideoRecorderView { videoData in
                    contact.videoMessageData = videoData
                    contact.videoMessageRecordedAt = Date()
                    contact.lastUpdated = Date()
                }
            }
            .alert("Delete Video Message?", isPresented: $showingDeleteVideoAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    contact.videoMessageData = nil
                    contact.videoMessageRecordedAt = nil
                    contact.lastUpdated = Date()
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}

// MARK: - Video recorder using AVFoundation

struct VideoRecorderView: UIViewControllerRepresentable {
    var onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onSave: onSave)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoMaximumDuration = 300 // 5 minutes max
        picker.videoQuality = .typeMedium
        picker.cameraCaptureMode = .video
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onSave: (Data) -> Void

        init(onSave: @escaping (Data) -> Void) {
            self.onSave = onSave
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)

            if let url = info[.mediaURL] as? URL,
               let data = try? Data(contentsOf: url) {
                onSave(data)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Video player for previewing recorded messages

struct VideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let videoData: Data

    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            Group {
                if let player = player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                } else {
                    ProgressView("Loading video...")
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    private func setupPlayer() {
        // Write data to a temp file so AVPlayer can read it
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        do {
            try videoData.write(to: tempURL)
            player = AVPlayer(url: tempURL)
        } catch {
            print("Failed to write video temp file: \(error)")
        }
    }
}
