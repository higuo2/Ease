import SwiftUI
import SwiftData
import UIKit

@main
struct EaseApp: App {
    let container = EaseModelContainer.make()

    var body: some Scene {
        WindowGroup {
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea()
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
