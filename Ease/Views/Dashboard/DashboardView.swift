import SwiftUI

/// Legacy entry retained for previews / tests; production root uses `MainTabView`.
struct DashboardView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    DashboardView()
        .modelContainer(EaseModelContainer.preview())
}
