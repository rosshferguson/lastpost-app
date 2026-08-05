import Foundation
import SwiftUI
import SwiftData
import PhotosUI

@MainActor
class MediaViewModel: ObservableObject {
    @Published var sharedMedia: [SharedMedia] = []
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasPhotoLibraryAccess = false
    
    private var modelContext: ModelContext?
    private var currentUser: User?
    
    func configure(context: ModelContext, user: User?) {
        self.modelContext = context
        self.currentUser = user
        loadMedia()
        checkPhotoLibraryAccess()
    }
    
    func loadMedia() {
        guard let user = currentUser else {
            sharedMedia = []
            return
        }
        
        sharedMedia = user.sharedMedia.sorted { $0.createdAt > $1.createdAt }
    }
    
    func addMedia(imageData: Data, caption: String, sharedWithAll: Bool, recipientIds: [UUID]) {
        guard let context = modelContext, let user = currentUser else { return }
        
        let media = SharedMedia(
            imageData: imageData,
            caption: caption
        )
        media.sharedWithAll = sharedWithAll
        media.specificRecipientIds = recipientIds
        media.owner = user
        
        user.sharedMedia.append(media)
        context.insert(media)
        
        do {
            try context.save()
            loadMedia()
        } catch {
            errorMessage = "Failed to save media: \(error.localizedDescription)"
        }
    }
    
    func deleteMedia(_ media: SharedMedia) {
        guard let context = modelContext else { return }
        
        context.delete(media)
        
        do {
            try context.save()
            loadMedia()
        } catch {
            errorMessage = "Failed to delete media: \(error.localizedDescription)"
        }
    }
    
    func processSelectedPhotos() async {
        isLoading = true
        
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self) {
                addMedia(imageData: data, caption: "", sharedWithAll: true, recipientIds: [])
            }
        }
        
        selectedPhotos = []
        isLoading = false
    }
    
    func requestPhotoLibraryAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        hasPhotoLibraryAccess = status == .authorized || status == .limited
    }
    
    private func checkPhotoLibraryAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        hasPhotoLibraryAccess = status == .authorized || status == .limited
    }
}
