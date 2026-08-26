import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MealPhotoThumbnail: View {
    let fileName: String?
    var isBusy: Bool = false

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(EasePalette.recessed)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if fileName == nil {
                Image(systemName: "camera")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            if isBusy {
                ProgressView()
                    .tint(EasePalette.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .task(id: fileName) {
            guard let fileName else {
                image = nil
                return
            }
            if let hit = MealPhotoStore.peek(fileName) {
                image = hit
                return
            }
            image = await MealPhotoStore.loadImage(fileName: fileName)
        }
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
