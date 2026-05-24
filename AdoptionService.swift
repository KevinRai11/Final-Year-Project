import Foundation
import FirebaseFirestore

final class AdoptionService {

    static let shared = AdoptionService()
    private let db    = Firestore.firestore()
    private init() {}

    // MARK: - PM-F-1.1 Submit adoption request
    func submitRequest(_ request: AdoptionRequest) async throws {
        let existing = try await db.collection("adoptionRequests")
            .whereField("petId",     isEqualTo: request.petId)
            .whereField("adopterId", isEqualTo: request.adopterId)
            .whereField("status",    isEqualTo: RequestStatus.pending.rawValue)
            .getDocuments()
        guard existing.documents.isEmpty else { throw AdoptionError.duplicateRequest }

        try await db.collection("adoptionRequests")
            .document(request.id)
            .setData(encodeRequest(request))
        try await PetService.shared.updatePetStatus(petId: request.petId, status: .pending)
    }

    // MARK: - PM-F-1.2 Approve request
    func approveRequest(_ request: AdoptionRequest, notes: String = "") async throws {
        try await db.collection("adoptionRequests").document(request.id).updateData([
            "status":     RequestStatus.approved.rawValue,
            "notes":      notes,
            "reviewedAt": Timestamp(date: Date())
        ])
        try await PetService.shared.updatePetStatus(petId: request.petId, status: .adopted)
    }

    // MARK: - PM-F-1.2 Reject request
    func rejectRequest(_ request: AdoptionRequest, reason: String = "") async throws {
        try await db.collection("adoptionRequests").document(request.id).updateData([
            "status":     RequestStatus.rejected.rawValue,
            "notes":      reason,
            "reviewedAt": Timestamp(date: Date())
        ])
        try await PetService.shared.updatePetStatus(petId: request.petId, status: .available)
    }

    // MARK: - PM-F-1.5 Fetch requests for adopter
    func fetchRequestsForAdopter(adopterId: String) async throws -> [AdoptionRequest] {
        let snapshot = try await db.collection("adoptionRequests")
            .whereField("adopterId", isEqualTo: adopterId)
            .order(by: "submittedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? decodeRequest(from: $0.data(), id: $0.documentID) }
    }

    // MARK: - Fetch requests for shop
    func fetchRequestsForShop(shopId: String) async throws -> [AdoptionRequest] {
        let snapshot = try await db.collection("adoptionRequests")
            .whereField("shopId", isEqualTo: shopId)
            .order(by: "submittedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? decodeRequest(from: $0.data(), id: $0.documentID) }
    }

    // MARK: - Fetch all requests (admin)
    func fetchAllRequests() async throws -> [AdoptionRequest] {
        let snapshot = try await db.collection("adoptionRequests")
            .order(by: "submittedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? decodeRequest(from: $0.data(), id: $0.documentID) }
    }

    // MARK: - Encoder
    private func encodeRequest(_ r: AdoptionRequest) -> [String: Any] {
        var data: [String: Any] = [
            "petId":       r.petId,
            "petName":     r.petName,
            "petImageURL": r.petImageURL,
            "adopterId":   r.adopterId,
            "adopterName": r.adopterName,
            "shopId":      r.shopId,
            "status":      r.status.rawValue,
            "notes":       r.notes,
            "submittedAt": Timestamp(date: r.submittedAt)
        ]
        if let reviewed = r.reviewedAt { data["reviewedAt"] = Timestamp(date: reviewed) }
        return data
    }

    // MARK: - Decoder
    private func decodeRequest(from data: [String: Any], id: String) throws -> AdoptionRequest {
        guard
            let petId       = data["petId"]       as? String,
            let petName     = data["petName"]     as? String,
            let petImageURL = data["petImageURL"] as? String,
            let adopterId   = data["adopterId"]   as? String,
            let adopterName = data["adopterName"] as? String,
            let shopId      = data["shopId"]      as? String,
            let statusRaw   = data["status"]      as? String,
            let status      = RequestStatus(rawValue: statusRaw)
        else { throw AdoptionError.decodingFailed }

        var req         = AdoptionRequest(petId: petId, petName: petName,
                                          petImageURL: petImageURL,
                                          adopterId: adopterId,
                                          adopterName: adopterName, shopId: shopId)
        req.id          = id
        req.status      = status
        req.notes       = data["notes"] as? String ?? ""
        if let ts = data["submittedAt"] as? Timestamp { req.submittedAt = ts.dateValue() }
        if let ts = data["reviewedAt"]  as? Timestamp { req.reviewedAt  = ts.dateValue() }
        return req
    }
}

enum AdoptionError: LocalizedError {
    case duplicateRequest, decodingFailed
    var errorDescription: String? {
        switch self {
        case .duplicateRequest: return "You already have a pending request for this pet."
        case .decodingFailed:   return "Failed to load adoption request."
        }
    }
}
