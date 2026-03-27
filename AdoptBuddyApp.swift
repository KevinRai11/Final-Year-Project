import SwiftUI
import Firebase

@main
struct AdoptBuddyApp: App {

    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }

    private func configureAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor.systemBackground

        let tabItemAppearance = UITabBarItemAppearance()
        tabItemAppearance.selected.iconColor = UIColor(Color(hex: "#4A6FA5"))
        tabItemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "#4A6FA5")),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        tabItemAppearance.normal.iconColor = UIColor.secondaryLabel
        tabItemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        tabAppearance.stackedLayoutAppearance = tabItemAppearance
        tabAppearance.inlineLayoutAppearance = tabItemAppearance
        tabAppearance.compactInlineLayoutAppearance = tabItemAppearance

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color(hex: "#4A6FA5"))
    }
}
