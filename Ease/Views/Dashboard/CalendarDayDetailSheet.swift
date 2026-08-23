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
    @State private var isPhotoPickerPresented = false
    @State private var isPhotoBusy = false
    @State private var dietSelectionToken = ""

    private var record: DailyRecord? {
        let key = CalendarDay.dayKey(from: date)
        return allRecords.first { $0.dayKey == key }
    }

    private var diet: DietStatus? { record?.dietStatus }

    private var mealColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
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
            .onChange(of: photoItem) { _, item in
                guard let item, let pendingMeal else { return }
                Task { await applyMealPhoto(from: item, slot: pendingMeal) }
            }
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $photoItem,
                matching: .images
            )
            .sensoryFeedback(.selection, trigger: dietSelectionToken)
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

                LazyVGrid(columns: mealColumns, spacing: 10) {
                    ForEach(MealSlot.allCases) { slot in
                        mealTile(slot)
                    }
                }
            }
        }
    }

    private var dietChipsCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("log.diet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(DietStatus.allCases, id: \.self) { status in
                        dietChip(status)
                    }
                }
                .animation(.snappy, value: dietSelectionToken)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func mealTile(_ slot: MealSlot) -> some View {
        let data = record?.mealPhotoData(for: slot)
        let image = data.flatMap { UIImage(data: $0) }

        return Button {
            pendingMeal = slot
            Task {
                await PermissionsService.requestPhotoLibrary()
                isPhotoPickerPresented = true
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(EasePalette.recessed)
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Image(systemName: "camera")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                    if isPhotoBusy && pendingMeal == slot {
                        ProgressView()
                            .tint(EasePalette.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

                Text(LocalizedStringKey(slot.titleKey))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(EasePalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .disabled(isPhotoBusy)
        .contextMenu {
            if data != nil {
                Button(role: .destructive) {
                    saveMealPhoto(nil, for: slot)
                } label: {
                    Label("calendar.meal.remove", systemImage: "trash")
                }
            }
        }
    }

    private func dietChip(_ status: DietStatus) -> some View {
        let selected = diet == status
        let tint = EasePalette.dietTint(status)
        return Button {
            saveDiet(selected ? nil : status)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: status.systemImage)
                Text(LocalizedStringKey(status.titleKey))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? tint : EasePalette.secondaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                selected ? tint.opacity(0.18) : EasePalette.recessed,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
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

    private func saveMealPhoto(_ data: Data?, for slot: MealSlot) {
        var patch = DailyRecordPatch()
        patch.setMealPhoto(data, for: slot)
        do {
            try DailyRecordRepository(context: modelContext).upsert(on: date, patch: patch)
        } catch {
            // Ignore transient save failures; tile stays on last known data.
        }
    }

    private func applyMealPhoto(from item: PhotosPickerItem, slot: MealSlot) async {
        isPhotoBusy = true
        defer {
            isPhotoBusy = false
            photoItem = nil
            pendingMeal = nil
        }
        guard let picked = try? await item.loadTransferable(type: PickedMealImage.self) else { return }
        let jpeg = picked.image.jpegData(compressionQuality: 0.72)
        await MainActor.run {
            saveMealPhoto(jpeg, for: slot)
        }
    }

    private func refreshReminders() {
        let enabled = profiles.first?.notificationsEnabled == true
        Task {
            await NotificationScheduler.refresh(enabled: enabled, context: modelContext)
        }
    }
}

private struct PickedMealImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return PickedMealImage(image: image)
        }
    }
}
