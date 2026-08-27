import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct CalendarDayDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRecord.date, order: .forward) private var allRecords: [DailyRecord]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    let date: Date
    let logs: [WeightLog]
    let onLogWeight: () -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var pendingMeal: MealSlot?
    @State private var isSourceDialogPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var capturedImage: UIImage?
    @State private var isPhotoBusy = false
    @State private var dietSelectionToken = ""
    @State private var dietNote = ""
    @State private var noteSaveTask: Task<Void, Never>?
    @State private var photoPersistTask: Task<Void, Never>?
    @State private var mealPreview: MealPhotoPreviewItem?
    @State private var isAddMealPresented = false
    @State private var customMealTitle = ""
    @State private var isAddTagPresented = false
    @State private var customTagTitle = ""
    @FocusState private var isNoteFocused: Bool

    private var record: DailyRecord? {
        let key = CalendarDay.dayKey(from: date)
        return allRecords.first { $0.dayKey == key }
    }

    private var diet: DietStatus? { record?.dietStatus }

    private var tags: Set<VariableTag> {
        Set(record?.variableTags ?? [])
    }

    private var tagSelectionToken: Int {
        tags.map(\.rawValue).sorted().joined().hashValue
    }

    private var pendingMealHasPhoto: Bool {
        guard let pendingMeal else { return false }
        return record?.mealPhotoFileName(for: pendingMeal) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        weightCard
                        mealsCard
                        dietChipsCard
                        tagsCard
                        noteCard
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.headline)
                        .foregroundStyle(EasePalette.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onLogWeight()
                    } label: {
                        Text("calendar.log")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(EasePalette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .onAppear(perform: hydrateNote)
            .onChange(of: date) { _, _ in
                hydrateNote()
            }
            .onChange(of: record?.note) { _, newNote in
                guard !isNoteFocused else { return }
                dietNote = newNote ?? ""
            }
            .onChange(of: dietNote) { _, _ in
                scheduleNoteSave()
            }
            .onChange(of: isNoteFocused) { _, focused in
                if !focused { scheduleNoteSave(immediate: true) }
            }
            .onDisappear {
                // Don't block scene teardown — flush note off the critical path.
                scheduleNoteSave(immediate: true)
            }
            .onChange(of: photoItem) { _, item in
                guard let item, let pendingMeal else { return }
                let slot = pendingMeal
                photoPersistTask?.cancel()
                photoPersistTask = Task {
                    await applyLibraryPhoto(from: item, slot: slot)
                }
            }
            .onChange(of: capturedImage) { _, image in
                guard let image, let pendingMeal else { return }
                let slot = pendingMeal
                photoPersistTask?.cancel()
                photoPersistTask = Task {
                    await persistCapturedImage(image, for: slot)
                }
            }
            .confirmationDialog(
                "calendar.meal.source.title",
                isPresented: $isSourceDialogPresented,
                titleVisibility: .visible
            ) {
                if CameraImagePicker.isCameraAvailable {
                    Button("calendar.meal.takePhoto") {
                        isCameraPresented = true
                    }
                }
                Button("calendar.meal.chooseLibrary") {
                    isPhotoPickerPresented = true
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
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $photoItem,
                matching: .images
            )
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraImagePicker(image: $capturedImage)
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
            .sensoryFeedback(.selection, trigger: dietSelectionToken)
            .sensoryFeedback(.selection, trigger: tagSelectionToken)
        }
        .preferredColorScheme(.light)
    }

    private var weightCard: some View {
        let bounds = WeightMetrics.dayBounds(records: allRecords, logs: logs, on: date)
        let swing = WeightMetrics.daytimeSwing(records: allRecords, logs: logs, on: date)

        return EaseCard(radius: 16, padding: 18) {
            HStack(alignment: .top, spacing: 0) {
                detailMetric("calendar.detail.am", bounds.morning.map(EaseFormatters.oneDecimal))
                detailMetric("calendar.detail.pm", bounds.evening.map(EaseFormatters.oneDecimal))
                detailMetric(
                    "calendar.detail.day",
                    swing.map(signedOne),
                    showUnit: false,
                    valueColor: swing.map(EasePalette.semanticDelta)
                )
            }
        }
    }

    private var mealsCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("calendar.meals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                MealPhotoCarousel(
                    slots: record?.visibleMealSlots ?? MealSlot.presets,
                    fileName: { record?.mealPhotoFileName(for: $0) },
                    isBusy: { isPhotoBusy && pendingMeal == $0 },
                    onTap: { slot in
                        if let fileName = record?.mealPhotoFileName(for: slot) {
                            mealPreview = MealPhotoPreviewItem(fileName: fileName)
                        } else {
                            pendingMeal = slot
                            isSourceDialogPresented = true
                        }
                    },
                    onReplace: { slot in
                        pendingMeal = slot
                        isSourceDialogPresented = true
                    },
                    onClear: clearMealPhoto(for:),
                    onRemoveCustom: removeCustomMeal,
                    onAdd: {
                        customMealTitle = ""
                        isAddMealPresented = true
                    }
                )
                .disabled(isPhotoBusy)
            }
        }
    }

    private var dietChipsCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("log.diet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DietStatusChipFlow(selection: diet, onSelect: saveDiet)
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
                    onToggle: toggleTag,
                    onAddCustom: {
                        customTagTitle = ""
                        isAddTagPresented = true
                    },
                    onRemoveCustom: { tag in
                        saveTags(tags.subtracting([tag]))
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noteCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("log.note")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("calendar.note.placeholder", text: $dietNote, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(EasePalette.primaryText)
                    .lineLimit(3...6)
                    .focused($isNoteFocused)
                    .padding(12)
                    .background(
                        EasePalette.recessed,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailMetric(
        _ title: LocalizedStringKey,
        _ value: String?,
        showUnit: Bool = true,
        valueColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value ?? "—")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(valueColor ?? EasePalette.primaryText)
                if showUnit, value != nil {
                    Text("unit.kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signedOne(_ value: Double) -> String {
        if value > 0 { return "+\(EaseFormatters.oneDecimal(value))" }
        if value < 0 { return EaseFormatters.oneDecimal(value) }
        return EaseFormatters.oneDecimal(value)
    }

    private func hydrateNote() {
        dietNote = record?.note ?? ""
    }

    private func scheduleNoteSave(immediate: Bool = false) {
        noteSaveTask?.cancel()
        noteSaveTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(450))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                saveNoteIfNeeded()
            }
        }
    }

    private func saveDiet(_ status: DietStatus?) {
        var patch = DailyRecordPatch()
        patch.dietStatus = .set(status)
        do {
            try DailyRecordRepository(context: modelContext).upsert(on: date, patch: patch)
            dietSelectionToken = status?.rawValue ?? "none-\(UUID().uuidString)"
            refreshReminders()
        } catch {
            // Keep UI quiet; chips reflect persisted state via @Query.
        }
    }

    private func toggleTag(_ tag: VariableTag) {
        var next = tags
        if next.contains(tag) { next.remove(tag) } else { next.insert(tag) }
        saveTags(next)
    }

    private func saveTags(_ next: Set<VariableTag>) {
        var patch = DailyRecordPatch()
        patch.tags = .set(VariableTag.sanitized(Array(next)))
        do {
            try DailyRecordRepository(context: modelContext).upsert(on: date, patch: patch)
        } catch {
            // Keep UI quiet; chips reflect persisted state via @Query.
        }
    }

    private func addCustomTag() {
        guard let tag = VariableTag.custom(from: customTagTitle) else { return }
        customTagTitle = ""
        saveTags(tags.union([tag]))
    }

    private func addCustomMeal() {
        guard let slot = MealSlot.custom(title: customMealTitle) else { return }
        customMealTitle = ""
        do {
            try saveMealPhotoFileName(nil, for: slot)
        } catch {
            // Keep carousel as persisted state.
        }
    }

    private func removeCustomMeal(_ slot: MealSlot) {
        var extras = record?.extraMeals ?? []
        let oldName = extras.first(where: { $0.id == slot.id })?.fileName
        extras.removeMeal(id: slot.id)
        var patch = DailyRecordPatch()
        patch.extraMeals = .set(extras)
        do {
            try DailyRecordRepository(context: modelContext).upsert(on: date, patch: patch)
            MealPhotoStore.deleteAsync(fileName: oldName)
        } catch {
            // Keep existing slot if upsert fails.
        }
    }

    private func saveNoteIfNeeded() {
        let trimmed = dietNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let next: String? = trimmed.isEmpty ? nil : trimmed
        guard next != record?.note else { return }
        if next == nil, record == nil { return }

        var patch = DailyRecordPatch()
        patch.note = .set(next)
        do {
            try DailyRecordRepository(context: modelContext).upsert(on: date, patch: patch)
        } catch {
            // Keep typing state; next change or blur retries.
        }
    }

    private func persistCapturedImage(_ image: UIImage, for slot: MealSlot) async {
        await MainActor.run {
            isPhotoBusy = true
            capturedImage = nil
        }
        defer {
            Task { @MainActor in
                isPhotoBusy = false
                pendingMeal = nil
            }
        }
        do {
            let fileName = try await MealPhotoStore.saveJPEG(image, compressionQuality: 0.8)
            guard !Task.isCancelled else {
                MealPhotoStore.deleteAsync(fileName: fileName)
                return
            }
            try await MainActor.run {
                try saveMealPhotoFileName(fileName, for: slot)
            }
        } catch {
            // Leave previous photo in place.
        }
    }

    private func applyLibraryPhoto(from item: PhotosPickerItem, slot: MealSlot) async {
        await MainActor.run {
            isPhotoBusy = true
        }
        defer {
            Task { @MainActor in
                isPhotoBusy = false
                photoItem = nil
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
            try await MainActor.run {
                try saveMealPhotoFileName(fileName, for: slot)
            }
        } catch {
            // Leave previous photo in place.
        }
    }

    private func clearMealPhoto(for slot: MealSlot) {
        do {
            try saveMealPhotoFileName(nil, for: slot)
        } catch {
            // Keep existing filename if upsert fails.
        }
    }

    private func saveMealPhotoFileName(_ fileName: String?, for slot: MealSlot) throws {
        var patch = DailyRecordPatch()
        if slot.storesInLegacyFields {
            patch.setMealPhotoFileName(fileName, for: slot)
        } else {
            var extras = record?.extraMeals ?? []
            extras.upsert(slot: slot, fileName: fileName)
            patch.extraMeals = .set(extras)
        }
        try DailyRecordRepository(context: modelContext).upsert(on: date, patch: patch)
    }

    private func refreshReminders() {
        let enabled = profiles.first?.notificationsEnabled == true
        Task {
            await NotificationScheduler.refresh(enabled: enabled, context: modelContext)
        }
    }
}
