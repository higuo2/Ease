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
            image = nil
            guard fileName != nil else { return }
            image = await MealPhotoStore.loadImage(fileName: fileName)
        }
    }
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
