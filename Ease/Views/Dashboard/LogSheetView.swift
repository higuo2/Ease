import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct LogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRecord.date, order: .forward) private var records: [DailyRecord]
    @Query(sort: \WeightLog.timestamp, order: .forward) private var weightLogs: [WeightLog]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    let mode: LogSheetMode
    @State private var selectedDate: Date
    @State private var editingLogID: UUID?
    @State private var weightText: String
    @State private var bodyFatText: String
    @State private var diet: DietStatus?
    @State private var tags: Set<VariableTag>
    @State private var noteText: String
    @State private var breakfastFileName: String?
    @State private var lunchFileName: String?
    @State private var dinnerFileName: String?
    @State private var extraMeals: [ExtraMealPhoto]
    @State private var errorKey: String?
    @State private var errorPulse = 0
    @State private var saveSuccessPulse = 0
    @State private var ocrSuccessPulse = 0
    @State private var ocrPhotoItem: PhotosPickerItem?
    @State private var isOCRPickerPresented = false
    @State private var isOCRBusy = false
    @State private var isCalendarExpanded = false
    @State private var pendingMeal: MealSlot?
    @State private var isMealSourceDialogPresented = false
    @State private var mealLibraryItem: PhotosPickerItem?
    @State private var isMealLibraryPresented = false
    @State private var isMealCameraPresented = false
    @State private var capturedMealImage: UIImage?
    @State private var isMealPhotoBusy = false
    @State private var mealPhotoTask: Task<Void, Never>?
    @State private var mealPreview: MealPhotoPreviewItem?
    @State private var isAddMealPresented = false
    @State private var customMealTitle = ""
    @State private var isAddTagPresented = false
    @State private var customTagTitle = ""

    init(date: Date, editingLogID: UUID? = nil, mode: LogSheetMode = .weight) {
        self.mode = mode
        let start = CalendarDay.startOfDay(date)
        _selectedDate = State(initialValue: start)
        _editingLogID = State(initialValue: editingLogID)
        _weightText = State(initialValue: "")
        _bodyFatText = State(initialValue: "")
        _diet = State(initialValue: nil)
        _tags = State(initialValue: [])
        _noteText = State(initialValue: "")
        _breakfastFileName = State(initialValue: nil)
        _lunchFileName = State(initialValue: nil)
        _dinnerFileName = State(initialValue: nil)
        _extraMeals = State(initialValue: [])
    }

    private var existing: DailyRecord? {
        let key = CalendarDay.dayKey(from: selectedDate)
        return records.first { $0.dayKey == key }
    }

    private var titleKey: LocalizedStringKey {
        switch mode {
        case .weight: "log.title.weight"
        case .diet: "log.title.diet"
        }
    }

    private var dietSelectionToken: String {
        diet?.rawValue ?? "none"
    }

    private var tagSelectionToken: Int {
        tags.map(\.rawValue).sorted().joined().hashValue
    }

    private var hasMealPhoto: Bool {
        breakfastFileName != nil
            || lunchFileName != nil
            || dinnerFileName != nil
            || extraMeals.contains { $0.fileName != nil }
    }

    private var visibleMealSlots: [MealSlot] {
        MealSlot.presets + extraMeals.filter(\.isCustom).map(MealSlot.fromExtra)
    }

    private var pendingMealHasPhoto: Bool {
        guard let pendingMeal else { return false }
        return mealFileName(for: pendingMeal) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard(radius: 16, padding: 18) {
                            logDateRow
                        }
                        switch mode {
                        case .weight:
                            weightCard
                        case .diet:
                            dietCard
                            mealsCard
                            tagsCard
                            noteCard
                        }
                        if let errorKey {
                            Text(LocalizedStringKey(errorKey))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EasePalette.primaryText)
                        }
                    }
                    .padding(20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    EasePrimaryButton(
                        title: "log.save",
                        isEnabled: canSave,
                        usesAccent: true,
                        action: save
                    )
                    if showsDelete {
                        EaseTextButton(title: "log.delete", action: deleteCurrent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(EasePalette.background.ignoresSafeArea(edges: .bottom))
            }
            .navigationTitle(titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel(Text("common.close"))
                }
            }
            .onAppear(perform: hydrateFromExisting)
            .onChange(of: selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    editingLogID = nil
                }
                hydrateFromExisting()
            }
            .onChange(of: ocrPhotoItem) { _, item in
                guard let item else { return }
                Task { await applyOCR(from: item) }
            }
            .onChange(of: mealLibraryItem) { _, item in
                guard let item, let pendingMeal else { return }
                let slot = pendingMeal
                mealPhotoTask?.cancel()
                mealPhotoTask = Task {
                    await applyMealLibraryPhoto(from: item, slot: slot)
                }
            }
            .onChange(of: capturedMealImage) { _, image in
                guard let image, let pendingMeal else { return }
                let slot = pendingMeal
                mealPhotoTask?.cancel()
                mealPhotoTask = Task {
                    await persistMealImage(image, for: slot)
                }
            }
            .confirmationDialog(
                "calendar.meal.source.title",
                isPresented: $isMealSourceDialogPresented,
                titleVisibility: .visible
            ) {
                if CameraImagePicker.isCameraAvailable {
                    Button("calendar.meal.takePhoto") {
                        isMealCameraPresented = true
                    }
                }
                Button("calendar.meal.chooseLibrary") {
                    isMealLibraryPresented = true
                }
                if pendingMealHasPhoto {
                    Button("calendar.meal.remove", role: .destructive) {
                        if let pendingMeal {
                            clearMealPhoto(for: pendingMeal)
                        }
                        pendingMeal = nil
                    }
                }
                if pendingMeal?.isCustom == true {
                    Button("meal.custom.remove", role: .destructive) {
                        if let pendingMeal {
                            removeCustomMeal(pendingMeal)
                        }
                        pendingMeal = nil
                    }
                }
                Button("common.cancel", role: .cancel) {
                    pendingMeal = nil
                }
            }
            .photosPicker(isPresented: $isOCRPickerPresented, selection: $ocrPhotoItem, matching: .images)
            .photosPicker(isPresented: $isMealLibraryPresented, selection: $mealLibraryItem, matching: .images)
            .fullScreenCover(isPresented: $isMealCameraPresented) {
                CameraImagePicker(image: $capturedMealImage)
                    .ignoresSafeArea()
            }
            .fullScreenCover(item: $mealPreview) { item in
                MealPhotoPreviewCover(fileName: item.fileName)
            }
            .alert("meal.custom.title", isPresented: $isAddMealPresented) {
                TextField("meal.custom.placeholder", text: $customMealTitle)
                Button("common.add") {
                    addCustomMeal()
                }
                Button("common.cancel", role: .cancel) {
                    customMealTitle = ""
                }
            }
            .alert("tag.custom.title", isPresented: $isAddTagPresented) {
                TextField("tag.custom.placeholder", text: $customTagTitle)
                Button("common.add") {
                    addCustomTag()
                }
                Button("common.cancel", role: .cancel) {
                    customTagTitle = ""
                }
            }
            .sensoryFeedback(.error, trigger: errorPulse)
            .sensoryFeedback(.success, trigger: saveSuccessPulse)
            .sensoryFeedback(.success, trigger: ocrSuccessPulse)
            .sensoryFeedback(.selection, trigger: dietSelectionToken)
            .sensoryFeedback(.selection, trigger: tagSelectionToken)
        }
        .preferredColorScheme(.light)
    }

    private var weightCard: some View {
        EaseCard(radius: 16, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("log.weight")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("onboarding.weight.placeholder", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                        .minimumScaleFactor(0.5)
                    Text("unit.kg")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 8)
                    ocrButton
                }

                Divider().overlay(EasePalette.hairline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("log.bodyFat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("log.bodyFat.placeholder", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(EasePalette.primaryText)
                        Text("unit.percent")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var dietCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("log.diet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DietStatusChipFlow(selection: diet) { diet = $0 }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mealsCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("calendar.meals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                MealPhotoCarousel(
                    slots: visibleMealSlots,
                    fileName: mealFileName(for:),
                    isBusy: { isMealPhotoBusy && pendingMeal == $0 },
                    onTap: { slot in
                        if let fileName = mealFileName(for: slot) {
                            mealPreview = MealPhotoPreviewItem(fileName: fileName)
                        } else {
                            pendingMeal = slot
                            isMealSourceDialogPresented = true
                        }
                    },
                    onReplace: { slot in
                        pendingMeal = slot
                        isMealSourceDialogPresented = true
                    },
                    onClear: clearMealPhoto(for:),
                    onRemoveCustom: removeCustomMeal,
                    onAdd: {
                        customMealTitle = ""
                        isAddMealPresented = true
                    }
                )
                .disabled(isMealPhotoBusy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tagsCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("log.tags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VariableTagChipFlow(
                    selection: tags,
                    onToggle: { tag in
                        if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
                    },
                    onAddCustom: {
                        customTagTitle = ""
                        isAddTagPresented = true
                    },
                    onRemoveCustom: { tag in
                        tags.remove(tag)
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noteCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("log.note")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("log.note.placeholder", text: $noteText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(EasePalette.primaryText)
                    .lineLimit(3...6)
            }
        }
    }

    private var logDateRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCalendarExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("log.date")
                        .font(.body)
                        .foregroundStyle(EasePalette.primaryText)
                    Spacer(minLength: 12)
                    Text(EaseFormatters.numericDate(selectedDate))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                    Image(systemName: isCalendarExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("log.date.hint"))

            if isCalendarExpanded {
                DatePicker(
                    "log.date",
                    selection: $selectedDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(EasePalette.accent)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var editingLog: WeightLog? {
        guard let editingLogID else { return nil }
        return weightLogs.first { $0.id == editingLogID }
    }

    private var showsDelete: Bool {
        switch mode {
        case .weight:
            return editingLog != nil
        case .diet:
            return existing != nil
        }
    }

    private var canSave: Bool {
        switch mode {
        case .weight:
            return EaseFormatters.parseDecimal(weightText) != nil
        case .diet:
            return diet != nil
                || !tags.isEmpty
                || !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || hasMealPhoto
                || !extraMeals.isEmpty
                || existing != nil
        }
    }

    private var ocrButton: some View {
        Button {
            isOCRPickerPresented = true
        } label: {
            ZStack {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(EasePalette.accent)
                    .opacity(isOCRBusy ? 0 : 1)
                if isOCRBusy {
                    ProgressView()
                        .tint(EasePalette.accent)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(isOCRBusy)
        .accessibilityLabel(Text("log.ocr"))
    }

    private func applyOCR(from item: PhotosPickerItem) async {
        isOCRBusy = true
        defer {
            isOCRBusy = false
            ocrPhotoItem = nil
        }
        guard let picked = try? await item.loadTransferable(type: PickedUIImage.self) else { return }
        let result = await ScaleOCR.recognize(image: picked.image)
        if let weight = result.weightKg {
            weightText = EaseFormatters.oneDecimal(weight)
        }
        if let bodyFat = result.bodyFatPercent {
            bodyFatText = EaseFormatters.oneDecimal(bodyFat)
        }
        if result.weightKg != nil || result.bodyFatPercent != nil {
            ocrSuccessPulse += 1
        }
    }

    private func applyMealLibraryPhoto(from item: PhotosPickerItem, slot: MealSlot) async {
        await MainActor.run { isMealPhotoBusy = true }
        defer {
            Task { @MainActor in
                isMealPhotoBusy = false
                mealLibraryItem = nil
                pendingMeal = nil
            }
        }
        guard let picked = try? await item.loadTransferable(type: PickedUIImage.self) else { return }
        do {
            let fileName = try await MealPhotoStore.saveJPEG(picked.image, compressionQuality: 0.8)
            guard !Task.isCancelled else {
                MealPhotoStore.deleteAsync(fileName: fileName)
                return
            }
            await MainActor.run {
                replaceMealFileName(fileName, for: slot)
            }
        } catch {
            // Keep previous draft filename.
        }
    }

    private func persistMealImage(_ image: UIImage, for slot: MealSlot) async {
        await MainActor.run {
            isMealPhotoBusy = true
            capturedMealImage = nil
        }
        defer {
            Task { @MainActor in
                isMealPhotoBusy = false
                pendingMeal = nil
            }
        }
        do {
            let fileName = try await MealPhotoStore.saveJPEG(image, compressionQuality: 0.8)
            guard !Task.isCancelled else {
                MealPhotoStore.deleteAsync(fileName: fileName)
                return
            }
            await MainActor.run {
                replaceMealFileName(fileName, for: slot)
            }
        } catch {
            // Keep previous draft filename.
        }
    }

    private func mealFileName(for slot: MealSlot) -> String? {
        switch slot {
        case .breakfast: breakfastFileName
        case .lunch: lunchFileName
        case .dinner: dinnerFileName
        default: extraMeals.first(where: { $0.id == slot.id })?.fileName
        }
    }

    private func replaceMealFileName(_ fileName: String?, for slot: MealSlot) {
        let previous = mealFileName(for: slot)
        switch slot {
        case .breakfast: breakfastFileName = fileName
        case .lunch: lunchFileName = fileName
        case .dinner: dinnerFileName = fileName
        default: extraMeals.upsert(slot: slot, fileName: fileName)
        }
        if previous != fileName {
            MealPhotoStore.deleteAsync(fileName: previous)
        }
    }

    private func clearMealPhoto(for slot: MealSlot) {
        replaceMealFileName(nil, for: slot)
    }

    private func addCustomMeal() {
        guard let slot = MealSlot.custom(title: customMealTitle) else { return }
        extraMeals.upsert(slot: slot, fileName: nil)
        customMealTitle = ""
    }

    private func removeCustomMeal(_ slot: MealSlot) {
        if let fileName = extraMeals.first(where: { $0.id == slot.id })?.fileName {
            MealPhotoStore.deleteAsync(fileName: fileName)
        }
        extraMeals.removeMeal(id: slot.id)
    }

    private func addCustomTag() {
        guard let tag = VariableTag.custom(from: customTagTitle) else { return }
        tags.insert(tag)
        customTagTitle = ""
    }

    private func hydrateFromExisting() {
        let record = existing
        let log = editingLog ?? loadEditingLog()
        if mode == .weight {
            if let log {
                weightText = EaseFormatters.oneDecimal(log.weight)
                bodyFatText = log.bodyFat.map(EaseFormatters.oneDecimal) ?? ""
            } else {
                weightText = ""
                bodyFatText = ""
            }
        }
        if mode == .diet {
            diet = record?.dietStatus
            tags = Set(record?.variableTags ?? [])
            noteText = record?.note ?? ""
            breakfastFileName = record?.breakfastPhotoFileName
            lunchFileName = record?.lunchPhotoFileName
            dinnerFileName = record?.dinnerPhotoFileName
            extraMeals = record?.extraMeals ?? []
        }
        errorKey = nil
    }

    private func loadEditingLog() -> WeightLog? {
        guard let editingLogID else { return nil }
        return try? WeightLogRepository(context: modelContext).log(id: editingLogID)
    }

    private func save() {
        do {
            switch mode {
            case .weight:
                let weight = EaseFormatters.parseDecimal(weightText)
                let bodyFat = EaseFormatters.parseDecimal(bodyFatText)
                guard weight != nil else {
                    presentError("log.error.empty")
                    return
                }
                try saveWeight(weight: weight, bodyFat: bodyFat)
            case .diet:
                let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                let noteValue = note.isEmpty ? nil : note
                guard diet != nil || !tags.isEmpty || noteValue != nil || hasMealPhoto || !extraMeals.isEmpty || existing != nil else {
                    presentError("log.error.empty")
                    return
                }
                try saveJournal(note: noteValue)
            }
            saveSuccessPulse += 1
            refreshReminders()
            dismiss()
        } catch let error as EaseDataError {
            switch error {
            case .emptyRecord, .emptyPatch:
                presentError("log.error.empty")
            case .invalidWeight, .invalidBodyFat, .invalidProfile, .invalidMetric, .tooManyCustomMetrics:
                presentError("onboarding.error.invalid")
            case .futureDate:
                presentError("log.error.future")
            }
        } catch {
            presentError("onboarding.error.invalid")
        }
    }

    private func saveWeight(weight: Double?, bodyFat: Double?) throws {
        let logs = WeightLogRepository(context: modelContext)
        if let editingLog {
            guard let weight else { return }
            try logs.update(editingLog, weight: weight, bodyFat: bodyFat)
            return
        }
        guard let weight else { return }
        try logs.insert(timestamp: timestampForNewLog, weight: weight, bodyFat: bodyFat)
    }

    private var timestampForNewLog: Date {
        if Calendar.current.isDate(selectedDate, inSameDayAs: .now) {
            return .now
        }
        return CalendarDay.atHour(8, on: selectedDate)
    }

    private func saveJournal(note: String?) throws {
        var patch = DailyRecordPatch()
        patch.dietStatus = .set(diet)
        patch.tags = .set(VariableTag.sanitized(Array(tags)))
        patch.note = .set(note)
        patch.breakfastPhoto = .set(breakfastFileName)
        patch.lunchPhoto = .set(lunchFileName)
        patch.dinnerPhoto = .set(dinnerFileName)
        patch.extraMeals = .set(extraMeals)
        try DailyRecordRepository(context: modelContext).upsert(on: selectedDate, patch: patch)
    }

    private func presentError(_ key: String) {
        errorKey = key
        errorPulse += 1
    }

    private func deleteCurrent() {
        do {
            switch mode {
            case .weight:
                if let editingLog {
                    try WeightLogRepository(context: modelContext).delete(editingLog)
                }
            case .diet:
                try DailyRecordRepository(context: modelContext).delete(on: selectedDate)
            }
            refreshReminders()
            dismiss()
        } catch {
            presentError("onboarding.error.invalid")
        }
    }

    private func refreshReminders() {
        let enabled = profiles.first?.notificationsEnabled == true
        Task {
            await NotificationScheduler.refresh(enabled: enabled, context: modelContext)
        }
    }
}
