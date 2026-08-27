import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MealPhotoThumbnail: View {
    let fileName: String?
    var isBusy: Bool = false
    var showsCutout: Bool = false
    var cornerRadius: CGFloat = 16

    private var roundedRect: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @State private var original: UIImage?
    @State private var cutout: UIImage?
    @State private var isCutoutBusy = false

    private var taskID: String {
        "\(fileName ?? "")-\(showsCutout ? "cutout" : "original")"
    }

    var body: some View {
        ZStack {
            roundedRect.fill(EasePalette.recessed)
            if showsCutout, let cutout {
                Image(uiImage: cutout)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            } else if let original {
                Image(uiImage: original)
                    .resizable()
                    .scaledToFill()
                    .clipShape(roundedRect)
                    .opacity(showsCutout && isCutoutBusy ? 0.45 : 1)
            } else if fileName == nil {
                Image(systemName: "camera")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            if isBusy || (showsCutout && isCutoutBusy) {
                ProgressView()
                    .tint(EasePalette.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(roundedRect)
        .task(id: taskID) {
            await load()
        }
    }

    private func load() async {
        guard let fileName else {
            original = nil
            cutout = nil
            isCutoutBusy = false
            return
        }
        if let hit = MealPhotoStore.peek(fileName) {
            original = hit
        } else {
            original = await MealPhotoStore.loadImage(fileName: fileName)
        }
        guard showsCutout else {
            cutout = nil
            isCutoutBusy = false
            return
        }
        if let cachedName = MealPhotoStore.cutoutFileName(for: fileName),
           let hit = MealPhotoStore.peek(cachedName) {
            cutout = hit
            return
        }
        isCutoutBusy = true
        defer { isCutoutBusy = false }
        let generated = await MealPhotoStore.cutoutImage(forOriginal: fileName)
        guard !Task.isCancelled else { return }
        cutout = generated
    }
}

struct MealPhotoPreviewCover: View {
    let fileName: String
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            EasePalette.background.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .accessibilityLabel(Text("calendar.meal.preview"))
            } else {
                ProgressView()
                    .tint(EasePalette.accent)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel(Text("common.close"))
            .padding(20)
        }
        .task(id: fileName) {
            image = await MealPhotoStore.loadOriginal(fileName: fileName)
        }
        .preferredColorScheme(.light)
    }
}

struct MealPhotoPreviewItem: Identifiable {
    var id: String { fileName }
    let fileName: String
}

struct PickedUIImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return PickedUIImage(image: image)
        }
    }
}
