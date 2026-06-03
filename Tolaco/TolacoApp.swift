import SwiftUI

@main
struct TolacoApp: App {
    var body: some Scene {
        WindowGroup("Tolaco") {
            ContentView()
                .frame(minWidth: 480, minHeight: 360)
        }
        .windowResizability(.contentSize)
    }
}
