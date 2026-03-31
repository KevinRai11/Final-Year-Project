import SwiftUI

struct AdminDashboardView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var adminVM: AdminViewModel
    @State private var showCreateAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Admin Dashboard").font(AppFont.title2)
                            Text("Manage the AdoptBuddy platform").font(AppFont.body).foregroundColor(.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "shield.fill").font(.system(size: 36)).foregroundColor(.brand)
                    }
                    .padding(.horizontal).padding(.top, Spacing.sm)

                    // Stats grid
                    if adminVM.isLoadingDashboard {
                        ProgressView("Loading dashboard...").padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                            StatCard(title: "Total Users",    value: "\(adminVM.totalUsers)",    icon: "person.2.fill",      color: .blue)
                            StatCard(title: "Total Pets",     value: "\(adminVM.totalPets)",     icon: "pawprint.fill",       color: .brand)
                            StatCard(title: "Adoptions",      value: "\(adminVM.totalAdoptions)",icon: "heart.fill",          color: .success)
                            StatCard(title: "Pending Verify", value: "\(adminVM.pendingVerifications)", icon: "checkmark.shield.fill",
                                     color: adminVM.pendingVerifications > 0 ? .warning : .textSecondary)
                            StatCard(title: "Banned Users",   value: "\(adminVM.bannedUsers)",   icon: "person.fill.xmark",
                                     color: adminVM.bannedUsers > 0 ? .danger : .textSecondary)
                        }
                        .padding(.horizontal)
                    }

                    // Quick Actions
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Quick Actions").font(AppFont.title3).padding(.horizontal)
                        VStack(spacing: 0) {
                            AdminActionRow(icon: "person.badge.plus", title: "Create Shop Account",
                                           subtitle: "Add a new pet shop or shelter",
                                           color: .brand) { showCreateAccount = true }
                            Divider().padding(.leading, 56)
                            NavigationLink { PetVerificationView(vm: adminVM) } label: {
                                AdminActionRow(icon: "checkmark.shield", title: "Verify Pet Listings",
                                               subtitle: "\(adminVM.pendingVerifications) pending",
                                               color: .warning) {}
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 56)
                            NavigationLink { UserManagementView(vm: adminVM) } label: {
                                AdminActionRow(icon: "person.2", title: "Manage Users",
                                               subtitle: "Ban, unban, view accounts",
                                               color: .purple) {}
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 56)
                            NavigationLink { ReportsView() } label: {
                                AdminActionRow(icon: "chart.bar.fill", title: "View Reports",
                                               subtitle: "Adoption statistics and analytics",
                                               color: .teal) {}
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.cardBg).cornerRadius(14)
                        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius)
                        .padding(.horizontal)
                    }

                    if let success = adminVM.successMessage {
                        MessageBanner(message: success, type: .success) { adminVM.clearMessages() }.padding(.horizontal)
                    }
                    if let error = adminVM.errorMessage {
                        MessageBanner(message: error, type: .error) { adminVM.clearMessages() }.padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color.pageBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .task { await adminVM.loadDashboard() }
            .refreshable { await adminVM.loadDashboard() }
            .sheet(isPresented: $showCreateAccount) { CreateShopAccountView(vm: adminVM) }
        }
    }
}
