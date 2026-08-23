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
    var showsDismissButton: Bool = true

    @State private var heightText: String
    @State private var startText: String
    @State private var targetText: String
    @State private var sleepTargetText: String
    @State private var notificationsEnabled: Bool
    @State private var weightReminderDate: Date
    @State private var dietReminderDate: Date
    @State private var showDeleteConfirm = false
    @State private var showDeleteConfirmAgain = false
    @State private var sharePayload: SharePayload?
    @State private var errorKey: String?
    @State private var importResult: String?
    @State private var isImporterPresented = false
    @State private var importPreview: CSVImporter.Preview?
    @State private var customName = ""
    @State private var customUnit: MetricUnit = .cm
    @State private var customSymbol = MetricCatalog.allowedSymbols[0]
    @State private var historyTarget: MetricHistoryTarget?
    @State private var isAddingMetric = false
    @State private var isWeightReminderExpanded = false
    @State private var isDietReminderExpanded = false
    @State private var isModulesExpanded = false
    @State private var isMetricsExpanded = false

    init(
        profile: UserProfile,
        records: [DailyRecord],
        logs: [WeightLog] = [],
        showsDismissButton: Bool = true,
        onOpenSleep: (() -> Void)? = nil,
        onOpenCycle: (() -> Void)? = nil
    ) {
        self.profile = profile
        self.records = records
        self.logs = logs
        self.showsDismissButton = showsDismissButton
        _ = onOpenSleep
        _ = onOpenCycle
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

    private var homeModulesBinding: Binding<[HomeModule]> {
        Binding(
            get: { profile.homeModules },
            set: { newValue in
                profile.homeModules = newValue
                profile.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private var customCount: Int {
        metricDefinitions.filter { $0.kind == .custom }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                personalSection
                remindersSection
                modulesSection
                metricsSection
                dataSection
                if let errorKey {
                    Section {
                        Text(LocalizedStringKey(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let importResult {
                    Section {
                        Text(importResult)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(EasePalette.background.ignoresSafeArea())
            .tint(EasePalette.coral)
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.close") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done", action: save)
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("settings.deleteConfirm", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("settings.deleteContinue", role: .destructive) {
                    showDeleteConfirmAgain = true
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.deleteConfirmMessage")
            }
            .alert("settings.deleteConfirmAgain", isPresented: $showDeleteConfirmAgain) {
                Button("settings.deleteAll", role: .destructive, action: deleteAll)
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.deleteConfirmAgainMessage")
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
                MetricSheet(date: .now, initialKey: target.definition.key)
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

    private var personalSection: some View {
        Section {
            settingsField("settings.height", text: $heightText, suffix: "unit.cm", placeholder: "onboarding.height.placeholder")
            settingsField("settings.startWeight", text: $startText, suffix: "unit.kg", placeholder: "onboarding.weight.placeholder")
            settingsField("settings.targetWeight", text: $targetText, suffix: "unit.kg", placeholder: "onboarding.weight.placeholder")
            settingsField("settings.sleepTarget", text: $sleepTargetText, suffix: "unit.hours", placeholder: "settings.sleepTarget.placeholder")
        } header: {
            Text("settings.section.personal")
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("settings.notifications", isOn: $notificationsEnabled)

            DisclosureGroup(isExpanded: $isWeightReminderExpanded) {
                DatePicker(
                    "",
                    selection: $weightReminderDate,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            } label: {
                HStack {
                    Text("settings.weightReminder")
                    Spacer()
                    Text(weightReminderDate, format: .dateTime.hour().minute())
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: isWeightReminderExpanded) { _, expanded in
                if expanded { isDietReminderExpanded = false }
            }

            DisclosureGroup(isExpanded: $isDietReminderExpanded) {
                DatePicker(
                    "",
                    selection: $dietReminderDate,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            } label: {
                HStack {
                    Text("settings.dietReminder")
                    Spacer()
                    Text(dietReminderDate, format: .dateTime.hour().minute())
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: isDietReminderExpanded) { _, expanded in
                if expanded { isWeightReminderExpanded = false }
            }
        } header: {
            Text("settings.section.reminders")
        }
    }

    private var modulesSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isModulesExpanded) {
                ForEach(HomeModule.allCases) { module in
                    Toggle(isOn: moduleBinding(module)) {
                        Label {
                            Text(LocalizedStringKey(module.titleKey))
                        } icon: {
                            Image(systemName: module.symbolName)
                        }
                    }
                }
            } label: {
                Text("settings.section.modules")
            }
        } footer: {
            if isModulesExpanded {
                Text("settings.section.modules.footer")
            }
        }
    }

    private var metricsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isMetricsExpanded) {
                ForEach(metricDefinitions.filter { MetricCatalog.isActiveMetricKey($0.key) }, id: \.key) { definition in
                    let spec = MetricCatalog.spec(for: definition)
                    Toggle(isOn: enabledBinding(definition)) {
                        Label {
                            Text(verbatim: spec.resolvedTitle)
                        } icon: {
                            Image(systemName: spec.symbolName)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("metric.history.title") {
                            historyTarget = MetricHistoryTarget(definition: definition)
                        }
                        .tint(EasePalette.primaryText)
                    }
                }

                if customCount < MetricCatalog.maxCustom {
                    DisclosureGroup(isExpanded: $isAddingMetric) {
                        TextField("settings.metrics.name", text: $customName)
                        Picker("settings.metrics.unit", selection: $customUnit) {
                            ForEach(MetricUnit.allCases, id: \.self) { unit in
                                Text(LocalizedStringKey(unit.titleKey)).tag(unit)
                            }
                        }
                        Picker("settings.metrics.symbol", selection: $customSymbol) {
                            ForEach(MetricCatalog.allowedSymbols, id: \.self) { symbol in
                                Image(systemName: symbol).tag(symbol)
                            }
                        }
                        Button("settings.metrics.add", action: addCustom)
                            .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } label: {
                        Label("settings.metrics.add", systemImage: "plus")
                    }
                } else {
                    Text("settings.metrics.maxCustom")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text("settings.section.metrics")
            }
        } footer: {
            if isMetricsExpanded {
                Text("settings.section.metrics.footer")
            }
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                exportCSV()
            } label: {
                Label("settings.export", systemImage: "square.and.arrow.up")
            }
            Button {
                isImporterPresented = true
            } label: {
                Label("settings.import", systemImage: "square.and.arrow.down")
            }
            Button("settings.deleteAll", role: .destructive) {
                showDeleteConfirm = true
            }
        } header: {
            Text("settings.section.data")
        } footer: {
            Text("settings.import.hint")
        }
    }

    private func settingsField(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        suffix: LocalizedStringKey,
        placeholder: LocalizedStringKey
    ) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 120)
            Text(suffix)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func moduleBinding(_ module: HomeModule) -> Binding<Bool> {
        Binding(
            get: { homeModulesBinding.wrappedValue.contains(module) },
            set: { isOn in
                var modules = homeModulesBinding.wrappedValue
                if isOn {
                    if !modules.contains(module) { modules.append(module) }
                } else {
                    modules.removeAll { $0 == module }
                    if modules.isEmpty { modules = HomeModule.defaults }
                }
                homeModulesBinding.wrappedValue = modules
            }
        )
    }

    private func enabledBinding(_ definition: MetricDefinition) -> Binding<Bool> {
        Binding(
            get: { definition.isEnabled },
            set: { newValue in
                try? MetricRepository(context: modelContext).setEnabled(definition, isEnabled: newValue)
            }
        )
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
                    notificationsEnabled = enabled
                    if showsDismissButton {
                        dismiss()
                    }
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
                let specs = MetricCatalog.specs(for: Array(metricDefinitions))
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
            isAddingMetric = false
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
        if showsDismissButton {
            dismiss()
        }
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
