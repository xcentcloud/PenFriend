import XCTest
import PencilKit
@testable import PenFriend

final class StrokeSmoothingServiceTests: XCTestCase {
    func testSmoothEmptyDrawingReturnsUnchangedInterpolationResult() {
        let service = StrokeSmoothingService(predictor: nil)

        let result = service.smooth(PKDrawing(), useCustomModel: false)

        XCTAssertTrue(isStatus(result.modelStatus, .interpolationOnly))
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.unchangedStrokeCount, 0)
    }

    func testSmoothInterpolationChangesMultiPointStroke() {
        let drawing = PKDrawing(strokes: [makeStroke(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 6),
            CGPoint(x: 20, y: 0)
        ])])
        let service = StrokeSmoothingService(predictor: nil)

        let result = service.smooth(drawing, useCustomModel: false)

        XCTAssertTrue(isStatus(result.modelStatus, .interpolationOnly))
        XCTAssertTrue(result.didChange)
        XCTAssertEqual(result.drawing.strokes.count, 1)
        let points = Array(result.drawing.strokes[0].path)
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[1].location.x, 10, accuracy: 0.0001)
        XCTAssertEqual(points[1].location.y, 3, accuracy: 0.0001)
    }

    func testSmoothWithCustomModelUnavailableFallsBack() {
        let drawing = PKDrawing(strokes: [makeStroke(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 6, y: 8),
            CGPoint(x: 12, y: 0)
        ])])
        let service = StrokeSmoothingService(predictor: nil)

        let result = service.smooth(drawing, useCustomModel: true)

        XCTAssertTrue(isStatus(result.modelStatus, .customModelUnavailable))
        XCTAssertTrue(result.didChange)
        XCTAssertEqual(result.drawing.strokes.count, 1)
        let points = Array(result.drawing.strokes[0].path)
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[1].location.x, 6, accuracy: 0.0001)
        XCTAssertEqual(points[1].location.y, 4, accuracy: 0.0001)
    }

    func testSmoothWithRejectedConfidenceKeepsOriginal() {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 0)])
        let drawing = PKDrawing(strokes: [stroke])
        let predictor = FakePredictor(result: StrokePredictionResult(strokes: [stroke], unchangedStrokeCount: 1))
        let service = StrokeSmoothingService(predictor: predictor)

        let result = service.smooth(drawing, useCustomModel: true)

        XCTAssertTrue(isStatus(result.modelStatus, .customModelRejectedByConfidence))
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.unchangedStrokeCount, 1)
    }

    private func isStatus(_ lhs: StrokeSmoothingModelStatus, _ rhs: StrokeSmoothingModelStatus) -> Bool {
        switch (lhs, rhs) {
        case (.interpolationOnly, .interpolationOnly),
             (.customModelApplied, .customModelApplied),
             (.customModelRejectedByConfidence, .customModelRejectedByConfidence),
             (.customModelUnavailable, .customModelUnavailable),
             (.customModelPredictionFailed, .customModelPredictionFailed):
            return true
        default:
            return false
        }
    }

    private func makeStroke(points: [CGPoint]) -> PKStroke {
        let controlPoints = points.enumerated().map { index, point in
            PKStrokePoint(
                location: point,
                timeOffset: Double(index),
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }

        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())
        return PKStroke(ink: PKInk(.pen, color: .black), path: path)
    }
}

private struct FakePredictor: StrokeSmoothingPredicting {
    let result: StrokePredictionResult

    func predict(from strokes: [PKStroke], confidenceThreshold: Double) throws -> StrokePredictionResult {
        result
    }
}
