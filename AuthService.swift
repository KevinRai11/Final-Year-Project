import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {

    static let shared = AuthService()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: - UM-F-0.1 Login
    func login(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        let user   = try await fetchUser(uid: result.user.uid)
        guard !user.isBanned else {
            try Auth.auth().signOut()
            throw AuthError.accountBanned
        }
        return user
    }

    // MARK: - UM-F-1.2 Self-registration
    func register(email: String, password: String, fullName: String,
                  role: UserRole, shopName: String = "") async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid    = result.user.uid
        let user   = User(id: uid, email: email, role: role)
        try await saveUser(user)
        var profile       = UserProfile(userId: uid, fullName: fullName)
        profile.shopName  = shopName
        try await saveProfile(profile)
        return user
    }

    // MARK: - UM-F-1.0 Admin creates pet shop / shelter account
    func adminCreateAccount(email: String, shopName: String, fullName: String) async throws {
        let tempPassword = "AdoptBuddy@\(Int.random(in: 1000...9999))"
        let result       = try await Auth.auth().createUser(withEmail: email, password: tempPassword)
        let uid          = result.user.uid
        let user         = User(id: uid, email: email, role: .petShop)
        try await saveUser(user)
        var profile      = UserProfile(userId: uid, fullName: fullName)
        profile.shopName = shopName
        try await saveProfile(profile)
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Logout
    func logout() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Fetch user from Firestore
    func fetchUser(uid: String) async throws -> User {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data() else { throw AuthError.userNotFound }
        return try decodeUser(from: data, id: uid)
    }

    // MARK: - Auth state listener
    func authStateListener(onChange: @escaping (FirebaseAuth.User?) -> Void) {
        Auth.auth().addStateDidChangeListener { _, user in onChange(user) }
    }

    // MARK: - Private helpers
    private func saveUser(_ user: User) async throws {
        let data: [String: Any] = [
            "email":     user.email,
            "role":      user.role.rawValue,
            "isActive":  user.isActive,
            "isBanned":  user.isBanned,
            "createdAt": user.createdAt,
            "updatedAt": user.updatedAt
        ]
        try await db.collection("users").document(user.id).setData(data)
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        let data: [String: Any] = [
            "userId":          profile.userId,
            "fullName":        profile.fullName,
            "phone":           profile.phone,
            "address":         profile.address,
            "city":            profile.city,
            "country":         profile.country,
            "shopName":        profile.shopName,
            "description":     profile.description,
            "profileImageURL": profile.profileImageURL
        ]
        try await db.collection("userProfiles").document(profile.id).setData(data)
    }

    private func decodeUser(from data: [String: Any], id: String) throws -> User {
        guard
            let email   = data["email"]   as? String,
            let roleRaw = data["role"]    as? String,
            let role    = UserRole(rawValue: roleRaw),
            let isActive = data["isActive"] as? Bool,
            let isBanned = data["isBanned"] as? Bool
        else { throw AuthError.decodingFailed }
        var user         = User(id: id, email: email, role: role)
        user.isActive    = isActive
        user.isBanned    = isBanned
        return user
    }
}

enum AuthError: LocalizedError {
    case userNotFound, accountBanned, decodingFailed
    var errorDescription: String? {
        switch self {
        case .userNotFound:    return "User account not found."
        case .accountBanned:   return "Your account has been suspended. Contact support."
        case .decodingFailed:  return "Failed to load user data. Please try again."
        }
    }
}
