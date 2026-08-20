import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MetricDefinition.sortOrder, order: .forward) private var metricDefinitions: [MetricDefinition]
    @Query(sort: \MetricLog.timestamp, order: .forward) private var metricLogs: [MetricLog]
    let profile: UserProfile
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var heightText: String
    @State private var startText: String
    @State private var targetText: String
    @State private var sleepTargetText: String
    @State private var notificationsEnabled: Bool
    @State private var weightReminderDate: Date
    @State private var dietReminderDate: Date
    @State private var showDeleteConfirm = false
    @State private var sharePayload: SharePayload?
    @State private var errorKey: String?
    @State private var importResult: String?
    @State private var isImporterPresented = false
    @State private var importPreview: CSVImporter.Preview?
    @State private var customName = ""
    @State private var customUnit: MetricUnit = .cm
    @State private var customSymbol = MetricCatalog.allowedSymbols[0]
    @State private var historyTarget: MetricHistoryTarget?

    init(
        profile: UserProfile,
        records: [DailyRecord],
        logs: [WeightLog] = []
    ) {
        self.profile = profile
        self.records = records
        self.logs = logs
        _heightText = State(initialValue: EaseFormatters.oneDecimal(profile.heightCm))
        _startText = State(initialValue: EaseFormatters.oneDecimal(profile.startWeight))
        _targetText = State(initialValue: EaseFormatters.oneDecimal(profile.targetWeight))
        _sleepTargetText = State(initialValue: EaseFormatters.oneDecimal(profile.sleepTargetHours))
        _notificationsEnabled = State(initialValue: profile.notificationsEnabled)
        _weightReminderDate = State(initialValue: Self.clockDate(
            hour: profile.weightReminderHour,
            minute: profile.weightReminderMinute
        ))
        _dietReminderDate = State(initialValue: Self.clockDate(
            hour: profile.dietReminderHour,
            minute: profile.dietReminderMinute
        ))
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
                            VStack(alignment: .leading, spacing: 16) {
                                Toggle(isOn: $notificationsEnabled) {
                                    Text("settings.notifications")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(EasePalette.primaryText)
                                }
                                .tint(EasePalette.accent)
                                reminderRow("settings.weightReminder", date: $weightReminderDate)
                                reminderRow("settings.dietReminder", date: $dietReminderDate)
                            }
                        }
                        metricsCard
                        if let errorKey {
                            Text(LocalizedStringKey(errorKey))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(EasePalette.secondaryText)
                        }
                        if let importResult {
                            Text(importResult)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(EasePalette.secondaryText)
                        }
                        EasePrimaryButton(title: "settings.save", action: save)
                        EasePrimaryButton(title: "settings.export", action: exportCSV)
                        EasePrimaryButton(title: "settings.import", action: { isImporterPresented = true })
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
                ActivityView(items: payload.items)
            }
            .sheet(item: $importPreview) { preview in
                ImportPreviewSheet(preview: preview) {
                    confirmImport(preview)
                }
            }
            .sheet(item: $historyTarget) { target in
                MetricHistorySheet(
                    definitions: [target.definition],
                    logs: metricLogs.filter { $0.metricKey == target.definition.key }
                )
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
        .preferredColorScheme(.light)
    }

    private var metricsCard: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("settings.metrics")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                ForEach(metricDefinitions, id: \.key) { definition in
                    metricRow(definition)
                }
                if customCount < MetricCatalog.maxCustom {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("settings.metrics.add")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                        TextField("settings.metrics.name", text: $customName)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(EasePalette.primaryText)
                        Picker("settings.metrics.unit", selection: $customUnit) {
                            ForEach(MetricUnit.allCases, id: \.self) { unit in
                                Text(LocalizedStringKey(unit.titleKey)).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        Picker("settings.metrics.symbol", selection: $customSymbol) {
                            ForEach(MetricCatalog.allowedSymbols, id: \.self) { symbol in
                                Image(systemName: symbol).tag(symbol)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(EasePalette.primaryText)
                        EasePrimaryButton(title: "settings.metrics.add", isEnabled: !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, action: addCustom)
                    }
                } else {
                    Text("settings.metrics.maxCustom")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var customCount: Int {
        metricDefinitions.filter { $0.kind == .custom }.count
    }

    private func metricRow(_ definition: MetricDefinition) -> some View {
        let spec = MetricCatalog.spec(for: definition)
        return HStack(spacing: 12) {
            Image(systemName: spec.symbolName)
                .foregroundStyle(EasePalette.secondaryText)
                .frame(width: 22)
            Text(verbatim: spec.resolvedTitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(EasePalette.primaryText)
            Spacer(minLength: 8)
            Button("metric.history.title") {
                historyTarget = MetricHistoryTarget(definition: definition)
            }
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(EasePalette.secondaryText)
            .buttonStyle(.plain)
            Toggle("", isOn: Binding(
                get: { definition.isEnabled },
                set: { newValue in
                    try? MetricRepository(context: modelContext).setEnabled(definition, isEnabled: newValue)
                }
            ))
            .labelsHidden()
            .tint(EasePalette.accent)
        }
    }

    private func reminderRow(_ title: LocalizedStringKey, date: Binding<Date>) -> some View {
        DatePicker(title, selection: date, displayedComponents: .hourAndMinute)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(EasePalette.primaryText)
            .tint(EasePalette.accent)
    }

    private func save() {
        guard let height = EaseFormatters.parseDecimal(heightText),
              let start = EaseFormatters.parseDecimal(startText),
              let target = EaseFormatters.parseDecimal(targetText),
              let sleepTarget = EaseFormatters.parseDecimal(sleepTargetText) else {
            errorKey = "onboarding.error.invalid"
            return
        }
        let weightParts = Calendar.current.dateComponents([.hour, .minute], from: weightReminderDate)
        let dietParts = Calendar.current.dateComponents([.hour, .minute], from: dietReminderDate)
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
                    notificationsEnabled: enabled,
                    weightReminderHour: weightParts.hour,
                    weightReminderMinute: weightParts.minute,
                    dietReminderHour: dietParts.hour,
                    dietReminderMinute: dietParts.minute
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
        let journalURL = FileManager.default.temporaryDirectory.appendingPathComponent("ease-export.csv")
        do {
            try csv.write(to: journalURL, atomically: true, encoding: .utf8)
            var items: [Any] = [journalURL]
            if !metricLogs.isEmpty {
                let metricsCSV = CSVExporter.exportMetrics(metricLogs, definitions: metricDefinitions)
                let metricsURL = FileManager.default.temporaryDirectory.appendingPathComponent("ease-metrics.csv")
                try metricsCSV.write(to: metricsURL, atomically: true, encoding: .utf8)
                items.append(metricsURL)
            }
            sharePayload = SharePayload(items: items)
        } catch {
            errorKey = "settings.exportFailed"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            errorKey = "settings.import.failed"
        case .success(let urls):
            guard let url = urls.first else {
                errorKey = "settings.import.failed"
                return
            }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let specs = Dictionary(
                    uniqueKeysWithValues: metricDefinitions.map { ($0.key, MetricCatalog.spec(for: $0)) }
                )
                let preview = try CSVImporter.preview(
                    from: data,
                    existingLogs: logs,
                    existingRecords: records,
                    existingMetricLogs: metricLogs,
                    metricSpecs: specs
                )
                errorKey = nil
                importPreview = preview
            } catch {
                errorKey = "settings.import.failed"
            }
        }
    }

    private func confirmImport(_ preview: CSVImporter.Preview) {
        do {
            let result = try CSVImporter.apply(preview, context: modelContext)
            importResult = resultLine(result)
            errorKey = nil
        } catch {
            errorKey = "settings.import.failed"
        }
    }

    private func resultLine(_ result: CSVImporter.ApplyResult) -> String {
        if result.metricLogsWritten > 0 && result.weighInsWritten == 0 && result.dietDaysWritten == 0 {
            return String(format: String(localized: "settings.import.resultMetrics"), locale: .current, result.metricLogsWritten)
        }
        return String(
            format: String(localized: "settings.import.result"),
            locale: .current,
            result.weighInsWritten,
            result.dietDaysWritten
        )
    }

    private func addCustom() {
        do {
            _ = try MetricRepository(context: modelContext).addCustom(
                name: customName,
                unit: customUnit,
                symbolName: customSymbol
            )
            customName = ""
            errorKey = nil
        } catch EaseDataError.tooManyCustomMetrics {
            errorKey = "settings.metrics.maxCustom"
        } catch {
            errorKey = "onboarding.error.invalid"
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

    private static func clockDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: MeasurementBounds.clampedHour(hour),
            minute: MeasurementBounds.clampedMinute(minute),
            second: 0,
            of: Date()
        ) ?? Date()
    }
}

extension CSVImporter.Preview: Identifiable {
    var id: String {
        "\(kind)-\(weighInCount)-\(metricLogCount)-\(duplicateCount)-\(invalidCount)-\(isTruncated)"
    }
}

struct MetricHistoryTarget: Identifiable {
    var id: String { definition.key }
    let definition: MetricDefinition
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
