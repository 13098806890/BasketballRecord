import SwiftUI

struct CreateRosterItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: RosterImportKind = .player
    @State private var showingPlayerEditor = false
    @State private var showingTeamEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("section_create_type")) {
                    Picker(LocalizedStringKey("section_create_type"), selection: $kind) {
                        ForEach([RosterImportKind.player, .team]) { kind in
                            Text(kind.localizedTitle).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button {
                        if kind == .player {
                            showingPlayerEditor = true
                        } else {
                            showingTeamEditor = true
                        }
                    } label: {
                        Label(kind == .player ? LocalizedStringKey("button_create_player") : LocalizedStringKey("button_create_team"), systemImage: kind == .player ? "person.crop.circle.badge.plus" : "person.3.fill")
                            .symbolRenderingMode(.monochrome)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppNeutralProminentButtonStyle())
                }
            }
            .navigationTitle(LocalizedStringKey("settings_new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_close")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingPlayerEditor) {
                PlayerEditorView(player: nil)
            }
            .sheet(isPresented: $showingTeamEditor) {
                TeamEditorView(team: nil)
            }
        }
    }
}
