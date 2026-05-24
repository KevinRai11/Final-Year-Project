import Foundation
import FirebaseFirestore

struct SearchCriteria {
    var keyword:      String     = ""
    var species:      String     = ""
    var breed:        String     = ""
    var gender:       String     = ""
    var size:         String     = ""
    var location:     String     = ""
    var minAge:       Int        = 0
    var maxAge:       Int        = 20
    var maxPrice:     Double     = 100_000
    var sortOption:   SortOption = .newest
    var statusFilter: String     = PetStatus.available.rawValue
}

enum SortOption: String, CaseIterable, Identifiable {
    case newest    = "Newest First"
    case oldest    = "Oldest First"
    case ageLow    = "Age: Low to High"
    case ageHigh   = "Age: High to Low"
    case priceLow  = "Price: Low to High"
    case priceHigh = "Price: High to Low"
    var id: String { rawValue }
}

final class SearchService {

    static let shared  = SearchService()
    private let db     = Firestore.firestore()
    private let petSvc = PetService.shared
    private init() {}

    // MARK: - SR-F-1.0 / SR-F-1.1 Search & filter
    func search(criteria: SearchCriteria) async throws -> [Pet] {
        var query: Query = db.collection("pets")
        if !criteria.statusFilter.isEmpty {
            query = query.whereField("status", isEqualTo: criteria.statusFilter)
        } else {
            query = query.whereField("status", in: [
                PetStatus.available.rawValue,
                PetStatus.pending.rawValue,
                PetStatus.adopted.rawValue
            ])
        }
        let snapshot = try await query.getDocuments()
        var pets: [Pet] = snapshot.documents.compactMap { doc in
            try? petSvc.decodePet(from: doc.data(), id: doc.documentID)
        }
        pets = applyFilters(pets: pets, criteria: criteria)
        pets = sortPets(pets: pets, option: criteria.sortOption)
        return pets
    }

    // MARK: - SR-F-1.1 Apply filters client-side
    private func applyFilters(pets: [Pet], criteria: SearchCriteria) -> [Pet] {
        return pets.filter { pet in
            let keywordMatch: Bool
            if criteria.keyword.isEmpty {
                keywordMatch = true
            } else {
                let kw = criteria.keyword.lowercased()
                keywordMatch = pet.name.lowercased().contains(kw)     ||
                               pet.breed.lowercased().contains(kw)    ||
                               pet.species.rawValue.lowercased().contains(kw) ||
                               pet.location.lowercased().contains(kw)
            }
            let speciesMatch  = criteria.species.isEmpty  || pet.species.rawValue == criteria.species
            let breedMatch    = criteria.breed.isEmpty    || pet.breed.lowercased().contains(criteria.breed.lowercased())
            let genderMatch   = criteria.gender.isEmpty   || pet.gender == criteria.gender
            let sizeMatch     = criteria.size.isEmpty     || pet.size == criteria.size
            let locationMatch = criteria.location.isEmpty || pet.location.lowercased().contains(criteria.location.lowercased())
            let ageMatch      = pet.age >= criteria.minAge && pet.age <= criteria.maxAge
            let priceMatch    = pet.price <= criteria.maxPrice

            return keywordMatch && speciesMatch && breedMatch &&
                   genderMatch  && sizeMatch    && locationMatch &&
                   ageMatch     && priceMatch
        }
    }

    // MARK: - SR-F-1.2 Sort
    private func sortPets(pets: [Pet], option: SortOption) -> [Pet] {
        switch option {
        case .newest:    return pets.sorted { $0.createdAt > $1.createdAt }
        case .oldest:    return pets.sorted { $0.createdAt < $1.createdAt }
        case .ageLow:    return pets.sorted { $0.age < $1.age }
        case .ageHigh:   return pets.sorted { $0.age > $1.age }
        case .priceLow:  return pets.sorted { $0.price < $1.price }
        case .priceHigh: return pets.sorted { $0.price > $1.price }
        }
    }
}
