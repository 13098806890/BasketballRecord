import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GameView()
                .tabItem {
                    Label("记分", systemImage: "sportscourt")
                }

            RosterView()
                .tabItem {
                    Label("配置", systemImage: "person.3.sequence")
                }
        }
    }
}
