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
            guard pages.indices.contains(selectedPageIndex) else { return }
            pages[selectedPageIndex].drawing = currentDrawing
        }
    }
    @Published var selectedTool: EditingTool = .pen
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private weak var undoManager: UndoManager?

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

    private func loadCurrentPageDrawing() {
        guard pages.indices.contains(selectedPageIndex) else { return }
        currentDrawing = pages[selectedPageIndex].drawing
    }

    func refreshUndoState() {
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
    }
}
