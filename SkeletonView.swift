import SwiftUI

struct PetCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color(.systemGray5))
                .frame(height: 160)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 100, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 80,  height: 11)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 60,  height: 11)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 50,  height: 20)
            }
            .padding(Spacing.md)
        }
        .cornerRadius(Radius.md)
        .shimmer(isActive: true)
    }
}

struct PetGridSkeleton: View {
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in PetCardSkeleton() }
        }
        .padding(.horizontal)
        .allowsHitTesting(false)
    }
}
