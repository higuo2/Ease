import SwiftUI
import SwiftData

@main
struct EaseApp: App {
    let container = EaseModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
