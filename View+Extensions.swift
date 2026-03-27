import SwiftUI

extension View {

    // MARK: - Corner radius for specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    // MARK: - Fade + slide in on appear
    func fadeSlideIn(delay: Double = 0) -> some View {
        self.modifier(FadeSlideInModifier(delay: delay))
    }

    // MARK: - Shimmer loading effect
    func shimmer(isActive: Bool) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Rounded corner shape
struct RoundedCorner: Shape {
    var radius: CGFloat  = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Fade slide in modifier
struct FadeSlideInModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Press button style
struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Shimmer modifier
struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: phase * geo.size.width * 2 - geo.size.width)
                    }
                    .clipped()
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}
