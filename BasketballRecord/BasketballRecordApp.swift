import SwiftUI
import UIKit

@main
struct BasketballRecordApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var bluetoothSync = BluetoothSyncManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(bluetoothSync)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = store.keepsScreenAwake
                }
                .onChange(of: store.keepsScreenAwake) { _, isEnabled in
                    UIApplication.shared.isIdleTimerDisabled = isEnabled
                }
        }
    }
}
