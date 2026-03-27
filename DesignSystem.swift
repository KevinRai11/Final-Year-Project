import SwiftUI

// MARK: - Colour Palette
extension Color {
    static let brand        = Color("PrimaryColor")
    static let brandLight   = Color("PrimaryColor").opacity(0.12)
    static let brandMid     = Color("PrimaryColor").opacity(0.5)
    static let success      = Color(hex: "#34C759")
    static let warning      = Color(hex: "#FF9F0A")
    static let danger       = Color(hex: "#FF3B30")
    static let info         = Color(hex: "#5AC8FA")
    static let cardBg       = Color(.systemBackground)
    static let pageBg       = Color(.systemGray6)
    static let inputBg      = Color(.systemGray6)
    static let divider      = Color(.systemGray4)
    static let textPrimary   = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary  = Color(.tertiaryLabel)

    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography
struct AppFont {
    static let largeTitle  = Font.system(size: 34, weight: .bold,     design: .rounded)
    static let title1      = Font.system(size: 28, weight: .bold,     design: .rounded)
    static let title2      = Font.system(size: 22, weight: .bold,     design: .rounded)
    static let title3      = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let bodyLarge   = Font.system(size: 17, weight: .regular)
    static let body        = Font.system(size: 15, weight: .regular)
    static let bodyMedium  = Font.system(size: 15, weight: .medium)
    static let caption     = Font.system(size: 13, weight: .regular)
    static let captionMed  = Font.system(size: 13, weight: .medium)
    static let caption2    = Font.system(size: 11, weight: .regular)
    static let caption2Med = Font.system(size: 11, weight: .semibold)
}

// MARK: - Spacing
struct Spacing {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius
struct Radius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let full: CGFloat = 100
}

// MARK: - Shadows
struct AppShadow {
    static let card   = ShadowConfig(color: .black.opacity(0.07), radius: 8,  x: 0, y: 2)
    static let soft   = ShadowConfig(color: .black.opacity(0.04), radius: 4,  x: 0, y: 1)
    static let strong = ShadowConfig(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
}

struct ShadowConfig {
    let color:  Color
    let radius: CGFloat
    let x:      CGFloat
    let y:      CGFloat
}

// MARK: - Card Modifier
struct CardModifier: ViewModifier {
    var padding: CGFloat = Spacing.lg
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBg)
            .cornerRadius(Radius.lg)
            .shadow(color: AppShadow.card.color,
                    radius: AppShadow.card.radius,
                    x: AppShadow.card.x,
                    y: AppShadow.card.y)
    }
}

extension View {
    func cardStyle(padding: CGFloat = Spacing.lg) -> some View {
        modifier(CardModifier(padding: padding))
    }
}
