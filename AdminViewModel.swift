import Foundation
import FirebaseFirestore

@MainActor
final class AdminViewModel: ObservableObject {

    // Dashboard
    @Published var totalUsers:           Int  = 0
    @Published var totalPets:            Int  = 0
    @Published var totalAdoptions:       Int  = 0
    @Published var pendingVerifications: Int  = 0
    @Published var bannedUsers:          Int  = 0

    // Pet verification
    @Published var unverifiedPets:       [Pet]             = []
    @Published var isLoadingPets:        Bool              = false

    // User management
    @Published var allUsers:             [UserWithProfile] = []
    @Published var isLoadingUsers:       Bool              = false

    // Create account
    @Published var newShopEmail:         String = ""
    @Published var newShopName:          String = ""
    @Published var newShopFullName:      String = ""
    @Published var isCreatingAccount:    Bool   = false
    @Published var accountCreated:       Bool   = false

    // Shared
    @Published var isLoadingDashboard:   Bool   = false
    @Published var errorMessage:         String?
    @Published var successMessage:       String?

    private let petService  = PetService.shared
    private let userService = UserService.shared
    private let authService = AuthService.shared
    private let db          = Firestore.firestore()

    // MARK: - Load dashboard
    func loadDashboard() async {
        isLoadingDashboard = true; errorMessage = nil
        async let usersSnap    = db.collection("users").getDocuments()
        async let petsSnap     = db.collection("pets").getDocuments()
        async let requestsSnap = db.collection("adoptionRequests")
            .whereField("status", isEqualTo: RequestStatus.approved.rawValue).getDocuments()
        async let unverifiedSnap = db.collection("pets")
            .whereField("status", isEqualTo: PetStatus.unverified.rawValue).getDocuments()
        async let bannedSnap   = db.collection("users")
            .whereField("isBanned", isEqualTo: true).getDocuments()
        do {
            let (users, pets, requests, unverified, banned) =
                try await (usersSnap, petsSnap, requestsSnap, unverifiedSnap, bannedSnap)
            totalUsers           = users.documents.count
            totalPets            = pets.documents.count
            totalAdoptions       = requests.documents.count
            pendingVerifications = unverified.documents.count
            bannedUsers          = banned.documents.count
        } catch { errorMessage = error.localizedDescription }
        isLoadingDashboard = false
    }

    // MARK: - AV-F-1.0 Load unverified pets
    func loadUnverifiedPets() async {
        isLoadingPets = true
        do { unverifiedPets = try await petService.fetchUnverifiedPets(); pendingVerifications = unverifiedPets.count }
        catch { errorMessage = error.localizedDescription }
        isLoadingPets = false
    }

    // MARK: - AV-F-1.0 Approve pet
    func approvePet(petId: String) async {
        do {
            try await petService.verifyPet(petId: petId)
            unverifiedPets.removeAll { $0.id == petId }
            pendingVerifications = unverifiedPets.count
            successMessage = "Pet listing approved and now visible to adopters."
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - AV-F-1.0 Reject pet
    func rejectPet(petId: String, reason: String) async {
        do {
            try await petService.rejectPet(petId: petId)
            unverifiedPets.removeAll { $0.id == petId }
            pendingVerifications = unverifiedPets.count
            successMessage = "Pet listing rejected."
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - AV-F-1.1 Load all users
    func loadAllUsers() async {
        isLoadingUsers = true
        do {
            let users = try await userService.fetchAllUsers()
            var result: [UserWithProfile] = []
            await withTaskGroup(of: UserWithProfile?.self) { group in
                for user in users {
                    group.addTask {
                        let profile = try? await UserService.shared.fetchProfile(userId: user.id)
                        return UserWithProfile(user: user, profile: profile)
                    }
                }
                for await item in group { if let item { result.append(item) } }
            }
            allUsers = result.sorted {
                if $0.user.isBanned != $1.user.isBanned { return !$0.user.isBanned }
                return $0.user.role.rawValue < $1.user.role.rawValue
            }
        } catch { errorMessage = error.localizedDescription }
        isLoadingUsers = false
    }

    // MARK: - AV-F-1.1 Ban user
    func banUser(userId: String) async {
        do {
            try await userService.banUser(userId: userId)
            if let idx = allUsers.firstIndex(where: { $0.user.id == userId }) { allUsers[idx].user.isBanned = true }
            bannedUsers += 1; successMessage = "User has been banned."
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Unban user
    func unbanUser(userId: String) async {
        do {
            try await userService.unbanUser(userId: userId)
            if let idx = allUsers.firstIndex(where: { $0.user.id == userId }) { allUsers[idx].user.isBanned = false }
            bannedUsers = max(0, bannedUsers - 1); successMessage = "User has been unbanned."
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - UM-F-1.0 Create shop account
    func createShopAccount() async {
        guard validateNewAccount() else { return }
        isCreatingAccount = true; errorMessage = nil
        do {
            try await authService.adminCreateAccount(email: newShopEmail, shopName: newShopName, fullName: newShopFullName)
            accountCreated = true
            successMessage = "Account created. A password reset email has been sent to \(newShopEmail)."
            newShopEmail = ""; newShopName = ""; newShopFullName = ""
        } catch { errorMessage = error.localizedDescription }
        isCreatingAccount = false
    }

    private func validateNewAccount() -> Bool {
        guard !newShopEmail.isBlank, newShopEmail.isValidEmail else { errorMessage = "Please enter a valid email."; return false }
        guard !newShopName.isBlank  else { errorMessage = "Please enter the shop name."; return false }
        guard !newShopFullName.isBlank else { errorMessage = "Please enter the contact name."; return false }
        return true
    }

    func clearMessages() { errorMessage = nil; successMessage = nil }
}

// MARK: - Combined User + Profile model
struct UserWithProfile: Identifiable {
    var id: String { user.id }
    var user:    User
    var profile: UserProfile?
    var displayName: String { profile?.fullName.isEmpty == false ? profile!.fullName : user.email }
    var shopName: String    { profile?.shopName ?? "" }
}
