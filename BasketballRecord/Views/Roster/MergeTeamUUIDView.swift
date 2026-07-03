import SwiftUI

struct MergeTeamUUIDView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var embedded = false
    @State private var sourceID: UUID?
    @State private var targetID: UUID?
    @State private var resultMessage: String?

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                NavigationStack {
                    content
                        .navigationTitle(LocalizedStringKey("nav_merge_teams_uuid"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(LocalizedStringKey("button_close")) { dismiss() }
                            }
                        }
                    }
                }
        }
    }

    private var content: some View {
        Form {
            Section(LocalizedStringKey("section_select_merge_target")) {
                Picker(LocalizedStringKey("picker_team_to_merge"), selection: $sourceID) {
                    Text(LocalizedStringKey("text_please_select")).tag(UUID?.none)
                    ForEach(store.teams) { team in
                        Text(label(for: team)).tag(Optional(team.id))
                    }
                }

                Picker(LocalizedStringKey("picker_team_keep_uuid"), selection: $targetID) {
                    Text(LocalizedStringKey("text_please_select")).tag(UUID?.none)
                    ForEach(targetCandidates) { team in
                        Text(label(for: team)).tag(Optional(team.id))
                    }
                }
            }

            Section {
                Text(LocalizedStringKey("merge_team_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    merge()
                } label: {
                    Label(LocalizedStringKey("button_execute_merge"), systemImage: "arrow.triangle.merge")
                }
                .disabled(!canMerge)
            }

            if let resultMessage {
                Section(LocalizedStringKey("section_result")) {
                    Text(resultMessage)
                        .font(.footnote)
                }
            }
        }
    }

    private var canMerge: Bool {
        guard let sourceID, let targetID else { return false }
        return sourceID != targetID
    }

    private var targetCandidates: [Team] {
        store.teams.filter { $0.id != sourceID }
    }

    private func label(for team: Team) -> String {
        let shortID = String(team.id.uuidString.prefix(8))
        return "\(team.name) (\(shortID))"
    }

    private func merge() {
        guard let sourceID, let targetID else { return }
        guard let summary = store.mergeTeam(sourceID: sourceID, into: targetID) else {
            resultMessage = localized("merge_team_failed")
            return
        }
        resultMessage = localizedFormat("merge_team_success_format", summary.mergedPlayers, summary.updatedGames)
        self.sourceID = nil
        self.targetID = nil
    }
}

