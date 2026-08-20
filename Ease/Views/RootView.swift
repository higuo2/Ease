import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    private var hasCompletedOnboarding: Bool {
        profiles.contains(where: \.hasCompletedOnboarding)
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasCompletedOnboarding)
        .preferredColorScheme(.light)
        .task {
            try? LegacyWeightMigrator.run(context: modelContext)
            try? MetricRepository(context: modelContext).seedBuiltinsIfNeeded()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(EaseModelContainer.preview())
}
