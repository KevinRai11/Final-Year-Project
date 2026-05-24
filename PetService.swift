import Foundation
import FirebaseFirestore

final class PetService {

    static let shared = PetService()
    private let db    = Firestore.firestore()
    private init() {}

    // MARK: - PM-F-1.0 Create pet
    func createPet(_ pet: Pet) async throws -> String {
        let docRef = db.collection("pets").document(pet.id)
        try await docRef.setData(encodePet(pet))
        return pet.id
    }

    // MARK: - PM-F-1.3 Update pet
    func updatePet(_ pet: Pet) async throws {
        var data          = encodePet(pet)
        data["updatedAt"] = Timestamp(date: Date())
        try await db.collection("pets").document(pet.id).updateData(data)
    }

    // MARK: - PM-F-1.3 Delete pet
    func deletePet(petId: String) async throws {
        try await db.collection("pets").document(petId).delete()
    }

    // MARK: - Fetch single pet
    func fetchPet(petId: String) async throws -> Pet {
        let doc = try await db.collection("pets").document(petId).getDocument()
        guard let data = doc.data() else { throw PetError.notFound }
        return try decodePet(from: data, id: doc.documentID)
    }

    // MARK: - Fetch available pets (adopter view)
    func fetchAvailablePets() async throws -> [Pet] {
        let snapshot = try await db.collection("pets")
            .whereField("status", isEqualTo: PetStatus.available.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.map { try decodePet(from: $0.data(), id: $0.documentID) }
    }

    // MARK: - Fetch pets by shop
    func fetchPetsByShop(shopId: String) async throws -> [Pet] {
        let snapshot = try await db.collection("pets")
            .whereField("shopId", isEqualTo: shopId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.map { try decodePet(from: $0.data(), id: $0.documentID) }
    }

    // MARK: - Fetch unverified pets (admin)
    func fetchUnverifiedPets() async throws -> [Pet] {
        let snapshot = try await db.collection("pets")
            .whereField("status", isEqualTo: PetStatus.unverified.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.map { try decodePet(from: $0.data(), id: $0.documentID) }
    }

    // MARK: - Admin verify pet — AV-F-1.0
    func verifyPet(petId: String) async throws {
        try await db.collection("pets").document(petId).updateData([
            "status":    PetStatus.available.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Admin reject pet — AV-F-1.0
    func rejectPet(petId: String) async throws {
        try await db.collection("pets").document(petId).updateData([
            "status":    PetStatus.rejected.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Update pet status
    func updatePetStatus(petId: String, status: PetStatus) async throws {
        try await db.collection("pets").document(petId).updateData([
            "status":    status.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Encoder
    private func encodePet(_ pet: Pet) -> [String: Any] {
        return [
            "shopId":       pet.shopId,
            "shopName":     pet.shopName,
            "name":         pet.name,
            "species":      pet.species.rawValue,
            "breed":        pet.breed,
            "age":          pet.age,
            "gender":       pet.gender,
            "size":         pet.size,
            "description":  pet.description,
            "healthStatus": pet.healthStatus,
            "location":     pet.location,
            "price":        pet.price,
            "status":       pet.status.rawValue,
            "imageURLs":    pet.imageURLs,
            "createdAt":    Timestamp(date: pet.createdAt),
            "updatedAt":    Timestamp(date: pet.updatedAt)
        ]
    }

    // MARK: - Decoder
    func decodePet(from data: [String: Any], id: String) throws -> Pet {
        guard
            let shopId     = data["shopId"]     as? String,
            let shopName   = data["shopName"]   as? String,
            let name       = data["name"]       as? String,
            let speciesRaw = data["species"]    as? String,
            let species    = PetSpecies(rawValue: speciesRaw),
            let statusRaw  = data["status"]     as? String,
            let status     = PetStatus(rawValue: statusRaw)
        else { throw PetError.decodingFailed }

        var pet           = Pet(shopId: shopId, shopName: shopName, name: name)
        pet.id            = id
        pet.species       = species
        pet.breed         = data["breed"]        as? String ?? ""
        pet.age           = data["age"]          as? Int    ?? 0
        pet.gender        = data["gender"]       as? String ?? "Male"
        pet.size          = data["size"]         as? String ?? "Medium"
        pet.description   = data["description"]  as? String ?? ""
        pet.healthStatus  = data["healthStatus"] as? String ?? ""
        pet.location      = data["location"]     as? String ?? ""
        pet.price         = data["price"]        as? Double ?? 0
        pet.status        = status
        pet.imageURLs     = data["imageURLs"]    as? [String] ?? []
        if let ts = data["createdAt"] as? Timestamp { pet.createdAt = ts.dateValue() }
        if let ts = data["updatedAt"] as? Timestamp { pet.updatedAt = ts.dateValue() }
        return pet
    }
}

enum PetError: LocalizedError {
    case notFound, decodingFailed
    var errorDescription: String? {
        switch self {
        case .notFound:       return "Pet not found."
        case .decodingFailed: return "Failed to load pet data."
        }
    }
}
