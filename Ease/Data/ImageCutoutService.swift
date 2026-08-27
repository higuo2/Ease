import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

enum ImageCutoutError: Error, Equatable {
    case invalidImage
    case noSubject
    case renderFailed
}

actor ImageCutoutService {
    static let shared = ImageCutoutService()

    private let ciContext = CIContext(options: nil)

    func cutout(from image: UIImage) async throws -> UIImage {
        guard let cgImage = Self.flattened(image) else {
            throw ImageCutoutError.invalidImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw ImageCutoutError.noSubject
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )

        let original = CIImage(cgImage: cgImage)
        var mask = CIImage(cvPixelBuffer: maskBuffer)
        let scaleX = original.extent.width / max(mask.extent.width, 1)
        let scaleY = original.extent.height / max(mask.extent.height, 1)
        mask = mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let clear = CIImage(color: .clear).cropped(to: original.extent)
        let filter = CIFilter.blendWithMask()
        filter.inputImage = original
        filter.backgroundImage = clear
        filter.maskImage = mask

        guard let output = filter.outputImage,
              let cgOut = ciContext.createCGImage(output, from: original.extent)
        else {
            throw ImageCutoutError.renderFailed
        }

        return UIImage(cgImage: cgOut, scale: 1, orientation: .up)
    }

    /// Bakes `imageOrientation` into pixels and caps the long edge for Vision.
    nonisolated static func flattened(_ image: UIImage, maxSide: CGFloat = 512) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}
