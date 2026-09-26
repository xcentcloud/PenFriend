import Foundation
import PencilKit

struct NotePage: Identifiable {
    let id = UUID()
    var drawing = PKDrawing()
}

enum EditingTool: String, CaseIterable, Identifiable {
    case pen = "Pen"
    case marker = "Marker"
    case pencil = "Pencil"
    case eraser = "Eraser"
    case lasso = "Select"

    var id: String { rawValue }
}

@MainActor
final class NotesViewModel: ObservableObject {
    @Published private(set) var pages: [NotePage] = [NotePage()]
    @Published var selectedPageIndex: Int = 0 {
        didSet {
            loadCurrentPageDrawing()
        }
    }
    @Published var currentDrawing = PKDrawing() {
        didSet {
            guard !isLoadingPageDrawing else { return }
            guard pages.indices.contains(selectedPageIndex) else { return }
            pages[selectedPageIndex].drawing = currentDrawing
        }
    }
    @Published var selectedTool: EditingTool = .pen
    @Published var useCustomSmoothingModel = false
    @Published private(set) var smoothingStatus: String?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var undoManager: UndoManager?
    private var isLoadingPageDrawing = false
    private let strokeSmoothingService = StrokeSmoothingService()

    init() {
        loadCurrentPageDrawing()
    }

    var pageLabel: String {
        "Page \(selectedPageIndex + 1) of \(pages.count)"
    }

    func addNewPage() {
        pages.append(NotePage())
        selectedPageIndex = max(0, pages.count - 1)
    }

    func goToPreviousPage() {
        guard selectedPageIndex > 0 else { return }
        selectedPageIndex -= 1
    }

    func goToNextPage() {
        guard selectedPageIndex < pages.count - 1 else { return }
        selectedPageIndex += 1
    }

    func bindUndoManager(_ manager: UndoManager?) {
        undoManager = manager
        refreshUndoState()
    }

    func undo() {
        undoManager?.undo()
        refreshUndoState()
    }

    func redo() {
        undoManager?.redo()
        refreshUndoState()
    }

    func smoothCurrentDrawing() {
        let result = strokeSmoothingService.smooth(currentDrawing, useCustomModel: useCustomSmoothingModel)
        guard result.didChange else {
            smoothingStatus = statusMessage(for: result, changed: false)
            return
        }

        transitionDrawing(from: currentDrawing, to: result.drawing, actionName: "Smooth Handwriting")
        smoothingStatus = statusMessage(for: result, changed: true)
    }

    private func loadCurrentPageDrawing() {
        guard pages.indices.contains(selectedPageIndex) else { return }
        isLoadingPageDrawing = true
        defer { isLoadingPageDrawing = false }
        currentDrawing = pages[selectedPageIndex].drawing
    }

    func refreshUndoState() {
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
    }

    private func transitionDrawing(from previousDrawing: PKDrawing, to nextDrawing: PKDrawing, actionName: String) {
        undoManager?.registerUndo(withTarget: self) { target in
            target.transitionDrawing(from: nextDrawing, to: previousDrawing, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
        applyDrawing(nextDrawing)
    }

    private func applyDrawing(_ drawing: PKDrawing) {
        currentDrawing = drawing
        if pages.indices.contains(selectedPageIndex) {
            pages[selectedPageIndex].drawing = drawing
        }
        refreshUndoState()
    }

    private func statusMessage(for result: StrokeSmoothingResult, changed: Bool) -> String {
        switch result.modelStatus {
        case .customModelApplied:
            if changed {
                return result.unchangedStrokeCount > 0
                    ? "Smoothed with custom model (\(result.unchangedStrokeCount) low-confidence stroke(s) kept)."
                    : "Smoothed with custom model."
            }
            return "Custom model produced no visible smoothing changes."
        case .customModelUnavailable:
            return changed
                ? "Custom model unavailable. Applied interpolation smoothing."
                : "Custom model unavailable and interpolation made no visible changes."
        case .customModelPredictionFailed:
            return changed
                ? "Custom model inference failed. Applied interpolation smoothing."
                : "Custom model inference failed and interpolation made no visible changes."
        case .interpolationOnly:
            return changed
                ? "Applied interpolation smoothing."
                : "Interpolation smoothing made no visible changes."
        }
    }
}
