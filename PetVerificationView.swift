import SwiftUI

struct PetVerificationView: View {

    @ObservedObject var vm: AdminViewModel
    @State private var selectedPet:     Pet?   = nil
    @State private var rejectionReason: String = ""
    @State private var showRejectSheet: Bool   = false
    @State private var petToReject:     Pet?   = nil

    var body: some View {
        Group {
            if vm.isLoadingPets {
                ProgressView("Loading unverified pets...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.unverifiedPets.isEmpty {
                EmptyStateView(icon: "checkmark.shield.fill", title: "All Clear!",
                               message: "No pet listings waiting for verification.")
            } else {
                List {
                    Section {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "info.circle.fill").foregroundColor(.warning)
                            Text("These listings are hidden from adopters until approved.")
                                .font(AppFont.caption).foregroundColor(.textSecondary)
                        }
                        .listRowBackground(Color.warning.opacity(0.08))
                    }

                    Section("\(vm.unverifiedPets.count) Pending") {
                        ForEach(vm.unverifiedPets) { pet in
                            VerificationPetRow(
                                pet: pet,
                                onApprove: { Task { await vm.approvePet(petId: pet.id) } },
                                onReject:  { petToReject = pet; rejectionReason = ""; showRejectSheet = true },
                                onTap:     { selectedPet = pet }
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Verify Listings").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await vm.loadUnverifiedPets() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await vm.loadUnverifiedPets() }
        .refreshable { await vm.loadUnverifiedPets() }
        .sheet(item: $selectedPet) { pet in
            NavigationStack {
                PetDetailView(pet: pet)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { selectedPet = nil } } }
            }
        }
        .sheet(isPresented: $showRejectSheet) {
            NavigationStack {
                VStack(spacing: Spacing.xl) {
                    if let pet = petToReject {
                        HStack(spacing: Spacing.md) {
                            AsyncImage(url: URL(string: pet.imageURLs.first ?? "")) { phase in
                                switch phase { case .success(let img): img.resizable().scaledToFill(); default: Color(.systemGray5) }
                            }
                            .frame(width: 60, height: 60).clipped().cornerRadius(Radius.sm)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pet.name).font(AppFont.title3)
                                Text("\(pet.breed) · \(pet.shopName)").font(AppFont.caption).foregroundColor(.textSecondary)
                            }
                            Spacer()
                        }
                        .padding().background(Color(.systemGray6)).cornerRadius(Radius.md)
                    }
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Reason for rejection (optional)").font(AppFont.bodyMedium)
                        TextEditor(text: $rejectionReason).frame(minHeight: 100)
                            .padding(Spacing.sm).background(Color(.systemGray6)).cornerRadius(Radius.sm)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        guard let pet = petToReject else { return }
                        Task { await vm.rejectPet(petId: pet.id, reason: rejectionReason) }
                        showRejectSheet = false
                    } label: {
                        Text("Confirm Rejection").font(AppFont.bodyMedium).frame(maxWidth: .infinity).padding()
                            .background(Color.danger).foregroundColor(.white).cornerRadius(Radius.md)
                    }
                }
                .padding()
                .navigationTitle("Reject Listing").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showRejectSheet = false } } }
            }
            .presentationDetents([.medium])
        }
        .safeAreaInset(edge: .bottom) {
            if let success = vm.successMessage {
                MessageBanner(message: success, type: .success) { vm.clearMessages() }
                    .padding().transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: vm.successMessage)
    }
}

// MARK: - Verification Pet Row
struct VerificationPetRow: View {
    let pet: Pet
    let onApprove: () -> Void
    let onReject:  () -> Void
    let onTap:     () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button(action: onTap) {
                HStack(spacing: Spacing.md) {
                    AsyncImage(url: URL(string: pet.imageURLs.first ?? "")) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: PetImagePlaceholder()
                        }
                    }
                    .frame(width: 64, height: 64).clipped().cornerRadius(Radius.sm)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pet.name).font(AppFont.bodyMedium).foregroundColor(.textPrimary)
                        Text("\(pet.species.rawValue) · \(pet.breed) · \(pet.age)yr").font(AppFont.caption).foregroundColor(.textSecondary)
                        Text("From: \(pet.shopName)").font(AppFont.caption).foregroundColor(.brand)
                        Text("Rs. \(Int(pet.price)) · \(pet.location)").font(AppFont.caption2).foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "eye").font(AppFont.caption).foregroundColor(.textSecondary)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: Spacing.sm) {
                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark.circle").font(AppFont.bodyMedium)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.danger.opacity(0.1)).foregroundColor(.danger).cornerRadius(Radius.sm)
                }
                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark.circle").font(AppFont.bodyMedium)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.success.opacity(0.12)).foregroundColor(.success).cornerRadius(Radius.sm)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}
