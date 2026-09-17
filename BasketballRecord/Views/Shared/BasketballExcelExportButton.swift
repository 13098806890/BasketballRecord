import SwiftUI
import UIKit

private enum BasketballExcelExportSheet: String, Identifiable {
    case purchase
    case gameSelection
    case share

    var id: String { rawValue }
}

private struct ExcelExportIcon: View {
    private let excelGreen = Color(red: 0.12, green: 0.48, blue: 0.30)
    private let sheetGreen = Color(red: 0.22, green: 0.62, blue: 0.40)

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(sheetGreen)
                .frame(width: 15, height: 19)
                .overlay {
                    VStack(spacing: 3) {
                        ForEach(0..<3) { _ in
                            Rectangle()
                                .fill(.white.opacity(0.85))
                                .frame(height: 0.7)
                        }
                    }
                    .padding(.leading, 7)
                    .padding(.trailing, 2)
                }
                .offset(x: 8)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(excelGreen)
                .frame(width: 15, height: 17)

            Text("X")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 15, height: 17)
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

struct BasketballExcelExportButton: View {
    @EnvironmentObject private var store: AppStore
    var label: LocalizedStringKey = LocalizedStringKey("button_export_excel")
    var systemImage = "tablecells"
    var isEnabled = true
    var isLoadingGames: Binding<Bool>? = nil
    var loadsAllGamesFromStore = false
    var gamesForSelection: (() -> [SavedGame])? = nil
    var selectedGamesExportFile: (([SavedGame]) -> BasketballExcelExportFile)? = nil
    let makeExportFile: () -> BasketballExcelExportFile
    @State private var activeSheet: BasketballExcelExportSheet?
    @State private var selectionGames: [SavedGame] = []
    @State private var selectedGameIDs: Set<UUID> = []
    @State private var pendingExportFile: BasketballExcelExportFile?
    @State private var shareFileURL: URL?
    @State private var isShowingExportError = false
    @State private var isExporting = false

    var body: some View {
        Button {
            guard !isExporting else { return }
            guard store.isPro else {
                activeSheet = .purchase
                return
            }

            if (loadsAllGamesFromStore || gamesForSelection != nil), selectedGamesExportFile != nil {
                selectionGames = availableSelectionGames()
                guard isLoadingGames?.wrappedValue == true || !selectionGames.isEmpty else { return }
                selectedGameIDs = Set(selectionGames.map(\.id))
                activeSheet = .gameSelection
                return
            }

            prepareExport(makeExportFile())
        } label: {
            if isExporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                ExcelExportIcon()
            }
        }
        .accessibilityLabel(isExporting ? LocalizedStringKey("export_preparing") : label)
        .disabled(isExporting || !isEnabled)
        .sheet(item: $activeSheet, onDismiss: handleSheetDismiss) { sheet in
            switch sheet {
            case .purchase:
                ProSubscriptionStoreView()
            case .gameSelection:
                NavigationStack {
                    PlayerGameSelectionView(
                        games: selectionGames,
                        selectedIDs: $selectedGameIDs,
                        onDone: exportSelectedGames,
                        doneTitle: LocalizedStringKey("button_export"),
                        isLoadingGames: isLoadingGames,
                        loadsAllGamesFromStore: loadsAllGamesFromStore,
                        refreshGames: gamesForSelection,
                        onGamesRefreshed: { games in
                            selectionGames = games
                            selectedGameIDs = Set(games.map(\.id))
                        }
                    )
                }
            case .share:
                if isExporting {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text(LocalizedStringKey("export_preparing"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                    .interactiveDismissDisabled()
                } else if let shareFileURL {
                    BasketballExcelShareSheet(fileURL: shareFileURL) {
                        activeSheet = nil
                    }
                }
            }
        }
        .alert(LocalizedStringKey("error_export_file_create_failed"), isPresented: $isShowingExportError) {
            Button(LocalizedStringKey("button_ok"), role: .cancel) { }
        }
        .onChange(of: isLoadingGames?.wrappedValue ?? false) { _, isLoading in
            guard !isLoading, case .gameSelection? = activeSheet else { return }
            selectionGames = availableSelectionGames()
            selectedGameIDs = Set(selectionGames.map(\.id))
        }
    }

    private func availableSelectionGames() -> [SavedGame] {
        if loadsAllGamesFromStore {
            return store.savedGames.sorted { $0.savedAt > $1.savedAt }
        }
        return gamesForSelection?() ?? []
    }

    private func exportSelectedGames() {
        guard let selectedGamesExportFile else { return }
        let selectedGames = BasketballExcelGameSelection.selectedGames(from: selectionGames, ids: selectedGameIDs)
        guard !selectedGames.isEmpty else { return }
        pendingExportFile = selectedGamesExportFile(selectedGames)
        activeSheet = nil
    }

    private func handleSheetDismiss() {
        if let pendingExportFile {
            self.pendingExportFile = nil
            prepareExport(pendingExportFile)
            return
        }
        cleanupShareFile()
    }

    private func prepareExport(_ file: BasketballExcelExportFile) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BasketballRecordExport-\(UUID().uuidString)", isDirectory: true)
        let fileName = (file.fileName as NSString).lastPathComponent
        let fileURL = directoryURL.appendingPathComponent(fileName)
        isExporting = true
        activeSheet = .share

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                    try file.data.write(to: fileURL, options: .atomic)
                }.value
                isExporting = false
                shareFileURL = fileURL
            } catch {
                try? await Task.detached(priority: .utility) {
                    try FileManager.default.removeItem(at: directoryURL)
                }.value
                isExporting = false
                activeSheet = nil
                isShowingExportError = true
            }
        }
    }

    private func cleanupShareFile() {
        guard let shareFileURL else { return }
        try? FileManager.default.removeItem(at: shareFileURL.deletingLastPathComponent())
        self.shareFileURL = nil
    }
}

private struct BasketballExcelShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                onComplete()
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
