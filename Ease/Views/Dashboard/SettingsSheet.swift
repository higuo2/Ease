import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsSheet: View {
    private enum Field: Hashable {
        case height, start, target, sleep
    }

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
    @State private var birthDate: Date?
    @State private var sex: BiologicalSex
    @State private var notificationsEnabled: Bool
    @State private var weightReminderDate: Date
    @State private var dietReminderDate: Date
    @State private var showDeleteConfirm = false
    @State private var showDeleteConfirmAgain = false
    @State private var showImportInfo = false
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
    @FocusState private var focusedField: Field?

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
        _birthDate = State(initialValue: profile.birthDate)
        _sex = State(initialValue: profile.sex)
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

    private var customCount: Int {
        metricDefinitions.filter { $0.kind == .custom }.count
    }

    private var activeMetrics: [MetricDefinition] {
        metricDefinitions.filter { MetricCatalog.isActiveMetricKey($0.key) }
    }

    var body: some View {
        NavigationStack {
            List {
                personalSection
                remindersSection
                modulesSection
                metricsSection
                dataSection
                deleteSection
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background { EasePalette.background.ignoresSafeArea() }
            .tint(EasePalette.coral)
            .easeTabListMargins()
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
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
            .onChange(of: focusedField) { oldValue, _ in
                if oldValue != nil {
                    persistMeasurements()
                }
            }
            .onChange(of: birthDate) { _, _ in
                persistBirthDate()
            }
            .onChange(of: sex) { _, _ in
                persistSex()
            }
            .onChange(of: notificationsEnabled) { _, enabled in
                Task { await persistNotifications(enabled) }
            }
            .onChange(of: isWeightReminderExpanded) { _, expanded in
                if expanded {
                    isDietReminderExpanded = false
                } else {
                    persistReminders()
                }
            }
            .onChange(of: isDietReminderExpanded) { _, expanded in
                if expanded {
                    isWeightReminderExpanded = false
                } else {
                    persistReminders()
                }
            }
            .onDisappear {
                persistMeasurements()
                persistReminders()
            }
        }
        .preferredColorScheme(.light)
    }

    private var personalSection: some View {
        Section {
            settingsField(
                "settings.height",
                text: $heightText,
                suffix: "unit.cm",
                placeholder: "onboarding.height.placeholder",
                field: .height
            )
            settingsField(
                "settings.startWeight",
                text: $startText,
                suffix: "unit.kg",
                placeholder: "onboarding.weight.placeholder",
                field: .start
            )
            settingsField(
                "settings.targetWeight",
                text: $targetText,
                suffix: "unit.kg",
                placeholder: "onboarding.weight.placeholder",
                field: .target
            )
            birthdayRow
            Picker("settings.sex", selection: $sex) {
                ForEach(BiologicalSex.allCases) { option in
                    Text(LocalizedStringKey(option.titleKey)).tag(option)
                }
            }
            settingsField(
                "settings.sleepTarget",
                text: $sleepTargetText,
                suffix: "unit.hours",
                placeholder: "settings.sleepTarget.placeholder",
                field: .sleep
            )
        } header: {
            Text("settings.section.personal")
        }
    }

    private var birthdayRow: some View {
        HStack {
            Text("settings.birthDate")
            Spacer(minLength: 12)
            if birthDate != nil {
                DatePicker(
                    "settings.birthDate",
                    selection: birthDateBinding,
                    in: birthDateRange,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                Button {
                    birthDate = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(EasePalette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("settings.birthDate.clear"))
            } else {
                Button("settings.birthDate.notSet") {
                    birthDate = Self.defaultBirthDate()
                }
                .foregroundStyle(EasePalette.secondaryText)
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
    }

    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { birthDate ?? Self.defaultBirthDate() },
            set: { birthDate = $0 }
        )
    }

    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let oldest = calendar.date(byAdding: .year, value: -MeasurementBounds.maxAgeYears, to: today) ?? today
        return oldest...today
    }

    private var remindersSection: some View {
        Section {
            Toggle("settings.notifications", isOn: $notificationsEnabled)
                .contentShape(Rectangle())

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
        } header: {
            Text("settings.section.reminders")
        }
    }

    private var modulesSection: some View {
        Section {
            ForEach(HomeModule.allCases) { module in
                Toggle(isOn: moduleBinding(module)) {
                    Label {
                        Text(LocalizedStringKey(module.titleKey))
                    } icon: {
                        Image(systemName: module.symbolName)
                    }
                }
                .contentShape(Rectangle())
            }
        } header: {
            Text("settings.section.modules")
        } footer: {
            Text("settings.section.modules.footer")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var metricsSection: some View {
        Section {
            ForEach(activeMetrics, id: \.persistentModelID) { definition in
                SettingsMetricToggleRow(definition: definition) {
                    historyTarget = MetricHistoryTarget(definition: definition)
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
        } header: {
            Text("settings.section.metrics")
        } footer: {
            Text("settings.section.metrics.footer")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var dataSection: some View {
        Section {
            Button(action: exportCSV) {
                Label("settings.export", systemImage: "square.and.arrow.up")
            }
            Button {
                isImporterPresented = true
            } label: {
                Label("settings.import", systemImage: "square.and.arrow.down")
            }
            .overlay(alignment: .trailing) {
                Button {
                    showImportInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(EasePalette.secondaryText)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("settings.import.info"))
                .popover(isPresented: $showImportInfo) {
                    Text("settings.import.hint")
                        .font(.system(size: 13))
                        .foregroundStyle(EasePalette.secondaryText)
                        .padding(16)
                        .frame(maxWidth: 280, alignment: .leading)
                        .presentationCompactAdaptation(.popover)
                }
            }
        } header: {
            Text("settings.section.data")
        } footer: {
            Text("settings.import.footer")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var deleteSection: some View {
        Section {
            Button("settings.deleteAll", role: .destructive) {
                showDeleteConfirm = true
            }
        }
    }

    private func settingsField(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        suffix: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        field: Field
    ) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 120)
                .focused($focusedField, equals: field)
                .onSubmit { persistMeasurements() }
            Text(suffix)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func moduleBinding(_ module: HomeModule) -> Binding<Bool> {
        Binding(
            get: { profile.homeModules.contains(module) },
            set: { isOn in
                var modules = profile.homeModules
                if isOn {
                    if !modules.contains(module) { modules.append(module) }
                } else {
                    modules.removeAll { $0 == module }
                    if modules.isEmpty { modules = HomeModule.defaults }
                }
                profile.homeModules = modules
                profile.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private var repository: UserProfileRepository {
        UserProfileRepository(context: modelContext)
    }

    private func persistMeasurements() {
        guard let height = EaseFormatters.parseDecimal(heightText),
              let start = EaseFormatters.parseDecimal(startText),
              let target = EaseFormatters.parseDecimal(targetText),
              let sleepTarget = EaseFormatters.parseDecimal(sleepTargetText) else {
            errorKey = "onboarding.error.invalid"
            return
        }
        do {
            try repository.update(
                heightCm: height,
                startWeight: start,
                targetWeight: target,
                sleepTargetHours: sleepTarget
            )
            errorKey = nil
        } catch {
            errorKey = "onboarding.error.invalid"
        }
    }

    private func persistBirthDate() {
        do {
            try repository.update(birthDate: .set(birthDate))
            errorKey = nil
        } catch {
            errorKey = "onboarding.error.invalid"
        }
    }

    private func persistSex() {
        do {
            try repository.update(sex: sex)
            errorKey = nil
        } catch {
            errorKey = "onboarding.error.invalid"
        }
    }

    private func persistReminders() {
        let weightParts = Calendar.current.dateComponents([.hour, .minute], from: weightReminderDate)
        let dietParts = Calendar.current.dateComponents([.hour, .minute], from: dietReminderDate)
        do {
            try repository.update(
                weightReminderHour: weightParts.hour,
                weightReminderMinute: weightParts.minute,
                dietReminderHour: dietParts.hour,
                dietReminderMinute: dietParts.minute
            )
            errorKey = nil
        } catch {
            errorKey = "onboarding.error.invalid"
            return
        }
        Task {
            await NotificationScheduler.refresh(enabled: notificationsEnabled, context: modelContext)
        }
    }

    private func persistNotifications(_ enabled: Bool) async {
        var next = enabled
        if next {
            next = await PermissionsService.requestNotifications()
        }
        do {
            try repository.update(notificationsEnabled: next)
            await NotificationScheduler.refresh(enabled: next, context: modelContext)
            await MainActor.run {
                notificationsEnabled = next
                errorKey = nil
            }
        } catch {
            await MainActor.run {
                errorKey = "onboarding.error.invalid"
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
    }

    private static func defaultBirthDate() -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .year, value: -25, to: calendar.startOfDay(for: .now))
            ?? Date()
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

private struct SettingsMetricToggleRow: View {
    @Environment(\.modelContext) private var modelContext
    let definition: MetricDefinition
    let onHistory: () -> Void
    @State private var isEnabled: Bool

    init(definition: MetricDefinition, onHistory: @escaping () -> Void) {
        self.definition = definition
        self.onHistory = onHistory
        _isEnabled = State(initialValue: definition.isEnabled)
    }

    private var spec: MetricSpec { MetricCatalog.spec(for: definition) }

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label {
                Text(verbatim: spec.resolvedTitle)
            } icon: {
                Image(systemName: spec.symbolName)
            }
        }
        .toggleStyle(.switch)
        .contentShape(Rectangle())
        .onChange(of: isEnabled) { _, newValue in
            guard definition.isEnabled != newValue else { return }
            try? MetricRepository(context: modelContext).setEnabled(definition, isEnabled: newValue)
        }
        .onChange(of: definition.isEnabled) { _, newValue in
            if isEnabled != newValue {
                isEnabled = newValue
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("metric.history.title") {
                onHistory()
            }
            .tint(EasePalette.primaryText)
        }
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
