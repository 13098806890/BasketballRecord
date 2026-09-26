import SwiftUI

@main
struct AdaptivePrototypeApp: App {
    @State private var tab = PrototypeTab.management

    init() {
        let argument = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("-prototypeScreen=") } ?? ""
        let screen = argument.replacingOccurrences(of: "-prototypeScreen=", with: "")
        if let selected = PrototypeTab(rawValue: screen) {
            _tab = State(initialValue: selected)
        }
    }

    var body: some Scene {
        WindowGroup {
            AdaptivePrototypeShell(tab: $tab)
        }
    }
}
