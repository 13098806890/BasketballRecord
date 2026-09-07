import SwiftUI
import UniformTypeIdentifiers

struct BasketballExcelFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.spreadsheet] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BasketballExcelExportButton: View {
    @EnvironmentObject private var store: AppStore
    let makeReport: () -> BasketballExcelReport
    var label: LocalizedStringKey = LocalizedStringKey("button_export_excel")
    var systemImage = "tablecells"
    @State private var document: BasketballExcelFileDocument?
    @State private var isExporting = false
    @State private var isShowingPurchase = false
    @State private var fileName = "BasketballRecord_Export"

    var body: some View {
        Button {
            guard store.isPro else {
                isShowingPurchase = true
                return
            }
            let report = makeReport()
            document = BasketballExcelFileDocument(data: report.data)
            fileName = report.fileName
            isExporting = true
        } label: {
            Label(label, systemImage: systemImage)
        }
        .accessibilityLabel(label)
        .sheet(isPresented: $isShowingPurchase) {
            ProSubscriptionStoreView()
        }
        .fileExporter(
            isPresented: $isExporting,
            document: document,
            contentType: .spreadsheet,
            defaultFilename: fileName
        ) { _ in
            document = nil
        }
    }
}
