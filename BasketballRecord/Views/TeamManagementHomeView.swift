import SwiftUI

struct TeamManagementHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingCreateEntry = false
    @State private var isShowingPurchase = false

    var body: some View {
        NavigationStack {
            List {
                Section(LocalizedStringKey("settings_section_data_management")) {
                    NavigationLink {
                        GameGroupManagementView(store: store)
                    } label: {
                        managementRow(
                            title: LocalizedStringKey("game_group_nav_title"),
                            systemImage: "folder.fill",
                            countText: "\(store.gameGroups.count)"
                        )
                    }
                    .disabled(!store.isPro)
                    .overlay {
                        if !store.isPro {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { isShowingPurchase = true }
                        }
                    }

                    NavigationLink {
                        PlayerGroupManagementView(store: store)
                    } label: {
                        managementRow(
                            title: LocalizedStringKey("player_group_nav_title"),
                            systemImage: "person.2.fill",
                            countText: "\(store.playerGroups.count)"
                        )
                    }
                    .disabled(!store.isPro)
                    .overlay {
                        if !store.isPro {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { isShowingPurchase = true }
                        }
                    }

                    NavigationLink {
                        TeamManagementView()
                    } label: {
                        managementRow(
                            title: LocalizedStringKey("settings_teams"),
                            systemImage: "person.3.fill",
                            countText: "\(store.teams.count)"
                        )
                    }

                    NavigationLink {
                        PlayerManagementView()
                    } label: {
                        managementRow(
                            title: LocalizedStringKey("settings_players"),
                            systemImage: "person.crop.circle.fill",
                            countText: "\(store.players.count)"
                        )
                    }

                    Button {
                        showingCreateEntry = true
                    } label: {
                        managementRow(
                            title: LocalizedStringKey("settings_new"),
                            systemImage: "plus.circle.fill",
                            countText: nil,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(LocalizedStringKey("tab_management"))
        }
        .sheet(isPresented: $showingCreateEntry) {
            CreateRosterItemView()
        }
        .sheet(isPresented: $isShowingPurchase) {
            ProSubscriptionStoreView()
        }
        .onChange(of: PurchaseManager.shared.isPro) { _, isPro in
            if isPro { isShowingPurchase = false }
        }
    }

    private func managementRow(
        title: LocalizedStringKey,
        systemImage: String,
        countText: String?,
        showsDisclosure: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body.weight(.medium))

            Spacer()

            if let countText {
                Text(countText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
