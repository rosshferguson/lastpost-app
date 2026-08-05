//
//  SharedMediaView.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import SwiftUI
import PhotosUI

struct SharedMediaView: View {
    @EnvironmentObject var mediaViewModel: MediaViewModel
    @State private var showingPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingPermissionAlert = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Section {
                        Text("Add photos and memories you'd like shared with your loved ones after you pass.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    
                    if mediaViewModel.sharedMedia.isEmpty {
                        ContentUnavailableView(
                            "No Memories Yet",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Add photos to share with your loved ones.")
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(mediaViewModel.sharedMedia) { media in
                                MediaThumbnail(media: media)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .navigationTitle("Memories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images
                    ) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task {
                            await mediaViewModel.requestPhotoLibraryAccess()
                            if !mediaViewModel.hasPhotoLibraryAccess {
                                showingPermissionAlert = true
                            }
                        }
                    } label: {
                        Label("Photo Library Access", systemImage: "photo.badge.checkmark")
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                if let newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            mediaViewModel.addMedia(
                                imageData: data,
                                caption: "",
                                sharedWithAll: true,
                                recipientIds: []
                            )
                        }
                        selectedItem = nil
                    }
                }
            }
            .alert("Photo Access Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Grant photo library access in Settings to automatically share your photo library with designated persons.")
            }
        }
    }
}

struct MediaThumbnail: View {
    let media: SharedMedia
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            Group {
                if let imageData = media.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                        )
                }
            }
            .frame(height: 120)
            .clipped()
        }
        .sheet(isPresented: $showingDetail) {
            MediaDetailView(media: media)
        }
    }
}

struct MediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var mediaViewModel: MediaViewModel
    
    let media: SharedMedia
    @State private var caption: String
    @State private var showingDeleteConfirmation = false
    
    init(media: SharedMedia) {
        self.media = media
        _caption = State(initialValue: media.caption)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let imageData = media.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    TextField("Add a caption...", text: $caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    Text("Added \(media.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .alert("Delete Memory?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    mediaViewModel.deleteMedia(media)
                    dismiss()
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}
