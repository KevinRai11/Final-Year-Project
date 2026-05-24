import Foundation
import FirebaseStorage
import UIKit

final class StorageService {

    static let shared = StorageService()
    private let storage = Storage.storage()
    private init() {}

    // MARK: - Upload single pet image
    func uploadPetImage(image: UIImage, petId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.compressionFailed
        }
        let filename         = "\(UUID().uuidString).jpg"
        let ref              = storage.reference().child("pets/\(petId)/\(filename)")
        let metadata         = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Upload multiple images
    func uploadPetImages(images: [UIImage], petId: String) async throws -> [String] {
        var urls: [String] = []
        for image in images {
            let url = try await uploadPetImage(image: image, petId: petId)
            urls.append(url)
        }
        return urls
    }

    // MARK: - Delete image
    func deleteImage(urlString: String) async throws {
        let ref = storage.reference(forURL: urlString)
        try await ref.delete()
    }

    // MARK: - Upload profile image
    func uploadProfileImage(image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.compressionFailed
        }
        let ref              = storage.reference().child("profiles/\(userId)/avatar.jpg")
        let metadata         = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}

enum StorageError: LocalizedError {
    case compressionFailed
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to process image. Please try a different photo."
        }
    }
}
