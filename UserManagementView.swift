import SwiftUI

// MARK: - User Management View
struct UserManagementView: View {

    @ObservedObject var vm: AdminViewModel
    @State private var searchText    = ""
    @State private var filterRole:   String = ""
    @State private var userToAction: UserWithProfile?
    @State private var showBanConfirm = false

    private var filteredUsers: [UserWithProfile] {
        var users = vm.allUsers
        if !filterRole.isEmpty { users = users.filter { $0.user.role.rawValue == filterRole } }
        if !searchText.isEmpty {
            users = users.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.user.email.localizedCaseInsensitiveContains(searchText)  ||
                $0.shopName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return users
    }

    var body: some View {
        Group {
            if vm.isLoadingUsers {
                ProgressView("Loading users...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        Picker("Filter", selection: $filterRole) {
                            Text("All").tag(""); Text("Adopters").tag(UserRole.adopter.rawValue)
                            Text("Shops").tag(UserRole.petShop.rawValue)
                        }
                        .pickerStyle(.segmented).listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    Section {
                        HStack(spacing: Spacing.xl) {
                            Label("\(vm.allUsers.count) Total", systemImage: "person.2")
                                .font(AppFont.caption).foregroundColor(.textSecondary)
                            Label("\(vm.bannedUsers) Banned", systemImage: "person.fill.xmark")
                                .font(AppFont.caption).foregroundColor(.danger)
                        }
                        .listRowBackground(Color.clear)
                    }
                    Section("\(filteredUsers.count) users") {
                        if filteredUsers.isEmpty {
                            Text("No users match this filter.").foregroundColor(.textSecondary).font(AppFont.body)
                        } else {
                            ForEach(filteredUsers) { item in
                                UserManagementRow(item: item,
                                                  onBan:   { userToAction = item; showBanConfirm = true },
                                                  onUnban: { Task { await vm.unbanUser(userId: item.user.id) } })
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search by name or email")
            }
        }
        .navigationTitle("Manage Users").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await vm.loadAllUsers() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .task { await vm.loadAllUsers() }
        .refreshable { await vm.loadAllUsers() }
        .alert("Ban User", isPresented: $showBanConfirm, presenting: userToAction) { item in
            Button("Cancel", role: .cancel) {}
            Button("Ban", role: .destructive) { Task { await vm.banUser(userId: item.user.id) } }
        } message: { item in
            Text("Are you sure you want to ban \(item.displayName)? They will be immediately logged out.")
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if let success = vm.successMessage {
                    MessageBanner(message: success, type: .success) { vm.clearMessages() }
                        .padding().transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let error = vm.errorMessage {
                    MessageBanner(message: error, type: .error) { vm.clearMessages() }.padding()
                }
            }
            .animation(.easeInOut, value: vm.successMessage)
        }
    }
}

// MARK: - User Management Row
struct UserManagementRow: View {
    let item:    UserWithProfile
    let onBan:   () -> Void
    let onUnban: () -> Void

    var roleColor: Color { switch item.user.role { case .admin: return .purple; case .petShop: return .brand; case .adopter: return .success } }
    var roleIcon:  String { switch item.user.role { case .admin: return "shield.fill"; case .petShop: return "storefront.fill"; case .adopter: return "person.fill" } }

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(item.user.isBanned ? Color.danger.opacity(0.15) : roleColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.user.isBanned ? "person.fill.xmark" : roleIcon)
                    .foregroundColor(item.user.isBanned ? .danger : roleColor).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.sm) {
                    Text(item.displayName).font(AppFont.bodyMedium).lineLimit(1)
                    if item.user.isBanned {
                        Text("BANNED").font(AppFont.caption2Med)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.danger.opacity(0.15)).foregroundColor(.danger).cornerRadius(4)
                    }
                }
                Text(item.user.email).font(AppFont.caption).foregroundColor(.textSecondary).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: roleIcon).font(AppFont.caption2).foregroundColor(roleColor)
                    Text(item.user.role.rawValue.capitalized).font(AppFont.caption2).foregroundColor(roleColor)
                    if !item.shopName.isEmpty {
                        Text("· \(item.shopName)").font(AppFont.caption2).foregroundColor(.textSecondary)
                    }
                }
            }
            Spacer()
            if item.user.role != .admin {
                if item.user.isBanned {
                    Button("Unban", action: onUnban)
                        .font(AppFont.caption).fontWeight(.semibold).foregroundColor(.success)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.success.opacity(0.12)).cornerRadius(Radius.sm)
                } else {
                    Button("Ban", action: onBan)
                        .font(AppFont.caption).fontWeight(.semibold).foregroundColor(.danger)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.danger.opacity(0.1)).cornerRadius(Radius.sm)
                }
            }
        }
        .padding(.vertical, 4).opacity(item.user.isBanned ? 0.7 : 1.0)
    }
}

// MARK: - Create Shop Account View
struct CreateShopAccountView: View {

    @ObservedObject var vm: AdminViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "info.circle.fill").foregroundColor(.brand)
                        Text("A password reset email will be sent so the shop can set their own password.")
                            .font(AppFont.caption).foregroundColor(.textSecondary)
                    }
                    .listRowBackground(Color.brandLight)
                }
                Section("Contact Person") {
                    HStack { Image(systemName: "person").foregroundColor(.textSecondary); TextField("Full Name", text: $vm.newShopFullName) }
                    HStack { Image(systemName: "envelope").foregroundColor(.textSecondary)
                        TextField("Email Address", text: $vm.newShopEmail).keyboardType(.emailAddress).autocapitalization(.none)
                    }
                }
                Section("Shop / Shelter Details") {
                    HStack { Image(systemName: "storefront").foregroundColor(.textSecondary); TextField("Shop or Shelter Name", text: $vm.newShopName) }
                }
                if vm.accountCreated {
                    Section { HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.success)
                        Text(vm.successMessage ?? "Account created!").font(.footnote).foregroundColor(.success)
                    } }
                }
                if let error = vm.errorMessage {
                    Section { Text(error).foregroundColor(.danger).font(.footnote) }
                }
                Section {
                    Button { Task { await vm.createShopAccount() } } label: {
                        HStack {
                            if vm.isCreatingAccount { ProgressView().tint(.white) }
                            else { Label("Create Account", systemImage: "person.badge.plus").font(AppFont.bodyMedium) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color(hex: "#2D3748")).foregroundColor(.white).cornerRadius(Radius.sm)
                    }
                    .disabled(vm.isCreatingAccount)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .navigationTitle("Create Shop Account").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.clearMessages(); vm.accountCreated = false; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.accountCreated {
                        Button("Done") { vm.clearMessages(); vm.accountCreated = false; dismiss() }
                            .foregroundColor(.success)
                    }
                }
            }
        }
    }
}
