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
        let previousDrawing = currentDrawing
        let result = strokeSmoothingService.smooth(currentDrawing, useCustomModel: useCustomSmoothingModel)
        guard result.drawing.dataRepresentation() != previousDrawing.dataRepresentation() else {
            smoothingStatus = useCustomSmoothingModel
                ? "No smoothing changes were applied."
                : "Interpolation smoothing made no visible changes."
            return
        }

        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreDrawing(previousDrawing)
        }
        undoManager?.setActionName("Smooth Handwriting")

        currentDrawing = result.drawing
        pages[selectedPageIndex].drawing = result.drawing
        refreshUndoState()

        if result.usedCustomModel {
            smoothingStatus = result.unchangedStrokeCount > 0
                ? "Smoothed with custom model (\(result.unchangedStrokeCount) low-confidence stroke(s) kept)."
                : "Smoothed with custom model."
        } else if useCustomSmoothingModel {
            smoothingStatus = "Custom model unavailable. Applied interpolation smoothing."
        } else {
            smoothingStatus = "Applied interpolation smoothing."
        }
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

    private func restoreDrawing(_ drawing: PKDrawing) {
        currentDrawing = drawing
        guard pages.indices.contains(selectedPageIndex) else { return }
        pages[selectedPageIndex].drawing = drawing
        refreshUndoState()
    }
}
