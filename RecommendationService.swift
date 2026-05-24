import Foundation
import FirebaseFirestore

final class RecommendationService {

    static let shared  = RecommendationService()
    private let db     = Firestore.firestore()
    private let petSvc = PetService.shared
    private init() {}

    // MARK: - SR-F-1.5 Rule-based recommendations
    func getRecommendations(for adopterId: String) async throws -> [Pet] {
        let prefs    = try await fetchPreferences(adopterId: adopterId)
        let snapshot = try await db.collection("pets")
            .whereField("status", isEqualTo: PetStatus.available.rawValue)
            .getDocuments()
        let pets: [Pet] = snapshot.documents.compactMap { doc in
            try? petSvc.decodePet(from: doc.data(), id: doc.documentID)
        }
        let scored = scorePets(pets: pets, preferences: prefs)
        return scored.filter { $0.score > 0 }.sorted { $0.score > $1.score }.map { $0.pet }
    }

    // MARK: - Rule-based scoring (no ML)
    private func scorePets(pets: [Pet], preferences: AdopterPreference) -> [(pet: Pet, score: Int)] {
        return pets.map { pet in
            var score = 0
            if !preferences.preferredSpecies.isEmpty, pet.species.rawValue == preferences.preferredSpecies { score += 3 }
            if !preferences.preferredBreed.isEmpty,   pet.breed.lowercased().contains(preferences.preferredBreed.lowercased()) { score += 3 }
            if !preferences.preferredSize.isEmpty,    pet.size == preferences.preferredSize { score += 2 }
            if !preferences.preferredLocation.isEmpty, pet.location.lowercased().contains(preferences.preferredLocation.lowercased()) { score += 2 }
            if pet.age >= preferences.minAge && pet.age <= preferences.maxAge { score += 2 }
            return (pet: pet, score: score)
        }
    }

    // MARK: - Fetch preferences
    func fetchPreferences(adopterId: String) async throws -> AdopterPreference {
        let doc = try await db.collection("adopterPreferences").document(adopterId).getDocument()
        guard let data = doc.data() else { return AdopterPreference(adopterId: adopterId) }
        return decodePreferences(from: data, adopterId: adopterId)
    }

    // MARK: - SR-F-1.4 Save preferences
    func savePreferences(_ prefs: AdopterPreference) async throws {
        let data: [String: Any] = [
            "adopterId":         prefs.adopterId,
            "preferredSpecies":  prefs.preferredSpecies,
            "preferredBreed":    prefs.preferredBreed,
            "preferredSize":     prefs.preferredSize,
            "preferredLocation": prefs.preferredLocation,
            "minAge":            prefs.minAge,
            "maxAge":            prefs.maxAge
        ]
        try await db.collection("adopterPreferences").document(prefs.adopterId).setData(data, merge: true)
    }

    // MARK: - Decoder
    private func decodePreferences(from data: [String: Any], adopterId: String) -> AdopterPreference {
        var prefs                = AdopterPreference(adopterId: adopterId)
        prefs.preferredSpecies   = data["preferredSpecies"]  as? String ?? ""
        prefs.preferredBreed     = data["preferredBreed"]    as? String ?? ""
        prefs.preferredSize      = data["preferredSize"]     as? String ?? ""
        prefs.preferredLocation  = data["preferredLocation"] as? String ?? ""
        prefs.minAge             = data["minAge"]            as? Int    ?? 0
        prefs.maxAge             = data["maxAge"]            as? Int    ?? 20
        return prefs
    }
}
