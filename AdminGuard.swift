import SwiftUI

struct AdminGuard<Content: View>: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if authViewModel.currentUser?.role == .admin {
            content
        } else {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.danger.opacity(0.5))
                Text("Access Denied")
                    .font(AppFont.title2)
                Text("This section is only accessible to administrators.")
                    .font(AppFont.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
