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
                ScrollView {
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
                                if !preview.skippedSamples.isEmpty {
                                    DisclosureGroup {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(preview.skippedSamples) { sample in
                                                Text(skipLine(sample))
                                                    .font(.system(size: 13, weight: .regular))
                                                    .foregroundStyle(EasePalette.secondaryText)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        .padding(.top, 8)
                                    } label: {
                                        Text("settings.import.skippedSamples")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundStyle(EasePalette.primaryText)
                                    }
                                    .tint(EasePalette.primaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        EasePrimaryButton(title: "common.confirm", action: {
                            onConfirm()
                            dismiss()
                        })
                        EaseTextButton(title: "common.cancel", action: { dismiss() })
                    }
                    .padding(20)
                }
            }
            .navigationTitle("settings.import")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.light)
        .easeSheetPresentation()
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

    private func skipLine(_ sample: CSVImporter.SkippedSample) -> String {
        let reason: String
        switch sample.reason {
        case .futureDate: reason = String(localized: "import.skip.futureDate")
        case .unparsable: reason = String(localized: "import.skip.unparsable")
        case .outOfRange: reason = String(localized: "import.skip.outOfRange")
        case .unknownMetric: reason = String(localized: "import.skip.unknownMetric")
        case .duplicate: reason = String(localized: "import.skip.duplicate")
        }
        return String(
            format: String(localized: "import.skip.line"),
            locale: .current,
            sample.lineNumber,
            reason
        )
    }
}
