import SwiftUI

struct CreateRosterItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: RosterImportKind = .player
    @State private var showingPlayerEditor = false
    @State private var showingTeamEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(LocalizedStringKey("section_create_type"), selection: $kind) {
                        ForEach([RosterImportKind.player, .team]) { kind in
                            Text(kind.localizedTitle).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(LocalizedStringKey("section_create_type"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EditorialDesign.navy)
                }
                .listRowBackground(EditorialDesign.card)

                Section {
                    Button {
                        if kind == .player {
                            showingPlayerEditor = true
                        } else {
                            showingTeamEditor = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: kind == .player ? "person.crop.circle.badge.plus" : "person.3.fill")
                                .foregroundStyle(EditorialDesign.orange)
                                .frame(width: 28, height: 28)
                            Text(kind == .player ? LocalizedStringKey("button_create_player") : LocalizedStringKey("button_create_team"))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(EditorialDesign.navy)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(EditorialDesign.card)
            }
            .editorialListStyle()
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
