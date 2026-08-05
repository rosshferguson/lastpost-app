import Foundation
import SwiftData

@Model
final class SharedMedia {
    @Attribute(.unique) var id: UUID
    var localIdentifier: String?
    var imageData: Data?
    var caption: String
    var createdAt: Date
    var mediaType: MediaType
    
    // Who can see this
    var sharedWithAll: Bool
    var specificRecipientIds: [UUID]
    
    @Relationship(inverse: \User.sharedMedia)
    var owner: User?
    
    enum MediaType: String, Codable {
        case photo
        case video
        case document
    }
    
    init(
        id: UUID = UUID(),
        localIdentifier: String? = nil,
        imageData: Data? = nil,
        caption: String = "",
        mediaType: MediaType = .photo
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.imageData = imageData
        self.caption = caption
        self.createdAt = Date()
        self.mediaType = mediaType
        self.sharedWithAll = true
        self.specificRecipientIds = []
    }
}
