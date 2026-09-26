import Foundation
import PencilKit
import CoreML

private func rebuildStroke(from stroke: PKStroke, with path: PKStrokePath) -> PKStroke {
    PKStroke(ink: stroke.ink, path: path, transform: stroke.transform, mask: stroke.mask)
}

struct StrokeSmoothingResult {
    let drawing: PKDrawing
    let modelStatus: StrokeSmoothingModelStatus
    let unchangedStrokeCount: Int
    let didChange: Bool

    var usedCustomModel: Bool {
        modelStatus == .customModelApplied
    }
}

enum StrokeSmoothingModelStatus {
    case interpolationOnly
    case customModelApplied
    case customModelUnavailable
    case customModelPredictionFailed
}

final class StrokeSmoothingService {
    private let predictor: StrokeSmoothingPredicting?
    private let confidenceThreshold: Double

    init(
        predictor: StrokeSmoothingPredicting? = CoreMLStrokeSmoothingPredictor.loadBundledModel(named: "HandwritingSmoother"),
        confidenceThreshold: Double = 0.55
    ) {
        self.predictor = predictor
        self.confidenceThreshold = confidenceThreshold
    }

    func smooth(_ drawing: PKDrawing, useCustomModel: Bool) -> StrokeSmoothingResult {
        let originalStrokes = drawing.strokes
        guard !originalStrokes.isEmpty else {
            return StrokeSmoothingResult(
                drawing: drawing,
                modelStatus: .interpolationOnly,
                unchangedStrokeCount: 0,
                didChange: false
            )
        }

        if useCustomModel {
            guard let predictor else {
                return fallbackResult(from: drawing, strokes: originalStrokes, status: .customModelUnavailable)
            }

            guard let customResult = try? predictor.predict(from: originalStrokes, confidenceThreshold: confidenceThreshold) else {
                return fallbackResult(from: drawing, strokes: originalStrokes, status: .customModelPredictionFailed)
            }

            let smoothedDrawing = PKDrawing(strokes: customResult.strokes)
            return StrokeSmoothingResult(
                drawing: smoothedDrawing,
                modelStatus: .customModelApplied,
                unchangedStrokeCount: customResult.unchangedStrokeCount,
                didChange: smoothedDrawing.dataRepresentation() != drawing.dataRepresentation()
            )
        }

        return fallbackResult(from: drawing, strokes: originalStrokes, status: .interpolationOnly)
    }

    private static func fallbackResult(
        from originalDrawing: PKDrawing,
        strokes: [PKStroke],
        status: StrokeSmoothingModelStatus
    ) -> StrokeSmoothingResult {
        let smoothed = strokes.map(Self.interpolateStroke)
        let smoothedDrawing = PKDrawing(strokes: smoothed)
        return StrokeSmoothingResult(
            drawing: smoothedDrawing,
            modelStatus: status,
            unchangedStrokeCount: 0,
            didChange: smoothedDrawing.dataRepresentation() != originalDrawing.dataRepresentation()
        )
    }

    private static func interpolateStroke(_ stroke: PKStroke) -> PKStroke {
        let controlPoints = Array(stroke.path)
        guard controlPoints.count > 2 else { return stroke }

        var smoothedPoints = controlPoints
        for index in 1..<(controlPoints.count - 1) {
            let previous = controlPoints[index - 1]
            let current = controlPoints[index]
            let next = controlPoints[index + 1]

            let location = CGPoint(
                x: (previous.location.x + current.location.x * 2 + next.location.x) / 4,
                y: (previous.location.y + current.location.y * 2 + next.location.y) / 4
            )

            smoothedPoints[index] = PKStrokePoint(
                location: location,
                timeOffset: (previous.timeOffset + current.timeOffset * 2 + next.timeOffset) / 4,
                size: CGSize(
                    width: (previous.size.width + current.size.width * 2 + next.size.width) / 4,
                    height: (previous.size.height + current.size.height * 2 + next.size.height) / 4
                ),
                opacity: (previous.opacity + current.opacity * 2 + next.opacity) / 4,
                force: (previous.force + current.force * 2 + next.force) / 4,
                azimuth: (previous.azimuth + current.azimuth * 2 + next.azimuth) / 4,
                altitude: (previous.altitude + current.altitude * 2 + next.altitude) / 4
            )
        }

        let smoothedPath = PKStrokePath(controlPoints: smoothedPoints, creationDate: stroke.path.creationDate)
        return rebuildStroke(from: stroke, with: smoothedPath)
    }

}

protocol StrokeSmoothingPredicting {
    func predict(from strokes: [PKStroke], confidenceThreshold: Double) throws -> StrokePredictionResult
}

struct StrokePredictionResult {
    let strokes: [PKStroke]
    let unchangedStrokeCount: Int
}

enum StrokePredictionError: Error {
    case invalidInput
    case invalidOutput
}

final class CoreMLStrokeSmoothingPredictor: StrokeSmoothingPredicting {
    private let model: MLModel

    init(model: MLModel) {
        self.model = model
    }

    static func loadBundledModel(named name: String) -> CoreMLStrokeSmoothingPredictor? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: url) else {
            return nil
        }
        return CoreMLStrokeSmoothingPredictor(model: model)
    }

    func predict(from strokes: [PKStroke], confidenceThreshold: Double) throws -> StrokePredictionResult {
        let input = try Self.makeInput(strokes: strokes)
        let output = try model.prediction(from: input)
        return try Self.decodeOutput(output, template: strokes, confidenceThreshold: confidenceThreshold)
    }

    private static func makeInput(strokes: [PKStroke]) throws -> MLFeatureProvider {
        let pointCounts = strokes.map { $0.path.count }
        let totalPointCount = pointCounts.reduce(0, +)
        guard totalPointCount > 0 else { throw StrokePredictionError.invalidInput }

        let flattened = try MLMultiArray(shape: [NSNumber(value: totalPointCount * 9)], dataType: .double)
        let counts = try MLMultiArray(shape: [NSNumber(value: pointCounts.count)], dataType: .int32)

        var arrayIndex = 0
        for (strokeIndex, stroke) in strokes.enumerated() {
            counts[strokeIndex] = NSNumber(value: pointCounts[strokeIndex])

            for point in stroke.path {
                flattened[arrayIndex] = NSNumber(value: point.location.x)
                flattened[arrayIndex + 1] = NSNumber(value: point.location.y)
                flattened[arrayIndex + 2] = NSNumber(value: point.timeOffset)
                flattened[arrayIndex + 3] = NSNumber(value: point.size.width)
                flattened[arrayIndex + 4] = NSNumber(value: point.size.height)
                flattened[arrayIndex + 5] = NSNumber(value: point.opacity)
                flattened[arrayIndex + 6] = NSNumber(value: point.force)
                flattened[arrayIndex + 7] = NSNumber(value: point.azimuth)
                flattened[arrayIndex + 8] = NSNumber(value: point.altitude)
                arrayIndex += 9
            }
        }

        return try MLDictionaryFeatureProvider(dictionary: [
            "stroke_points": MLFeatureValue(multiArray: flattened),
            "stroke_point_counts": MLFeatureValue(multiArray: counts)
        ])
    }

    private static func decodeOutput(
        _ output: MLFeatureProvider,
        template: [PKStroke],
        confidenceThreshold: Double
    ) throws -> StrokePredictionResult {
        guard let points = output.featureValue(for: "smoothed_stroke_points")?.multiArrayValue else {
            throw StrokePredictionError.invalidOutput
        }

        let confidence = output.featureValue(for: "stroke_confidence")?.multiArrayValue
        let pointCounts = template.map { $0.path.count }
        let expectedValueCount = pointCounts.reduce(0, +) * 9
        guard points.count == expectedValueCount else { throw StrokePredictionError.invalidOutput }
        if let confidence, confidence.count != template.count {
            throw StrokePredictionError.invalidOutput
        }
        if !hasValidOutputShape(points, expectedValueCount: expectedValueCount, expectedPointCount: pointCounts.reduce(0, +)) {
            throw StrokePredictionError.invalidOutput
        }

        var rebuiltStrokes = [PKStroke]()
        rebuiltStrokes.reserveCapacity(template.count)

        var unchangedStrokeCount = 0
        var pointOffset = 0

        for (strokeIndex, stroke) in template.enumerated() {
            let isLowConfidence: Bool
            if let confidence {
                isLowConfidence = strokeIndex >= confidence.count || confidence[strokeIndex].doubleValue < confidenceThreshold
            } else {
                isLowConfidence = false
            }
            if isLowConfidence {
                rebuiltStrokes.append(stroke)
                unchangedStrokeCount += 1
                pointOffset += pointCounts[strokeIndex] * 9
                continue
            }

            var smoothedPoints = [PKStrokePoint]()
            smoothedPoints.reserveCapacity(pointCounts[strokeIndex])

            for _ in 0..<pointCounts[strokeIndex] {
                let point = PKStrokePoint(
                    location: CGPoint(
                        x: points[pointOffset].doubleValue,
                        y: points[pointOffset + 1].doubleValue
                    ),
                    timeOffset: points[pointOffset + 2].doubleValue,
                    size: CGSize(
                        width: points[pointOffset + 3].doubleValue,
                        height: points[pointOffset + 4].doubleValue
                    ),
                    opacity: points[pointOffset + 5].doubleValue,
                    force: points[pointOffset + 6].doubleValue,
                    azimuth: points[pointOffset + 7].doubleValue,
                    altitude: points[pointOffset + 8].doubleValue
                )
                smoothedPoints.append(point)
                pointOffset += 9
            }

            let path = PKStrokePath(controlPoints: smoothedPoints, creationDate: stroke.path.creationDate)
            rebuiltStrokes.append(rebuildStroke(from: stroke, with: path))
        }

        return StrokePredictionResult(strokes: rebuiltStrokes, unchangedStrokeCount: unchangedStrokeCount)
    }

    private static func hasValidOutputShape(
        _ points: MLMultiArray,
        expectedValueCount: Int,
        expectedPointCount: Int
    ) -> Bool {
        let shape = points.shape.map(\.intValue)
        let strides = points.strides.map(\.intValue)

        if shape == [expectedValueCount] {
            return true
        }

        if shape == [expectedPointCount, 9], strides == [9, 1] {
            return true
        }

        return false
    }
}
