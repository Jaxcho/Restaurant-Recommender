//
//  PartyView.swift
//  Restaurant Recommender
//
//  Party mode: a host starts a party, friends join with its code, and the host
//  picks restaurants the whole group should like.
//

import SwiftUI
import CoreLocation

private let partyCodeLength = 6

/// Start a party at your location, or join a friend's with their code.
struct PartyHomeView: View {
    @Environment(PartyManager.self) private var partyManager
    @State private var locationManager = LocationModel()
    @State private var radius: Double = 3
    @State private var code: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false
    // Only Start shows a spinner (finding your location can take a moment)
    @State private var isStarting: Bool = false
    @State private var showLobby: Bool = false
    @State private var hasLoaded: Bool = false

    private var cleanedCode: String {
        code.trimmingCharacters(in: .whitespaces).uppercased()
    }

    /// Brings back a party the user is still in, e.g. after logging out and back in.
    private func loadParty() async {
        errorMessage = nil
        do {
            try await partyManager.restore()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't check for your party."
        }
        hasLoaded = true
    }

    private func startParty() {
        errorMessage = nil
        isSubmitting = true
        isStarting = true
        Task {
            defer {
                isSubmitting = false
                isStarting = false
            }
            guard let coordinate = await locationManager.currentLocation() else {
                errorMessage = "Couldn't get your location — allow location access."
                return
            }
            do {
                try await partyManager.create(lat: coordinate.latitude, lng: coordinate.longitude, radius: radius)
                showLobby = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't start a party."
            }
        }
    }

    private func joinParty() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                try await partyManager.join(code: cleanedCode)
                code = ""
                showLobby = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't join that party."
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                if let party = partyManager.party {
                    currentPartyCard(party)
                } else if hasLoaded {
                    startCard
                    joinCard
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if !hasLoaded {
                ProgressView()
            }
        }
        .navigationTitle("Party")
        .navigationDestination(isPresented: $showLobby) {
            PartyLobbyView()
        }
        // Runs each time this screen shows, so leaving or a new login is picked up
        .task {
            await loadParty()
        }
    }

    private func statusTag(_ status: String) -> TagLabel {
        switch status {
        case "picked": TagLabel(text: "Picks are in", systemImage: "checkmark.circle.fill")
        case "ended": TagLabel(text: "Ended", systemImage: "flag.checkered", tint: .gray)
        default: TagLabel(text: "Waiting to pick", systemImage: "hourglass")
        }
    }

    private func currentPartyCard(_ party: PartyDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("You're in a party", systemImage: "person.3.fill")
                .font(.headline)
            HStack(spacing: 8) {
                Text(party.code)
                    .font(.title2.monospaced().bold())
                Spacer()
                statusTag(party.status)
            }
            Text(party.isHost ? "You're the host · \(party.members.count) in the party" : "Hosted by \(party.host) · \(party.members.count) in the party")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showLobby = true
            } label: {
                Text("Open Lobby")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Leave this party in the lobby to start or join another.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Start a party", systemImage: "party.popper")
                .font(.headline)
            Text("Friends join with a code, then we pick places the whole group will like.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Within \(radius.formatted()) mi")
                    .font(.subheadline.weight(.semibold))
                Slider(value: $radius, in: 1...10, step: 1) {
                    Text("Search radius")
                } minimumValueLabel: {
                    Text("1")
                } maximumValueLabel: {
                    Text("10")
                }
            }

            Button {
                startParty()
            } label: {
                Group {
                    if isStarting {
                        ProgressView()
                    } else {
                        Text("Start Party")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .cardStyle()
        .disabled(isSubmitting)
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Join a party", systemImage: "person.badge.plus")
                .font(.headline)

            TextField("Code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.title2.monospaced())
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .submitLabel(.join)
                .onSubmit {
                    if cleanedCode.count == partyCodeLength {
                        joinParty()
                    }
                }

            Button {
                joinParty()
            } label: {
                Text("Join")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(cleanedCode.count != partyCodeLength)
        }
        .cardStyle()
        .disabled(isSubmitting)
    }
}

/// Everyone waits here: the code to share, who's in, and the picks once the host chooses.
struct PartyLobbyView: View {
    @Environment(PartyManager.self) private var partyManager
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false
    @State private var isLeaving: Bool = false
    @State private var showEndConfirm: Bool = false
    @State private var didCopy: Bool = false

    private func leave() {
        errorMessage = nil
        isLeaving = true
        Task {
            defer {
                isLeaving = false
            }
            do {
                try await partyManager.leave()
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't leave the party."
            }
        }
    }

    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        didCopy = true
    }

    private func pick() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                try await partyManager.pick()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't pick a restaurant."
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let party = partyManager.party {
                    codeCard(party.code, canInvite: party.status != "ended")
                    membersCard(party)

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if party.status == "ended" {
                        Label("This party has ended", systemImage: "flag.checkered")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    if !party.picks.isEmpty {
                        PartyResultsView(picks: party.picks)
                    } else if party.status == "waiting" {
                        if party.isHost {
                            pickButton
                        } else {
                            Label("Waiting for the host to pick…", systemImage: "hourglass")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Party")
        .navigationBarTitleDisplayMode(.inline)
        // Back keeps you in the party (it's saved on the server); Leave takes you out
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Leave", role: .destructive) {
                    if partyManager.party?.isHost == true {
                        showEndConfirm = true
                    } else {
                        leave()
                    }
                }
                .disabled(isSubmitting || isLeaving)
            }
        }
        .confirmationDialog("End the party for everyone?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Party", role: .destructive) {
                leave()
            }
        }
        // Poll for new members, the host's picks, and the host ending the party.
        // Slower once picked; stops when ended or when the view goes away.
        .task {
            while !Task.isCancelled, let status = partyManager.party?.status, status != "ended" {
                try? await partyManager.refresh()
                try? await Task.sleep(for: .seconds(status == "waiting" ? 3 : 10))
            }
        }
        // Turns "Copied" back into "Copy" after 2 seconds
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
        }
        .sensoryFeedback(.success, trigger: didCopy) { _, copied in
            copied
        }
    }

    private func codeCard(_ code: String, canInvite: Bool) -> some View {
        VStack(spacing: 12) {
            Text("Party code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(code)
                .font(.largeTitle.monospaced())
                .fontWeight(.bold)
                .tracking(4)
                .textSelection(.enabled)
            if canInvite {
                // Side by side, or stacked when the text is too big to fit
                ViewThatFits {
                    HStack(spacing: 10) {
                        inviteButtons(code)
                    }
                    VStack(spacing: 10) {
                        inviteButtons(code)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    @ViewBuilder
    private func inviteButtons(_ code: String) -> some View {
        Button {
            copyCode(code)
        } label: {
            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
        }
        ShareLink(item: "Join my food party on Restaurant Radar! Code: \(code)") {
            Label("Invite friends", systemImage: "square.and.arrow.up")
        }
    }

    private func membersCard(_ party: PartyDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(party.members.count) in the party", systemImage: "person.3")
                .font(.headline)
            ForEach(party.members, id: \.self) { member in
                HStack(spacing: 10) {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundStyle(Brand.accent)
                        .accessibilityHidden(true)
                    Text(member)
                    Spacer()
                    if member == party.host {
                        TagLabel(text: "Host", systemImage: "crown.fill")
                    }
                }
            }
        }
        .cardStyle()
    }

    private var pickButton: some View {
        Button {
            pick()
        } label: {
            Group {
                if isSubmitting {
                    ProgressView()
                } else {
                    Label("Pick Restaurant", systemImage: "sparkles")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isSubmitting || isLeaving)
    }
}

/// The group's picks, best first. Tap one for its details.
struct PartyResultsView: View {
    let picks: [PartyPickDTO]
    @Environment(FunctionManager.self) private var functionManager
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false

    // Details for the sheet
    @State private var showModal: Bool = false
    @State private var selectedPlaceId: String = ""
    @State private var restaurantName: String = ""
    @State private var restaurantReview: String = ""
    @State private var location: Array<Double> = []
    @State private var hours: Array<OpeningHoursStruct> = []
    @State private var distance: Double = 0
    @State private var userReviews: Array<RestaurantReviewsDTO> = []
    @State private var photoUrl: String?

    private func restaurantData(placeId: String, name: String) {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                let restaurant = try await functionManager.restaurantInfo(restaurant_id: placeId)
                userReviews = try await functionManager.getReviews(restaurant_id: placeId)
                distance = restaurant.distance
                restaurantReview = restaurant.reviewSummary
                photoUrl = restaurant.photoUrl
                restaurantName = name
                hours = restaurant.currentOpeningHours
                location = restaurant.location
                showModal = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't open that restaurant."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("The group's picks", systemImage: "sparkles")
                .font(.headline)

            if let errorMessage {
                ErrorBanner(message: errorMessage)
            }

            ForEach(picks) { pick in
                pickRow(pick, isWinner: pick.id == picks.first?.id)
            }
        }
        .cardStyle()
        .sheet(isPresented: $showModal) {
            ModalContentView(location: location, hours: hours, restaurantName: restaurantName, placeId: selectedPlaceId, distance: distance, showVisited: false, userReviews: userReviews, restaurantReview: restaurantReview, photoUrl: photoUrl)
        }
    }

    private func pickRow(_ pick: PartyPickDTO, isWinner: Bool) -> some View {
        Button {
            selectedPlaceId = pick.placeId
            restaurantData(placeId: pick.placeId, name: pick.name)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isWinner ? "trophy.fill" : "fork.knife")
                    .font(.title3)
                    .foregroundStyle(isWinner ? Brand.accent : Color.secondary)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pick.name)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    StarRatingView(rating: pick.score.rounded())
                    Text("Group \(pick.score.formatted(.number.precision(.fractionLength(1)))) · Lowest \(pick.lowest.formatted(.number.precision(.fractionLength(1))))")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                Spacer(minLength: 8)
                if isSubmitting && selectedPlaceId == pick.placeId {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .accessibilityHidden(true)
                }
            }
            .padding(10)
            .background(isWinner ? Brand.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }
}

#Preview("Party") {
    let apiClient = APIClient(baseURL: AppEnvironment.apiBaseURL)
    NavigationStack {
        PartyHomeView()
    }
    .environment(PartyManager(apiClient: apiClient))
    .environment(FunctionManager(apiClient: apiClient))
}
