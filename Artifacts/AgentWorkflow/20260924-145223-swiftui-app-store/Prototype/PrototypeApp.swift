import SwiftUI

@main
struct PrototypeApp: App {
    @State private var selectedTab = PrototypeTab.history

    init() {
        let argument = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("-prototypeScreen=") } ?? ""
        let screen = argument.replacingOccurrences(of: "-prototypeScreen=", with: "")
        if let tab = PrototypeTab(rawValue: screen) {
            _selectedTab = State(initialValue: tab)
        }
    }

    var body: some Scene {
        WindowGroup {
            PrototypeShell(selectedTab: $selectedTab)
        }
    }
}
