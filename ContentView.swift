import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isLoading {
                SplashView()
            } else if authViewModel.currentUser == nil {
                LoginView()
            } else {
                switch authViewModel.currentUser?.role {
                case .admin:
                    AdminRootView()
                case .petShop:
                    PetShopRootView()
                default:
                    AdopterRootView()
                }
            }
        }
        .animation(.easeInOut, value: authViewModel.currentUser == nil)
    }
}
