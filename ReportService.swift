import Foundation
import FirebaseFirestore

final class ReportService {

    static let shared = ReportService()
    private let db    = Firestore.firestore()
    private init() {}

    // MARK: - RP-F-1.0 Generate full report
    func generateReport() async throws -> ReportSummary {
        async let adoptionsSnap  = db.collection("adoptionRequests")
            .whereField("status", isEqualTo: RequestStatus.approved.rawValue).getDocuments()
        async let activePetsSnap = db.collection("pets")
            .whereField("status", isEqualTo: PetStatus.available.rawValue).getDocuments()
        async let allPetsSnap    = db.collection("pets").getDocuments()
        async let usersSnap      = db.collection("users").getDocuments()
        async let pendingSnap    = db.collection("adoptionRequests")
            .whereField("status", isEqualTo: RequestStatus.pending.rawValue).getDocuments()

        let (adoptions, activePets, allPets, users, pending) = try await
            (adoptionsSnap, activePetsSnap, allPetsSnap, usersSnap, pendingSnap)

        // Build petId → breed map
        var petIdToBreed: [String: String] = [:]
        var petIdToSpecies: [String: String] = [:]
        for doc in allPets.documents {
            petIdToBreed[doc.documentID]   = doc.data()["breed"]   as? String ?? "Unknown"
            petIdToSpecies[doc.documentID] = doc.data()["species"] as? String ?? "Unknown"
        }

        // Adoptions by breed
        var breedAdoptions: [String: Int] = [:]
        for doc in adoptions.documents {
            let petId = doc.data()["petId"] as? String ?? ""
            let breed = petIdToBreed[petId] ?? "Unknown"
            breedAdoptions[breed, default: 0] += 1
        }
        let adoptionsByBreed = breedAdoptions.sorted { $0.value > $1.value }
            .prefix(8).map { AdoptionStat(label: $0.key, count: $0.value) }

        // Adoptions by month
        let adoptionsByMonth = aggregateByMonth(documents: adoptions.documents, dateField: "reviewedAt")

        // Adoptions by species
        var speciesCounts: [String: Int] = [:]
        for doc in adoptions.documents {
            let petId   = doc.data()["petId"] as? String ?? ""
            let species = petIdToSpecies[petId] ?? "Unknown"
            speciesCounts[species, default: 0] += 1
        }
        let adoptionsBySpecies = speciesCounts.sorted { $0.value > $1.value }
            .map { AdoptionStat(label: $0.key, count: $0.value) }

        // Users by role
        var adoptersCount = 0, shopsCount = 0
        for doc in users.documents {
            let role = doc.data()["role"] as? String ?? ""
            if role == UserRole.adopter.rawValue { adoptersCount += 1 }
            if role == UserRole.petShop.rawValue { shopsCount += 1 }
        }

        return ReportSummary(
            totalAdoptions:     adoptions.documents.count,
            totalActivePets:    activePets.documents.count,
            totalPets:          allPets.documents.count,
            totalUsers:         users.documents.count,
            totalAdopters:      adoptersCount,
            totalShops:         shopsCount,
            pendingRequests:    pending.documents.count,
            adoptionsByBreed:   Array(adoptionsByBreed),
            adoptionsByMonth:   adoptionsByMonth,
            adoptionsBySpecies: adoptionsBySpecies
        )
    }

    // MARK: - Aggregate by month (last 6 months)
    private func aggregateByMonth(documents: [QueryDocumentSnapshot], dateField: String) -> [AdoptionStat] {
        let calendar = Calendar.current
        let now      = Date()
        var monthCounts: [String: Int] = [:]
        for offset in (0..<6).reversed() {
            if let date = calendar.date(byAdding: .month, value: -offset, to: now) {
                monthCounts[monthKey(from: date)] = 0
            }
        }
        for doc in documents {
            if let ts = doc.data()[dateField] as? Timestamp {
                let key = monthKey(from: ts.dateValue())
                if monthCounts[key] != nil { monthCounts[key]! += 1 }
            }
        }
        return monthCounts.sorted { $0.key < $1.key }
            .map { AdoptionStat(label: shortMonthLabel(from: $0.key), count: $0.value) }
    }

    private func monthKey(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f.string(from: date)
    }

    private func shortMonthLabel(from key: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: key) else { return key }
        let d = DateFormatter(); d.dateFormat = "MMM yy"; return d.string(from: date)
    }

    // MARK: - RP-F-1.1 Generate CSV
    func generateCSV(from summary: ReportSummary) -> String {
        var csv = "AdoptBuddy Adoption Report\n"
        csv += "Generated: \(Date().formatted(date: .long, time: .shortened))\n\n"
        csv += "SUMMARY\nMetric,Value\n"
        csv += "Total Adoptions,\(summary.totalAdoptions)\n"
        csv += "Active Pets,\(summary.totalActivePets)\n"
        csv += "Total Pets Listed,\(summary.totalPets)\n"
        csv += "Total Users,\(summary.totalUsers)\n"
        csv += "Total Adopters,\(summary.totalAdopters)\n"
        csv += "Total Shops/Shelters,\(summary.totalShops)\n"
        csv += "Pending Requests,\(summary.pendingRequests)\n\n"
        csv += "ADOPTIONS BY BREED\nBreed,Count\n"
        for stat in summary.adoptionsByBreed { csv += "\(stat.label),\(stat.count)\n" }
        csv += "\nADOPTIONS BY MONTH\nMonth,Count\n"
        for stat in summary.adoptionsByMonth { csv += "\(stat.label),\(stat.count)\n" }
        csv += "\nADOPTIONS BY SPECIES\nSpecies,Count\n"
        for stat in summary.adoptionsBySpecies { csv += "\(stat.label),\(stat.count)\n" }
        return csv
    }
}
