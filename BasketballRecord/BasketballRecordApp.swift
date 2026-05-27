import SwiftUI
import UIKit

@main
struct BasketballRecordApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = store.keepsScreenAwake
                }
                .onChange(of: store.keepsScreenAwake) { _, isEnabled in
                    UIApplication.shared.isIdleTimerDisabled = isEnabled
                }
        }
    }
}
