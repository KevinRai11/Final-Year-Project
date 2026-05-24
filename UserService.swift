import Foundation
import FirebaseFirestore

final class UserService {

    static let shared = UserService()
    private let db    = Firestore.firestore()
    private init() {}

    // MARK: - Fetch profile
    func fetchProfile(userId: String) async throws -> UserProfile {
        let doc = try await db.collection("userProfiles").document(userId).getDocument()
        guard let data = doc.data() else { throw UserError.profileNotFound }
        return decodeProfile(from: data, id: userId)
    }

    // MARK: - Update profile — UM-F-1.1
    func updateProfile(_ profile: UserProfile) async throws {
        let data: [String: Any] = [
            "fullName":        profile.fullName,
            "phone":           profile.phone,
            "address":         profile.address,
            "city":            profile.city,
            "country":         profile.country,
            "shopName":        profile.shopName,
            "description":     profile.description,
            "profileImageURL": profile.profileImageURL
        ]
        try await db.collection("userProfiles").document(profile.userId).updateData(data)
    }

    // MARK: - Fetch all users (admin)
    func fetchAllUsers() async throws -> [User] {
        let snapshot = try await db.collection("users").getDocuments()
        return snapshot.documents.compactMap { doc in
            decodeUser(from: doc.data(), id: doc.documentID)
        }
    }

    // MARK: - Ban user — UM-F-2.0
    func banUser(userId: String) async throws {
        try await db.collection("users").document(userId)
            .updateData(["isBanned": true, "updatedAt": Date()])
    }

    // MARK: - Unban user — UM-F-2.1
    func unbanUser(userId: String) async throws {
        try await db.collection("users").document(userId)
            .updateData(["isBanned": false, "updatedAt": Date()])
    }

    // MARK: - Decoders
    func decodeProfile(from data: [String: Any], id: String) -> UserProfile {
        var profile             = UserProfile(userId: id, fullName: "")
        profile.fullName        = data["fullName"]        as? String ?? ""
        profile.phone           = data["phone"]           as? String ?? ""
        profile.address         = data["address"]         as? String ?? ""
        profile.city            = data["city"]            as? String ?? ""
        profile.country         = data["country"]         as? String ?? ""
        profile.shopName        = data["shopName"]        as? String ?? ""
        profile.description     = data["description"]     as? String ?? ""
        profile.profileImageURL = data["profileImageURL"] as? String ?? ""
        return profile
    }

    func decodeUser(from data: [String: Any], id: String) -> User? {
        guard
            let email   = data["email"]   as? String,
            let roleRaw = data["role"]    as? String,
            let role    = UserRole(rawValue: roleRaw)
        else { return nil }
        var user      = User(id: id, email: email, role: role)
        user.isBanned = data["isBanned"] as? Bool ?? false
        user.isActive = data["isActive"] as? Bool ?? true
        return user
    }
}

enum UserError: LocalizedError {
    case profileNotFound
    var errorDescription: String? {
        switch self {
        case .profileNotFound: return "User profile not found."
        }
    }
}
