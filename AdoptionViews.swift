import Foundation
import SwiftUI

// MARK: - Adoption ViewModel
@MainActor
final class AdoptionViewModel: ObservableObject {
    @Published var requests:     [AdoptionRequest] = []
    @Published var isLoading     = false
    @Published var errorMessage: String?
    private let adoptionService  = AdoptionService.shared

    func loadForAdopter(adopterId: String) async {
        isLoading = true
        do { requests = try await adoptionService.fetchRequestsForAdopter(adopterId: adopterId) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func loadForShop(shopId: String) async {
        isLoading = true
        do { requests = try await adoptionService.fetchRequestsForShop(shopId: shopId) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}

// MARK: - Adoption Request View
struct AdoptionRequestView: View {
    let pet: Pet
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var notes        = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit    = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    HStack(spacing: Spacing.lg) {
                        AsyncImage(url: URL(string: pet.imageURLs.first ?? "")) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Color(.systemGray5)
                            }
                        }
                        .frame(width: 70, height: 70).clipped().cornerRadius(Radius.sm)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pet.name).font(AppFont.title3)
                            Text("\(pet.breed) · \(pet.age) yr").font(AppFont.body).foregroundColor(.textSecondary)
                            Text(pet.location).font(AppFont.caption).foregroundColor(.textSecondary)
                        }
                        Spacer()
                    }
                    .padding().background(Color(.systemGray6)).cornerRadius(Radius.md)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Message to shelter (optional)").font(AppFont.bodyMedium)
                        TextEditor(text: $notes).frame(minHeight: 120)
                            .padding(Spacing.sm).background(Color(.systemGray6)).cornerRadius(Radius.sm)
                    }

                    if let error = errorMessage { ErrorBanner(message: error) }

                    if didSubmit {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundColor(.success)
                            Text("Request Submitted!").font(AppFont.title3)
                            Text("The shelter will review your request and get back to you.")
                                .font(AppFont.body).foregroundColor(.textSecondary).multilineTextAlignment(.center)
                        }
                        .padding()
                    }

                    if !didSubmit {
                        PrimaryButton(title: "Submit Request", isLoading: isSubmitting) {
                            Task { await submitRequest() }
                        }
                    } else {
                        Button("Done") { dismiss() }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(.systemGray6)).cornerRadius(Radius.md)
                    }
                }
                .padding()
            }
            .navigationTitle("Adoption Request").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func submitRequest() async {
        guard let user = authViewModel.currentUser else { return }
        isSubmitting = true; errorMessage = nil
        do {
            let profile = try await UserService.shared.fetchProfile(userId: user.id)
            var request = AdoptionRequest(petId: pet.id, petName: pet.name,
                                          petImageURL: pet.imageURLs.first ?? "",
                                          adopterId: user.id, adopterName: profile.fullName,
                                          shopId: pet.shopId)
            request.notes = notes
            try await AdoptionService.shared.submitRequest(request)
            didSubmit = true
        } catch { errorMessage = error.localizedDescription }
        isSubmitting = false
    }
}

// MARK: - My Requests View (Adopter)
struct MyRequestsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = AdoptionViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading { ProgressView("Loading requests...").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if vm.requests.isEmpty {
                    EmptyStateView(icon: "tray", title: "No Requests Yet",
                                   message: "Your adoption requests will appear here.")
                } else {
                    List(vm.requests) { request in RequestRow(request: request) }
                        .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Requests")
            .task { if let uid = authViewModel.currentUser?.id { await vm.loadForAdopter(adopterId: uid) } }
            .refreshable { if let uid = authViewModel.currentUser?.id { await vm.loadForAdopter(adopterId: uid) } }
        }
    }
}

// MARK: - Incoming Requests View (Pet Shop)
struct IncomingRequestsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = AdoptionViewModel()
    @State private var selectedRequest: AdoptionRequest?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading { ProgressView("Loading...").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if vm.requests.isEmpty {
                    EmptyStateView(icon: "tray.and.arrow.down", title: "No Requests",
                                   message: "Adoption requests will appear here.")
                } else {
                    List(vm.requests) { request in
                        RequestRow(request: request, showActions: true) { selectedRequest = request }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Incoming Requests")
            .task { if let uid = authViewModel.currentUser?.id { await vm.loadForShop(shopId: uid) } }
            .refreshable { if let uid = authViewModel.currentUser?.id { await vm.loadForShop(shopId: uid) } }
            .sheet(item: $selectedRequest) { request in
                RequestDecisionView(request: request) {
                    Task { if let uid = authViewModel.currentUser?.id { await vm.loadForShop(shopId: uid) } }
                }
            }
        }
    }
}

// MARK: - Request Row
struct RequestRow: View {
    let request: AdoptionRequest
    var showActions: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            AsyncImage(url: URL(string: request.petImageURL)) { phase in
                switch phase { case .success(let img): img.resizable().scaledToFill(); default: Color(.systemGray5) }
            }
            .frame(width: 56, height: 56).clipped().cornerRadius(Radius.sm)
            VStack(alignment: .leading, spacing: 4) {
                Text(request.petName).font(AppFont.bodyMedium)
                if showActions { Text("From: \(request.adopterName)").font(AppFont.caption).foregroundColor(.textSecondary) }
                Text(request.submittedAt.shortDate).font(AppFont.caption2).foregroundColor(.textSecondary)
            }
            Spacer()
            RequestStatusBadge(status: request.status)
        }
        .contentShape(Rectangle()).onTapGesture { if showActions { onTap?() } }
    }
}

// MARK: - Request Status Badge
struct RequestStatusBadge: View {
    let status: RequestStatus
    var color: Color { switch status { case .pending: return .warning; case .approved: return .success; case .rejected: return .danger } }
    var body: some View {
        Text(status.rawValue.capitalized).font(AppFont.caption2Med)
            .padding(.horizontal, Spacing.sm).padding(.vertical, 4)
            .background(color.opacity(0.15)).foregroundColor(color).cornerRadius(Radius.sm)
    }
}

// MARK: - Request Decision View (Pet Shop)
struct RequestDecisionView: View {
    let request: AdoptionRequest
    let onDecision: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var rejectionReason = ""
    @State private var isProcessing    = false
    @State private var errorMessage:   String?

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                HStack(spacing: Spacing.lg) {
                    AsyncImage(url: URL(string: request.petImageURL)) { phase in
                        switch phase { case .success(let img): img.resizable().scaledToFill(); default: Color(.systemGray5) }
                    }
                    .frame(width: 70, height: 70).clipped().cornerRadius(Radius.sm)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.petName).font(AppFont.title3)
                        Text("Adopter: \(request.adopterName)").font(AppFont.body).foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
                .padding().background(Color(.systemGray6)).cornerRadius(Radius.md)

                if !request.notes.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Message from adopter").font(AppFont.bodyMedium)
                        Text(request.notes).font(AppFont.body).foregroundColor(.textSecondary)
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6)).cornerRadius(Radius.md)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Rejection reason (optional)").font(AppFont.caption).foregroundColor(.textSecondary)
                    TextField("Reason...", text: $rejectionReason)
                        .padding().background(Color(.systemGray6)).cornerRadius(Radius.sm)
                }

                if let error = errorMessage { ErrorBanner(message: error) }
                Spacer()

                HStack(spacing: Spacing.md) {
                    Button { Task { await decide(approve: false) } } label: {
                        Text("Reject").font(AppFont.bodyMedium).frame(maxWidth: .infinity).padding()
                            .background(Color.danger.opacity(0.1)).foregroundColor(.danger).cornerRadius(Radius.md)
                    }
                    .disabled(isProcessing)

                    Button { Task { await decide(approve: true) } } label: {
                        HStack {
                            if isProcessing { ProgressView().tint(.white) }
                            else { Text("Approve").font(AppFont.bodyMedium) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.success).foregroundColor(.white).cornerRadius(Radius.md)
                    }
                    .disabled(isProcessing || request.status != .pending)
                }
            }
            .padding()
            .navigationTitle("Review Request").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func decide(approve: Bool) async {
        isProcessing = true; errorMessage = nil
        do {
            if approve { try await AdoptionService.shared.approveRequest(request) }
            else       { try await AdoptionService.shared.rejectRequest(request, reason: rejectionReason) }
            onDecision(); dismiss()
        } catch { errorMessage = error.localizedDescription }
        isProcessing = false
    }
}
