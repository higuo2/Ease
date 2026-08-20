import SwiftUI
import SwiftData
import UIKit

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let profile: UserProfile
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var heightText: String
    @State private var startText: String
    @State private var targetText: String
    @State private var sleepTargetText: String
    @State private var notificationsEnabled: Bool
    @State private var showDeleteConfirm = false
    @State private var sharePayload: SharePayload?
    @State private var errorKey: String?

    init(profile: UserProfile, records: [DailyRecord], logs: [WeightLog] = []) {
        self.profile = profile
        self.records = records
        self.logs = logs
        _heightText = State(initialValue: EaseFormatters.oneDecimal(profile.heightCm))
        _startText = State(initialValue: EaseFormatters.oneDecimal(profile.startWeight))
        _targetText = State(initialValue: EaseFormatters.oneDecimal(profile.targetWeight))
        _sleepTargetText = State(initialValue: EaseFormatters.oneDecimal(profile.sleepTargetHours))
        _notificationsEnabled = State(initialValue: profile.notificationsEnabled)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard {
                            VStack(spacing: 20) {
                                EaseField(title: "settings.height", placeholder: "onboarding.height.placeholder", text: $heightText, suffix: "unit.cm")
                                EaseField(title: "settings.startWeight", placeholder: "onboarding.weight.placeholder", text: $startText, suffix: "unit.kg")
                                EaseField(title: "settings.targetWeight", placeholder: "onboarding.weight.placeholder", text: $targetText, suffix: "unit.kg")
                                EaseField(title: "settings.sleepTarget", placeholder: "settings.sleepTarget.placeholder", text: $sleepTargetText, suffix: "unit.hours")
                            }
                        }
                        EaseCard {
                            Toggle(isOn: $notificationsEnabled) {
                                Text("settings.notifications")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(EasePalette.primaryText)
                            }
                            .tint(EasePalette.accent)
                        }
                        if let errorKey {
                            Text(LocalizedStringKey(errorKey))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(EasePalette.secondaryText)
                        }
                        EasePrimaryButton(title: "settings.save", action: save)
                        EasePrimaryButton(title: "settings.export", action: exportCSV)
                        EaseTextButton(title: "settings.deleteAll") {
                            showDeleteConfirm = true
                        }
                        .padding(.bottom, 12)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .confirmationDialog("settings.deleteConfirm", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("settings.deleteAll", role: .destructive, action: deleteAll)
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.deleteConfirmMessage")
            }
            .sheet(item: $sharePayload) { payload in
                ActivityView(items: [payload.url])
            }
        }
        .preferredColorScheme(.light)
    }

    private func save() {
        guard let height = EaseFormatters.parseDecimal(heightText),
              let start = EaseFormatters.parseDecimal(startText),
              let target = EaseFormatters.parseDecimal(targetText),
              let sleepTarget = EaseFormatters.parseDecimal(sleepTargetText) else {
            errorKey = "onboarding.error.invalid"
            return
        }
        Task {
            var enabled = notificationsEnabled
            if enabled {
                enabled = await PermissionsService.requestNotifications()
            }
            do {
                try UserProfileRepository(context: modelContext).update(
                    heightCm: height,
                    startWeight: start,
                    targetWeight: target,
                    sleepTargetHours: sleepTarget,
                    notificationsEnabled: enabled
                )
                await NotificationScheduler.refresh(enabled: enabled, context: modelContext)
                await MainActor.run {
                    errorKey = nil
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorKey = "onboarding.error.invalid"
                }
            }
        }
    }

    private func exportCSV() {
        let csv = CSVExporter.export(records, logs: logs)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ease-export.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            sharePayload = SharePayload(url: url)
        } catch {
            errorKey = "settings.exportFailed"
        }
    }

    private func deleteAll() {
        Task {
            await NotificationScheduler.refresh(enabled: false, todayRecord: nil, healthToday: nil)
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            try? UserProfileRepository(context: modelContext).resetAll()
        }
        dismiss()
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
