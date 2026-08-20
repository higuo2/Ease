import SwiftUI
import SwiftData

struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: CSVImporter.Preview
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    EaseCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("settings.import.preview")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(EasePalette.secondaryText)
                            ForEach(summaryLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(EasePalette.primaryText)
                            }
                            if preview.isTruncated {
                                Text("settings.import.truncated")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                    .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    EasePrimaryButton(title: "common.confirm", action: {
                        onConfirm()
                        dismiss()
                    })
                    EaseTextButton(title: "common.cancel", action: { dismiss() })
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("settings.import")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.light)
    }

    private var summaryLines: [String] {
        switch preview.kind {
        case .journal:
            return [
                String(format: String(localized: "settings.import.weighIns"), locale: .current, preview.weighInCount),
                String(format: String(localized: "settings.import.dietDays"), locale: .current, preview.dietDayCount),
                String(format: String(localized: "settings.import.duplicates"), locale: .current, preview.duplicateCount),
                String(format: String(localized: "settings.import.invalid"), locale: .current, preview.invalidCount)
            ]
        case .metrics:
            return [
                String(format: String(localized: "settings.import.metrics"), locale: .current, preview.metricLogCount),
                String(format: String(localized: "settings.import.duplicates"), locale: .current, preview.duplicateCount),
                String(format: String(localized: "settings.import.invalid"), locale: .current, preview.invalidCount)
            ]
        }
    }
}
