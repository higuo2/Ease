import Foundation
import UIKit
import Vision

enum ScaleOCR {
    struct Result: Equatable, Sendable {
        var weightKg: Double?
        var bodyFatPercent: Double?
    }

    struct Line: Equatable, Sendable {
        var text: String
        var area: CGFloat
    }

    static func recognize(image: UIImage) async -> Result {
        guard let cgImage = flattened(image) else { return Result() }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runVision(cgImage: cgImage))
            }
        }
    }

    static func parse(lines: [Line]) -> Result {
        var candidates: [Candidate] = []
        for line in lines {
            candidates.append(contentsOf: candidates(in: line))
        }
        return Result(
            weightKg: pickWeight(candidates),
            bodyFatPercent: pickBodyFat(candidates)
        )
    }

    private static func runVision(cgImage: CGImage) -> Result {
        let observations = observations(from: cgImage, languages: ["zh-Hans", "en-US"])
            ?? observations(from: cgImage, languages: [])
            ?? []
        let lines = observations.compactMap { observation -> Line? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            return Line(text: text, area: box.width * box.height)
        }
        return parse(lines: lines)
    }

    private static func observations(from cgImage: CGImage, languages: [String]) -> [VNRecognizedTextObservation]? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        }
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            return request.results
        } catch {
            return nil
        }
    }

    private static func flattened(_ image: UIImage) -> CGImage? {
        let maxSide: CGFloat = 1600
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }

    private struct Candidate {
        var value: Double
        var area: CGFloat
        var isKg: Bool
        var isPercent: Bool
        var isWeightLabeled: Bool
        var isFatLabeled: Bool
        var isBMI: Bool
        var isIgnored: Bool
    }

    private static let numberPattern = try! NSRegularExpression(
        pattern: #"(?<![0-9])[0-9]{1,3}(?:[.,][0-9]{1,2})?(?![0-9])"#
    )

    private static func candidates(in line: Line) -> [Candidate] {
        let folded = fold(line.text)
        let isKg = folded.contains("kg")
        let isPercent = folded.contains("%")
        let isWeightLabeled = isKg || folded.contains("体重") || folded.contains("weight")
        let isFatLabeled = folded.contains("体脂") || folded.contains("脂肪")
            || folded.contains("bodyfat") || (folded.contains("fat") && !folded.contains("fatfree"))
        let isBMI = folded.contains("bmi") || folded.contains("体质指数") || folded.contains("身体质量")
        let isIgnored = ignoreTokens.contains { folded.contains($0) }

        let ns = line.text as NSString
        let range = NSRange(location: 0, length: ns.length)
        return numberPattern.matches(in: line.text, range: range).compactMap { match in
            guard let value = EaseFormatters.parseDecimal(ns.substring(with: match.range)) else {
                return nil
            }
            return Candidate(
                value: value,
                area: line.area,
                isKg: isKg,
                isPercent: isPercent,
                isWeightLabeled: isWeightLabeled,
                isFatLabeled: isFatLabeled,
                isBMI: isBMI,
                isIgnored: isIgnored
            )
        }
    }

    private static func pickWeight(_ candidates: [Candidate]) -> Double? {
        let pool = candidates.filter { candidate in
            guard !candidate.isIgnored, !candidate.isBMI, !candidate.isFatLabeled else { return false }
            if candidate.isPercent && !candidate.isKg { return false }
            return (try? MeasurementBounds.validatedWeight(candidate.value)) != nil
        }
        let labeled = pool.filter { $0.isKg || $0.isWeightLabeled }
        if labeled.isEmpty {
            return uniqueValue(pool) ?? uniquelyLargest(pool)
        }
        if let unique = uniqueValue(labeled) { return unique }
        return labeled.count == 1 ? labeled[0].value : nil
    }

    private static func pickBodyFat(_ candidates: [Candidate]) -> Double? {
        let pool = candidates.filter { candidate in
            guard !candidate.isIgnored, !candidate.isBMI, !candidate.isKg, !candidate.isWeightLabeled else {
                return false
            }
            guard candidate.isPercent || candidate.isFatLabeled else { return false }
            return (try? MeasurementBounds.validatedBodyFat(candidate.value)) != nil
        }
        if let unique = uniqueValue(pool) { return unique }
        let labeled = pool.filter(\.isFatLabeled)
        if let unique = uniqueValue(labeled) { return unique }
        return labeled.count == 1 ? labeled[0].value : nil
    }

    private static func uniqueValue(_ items: [Candidate]) -> Double? {
        let values = Set(items.map(\.value))
        return values.count == 1 ? values.first : nil
    }

    private static func uniquelyLargest(_ items: [Candidate]) -> Double? {
        guard let top = items.max(by: { $0.area < $1.area }) else { return nil }
        if items.count == 1 { return top.value }
        let second = items
            .filter { $0.value != top.value }
            .map(\.area)
            .max() ?? 0
        guard second > 0 else { return top.value }
        guard top.area / second >= 1.4 else { return nil }
        return top.value
    }

    private static func fold(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "％", with: "%")
            .replacingOccurrences(of: " ", with: "")
    }

    private static let ignoreTokens = [
        "water", "水分", "muscle", "肌肉", "bone", "骨量", "骨骼肌",
        "bmr", "kcal", "visceral", "内脏", "protein", "蛋白",
        "subcut", "皮下", "skeletal"
    ]
}
