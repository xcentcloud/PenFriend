import Foundation
import PencilKit

struct NotePage: Identifiable {
    let id: UUID
    var drawing: PKDrawing

    init(id: UUID = UUID(), drawing: PKDrawing = PKDrawing()) {
        self.id = id
        self.drawing = drawing
    }
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
            drawingRevision &+= 1
            guard !isLoadingPageDrawing else { return }
            guard pages.indices.contains(selectedPageIndex) else { return }
            pages[selectedPageIndex].drawing = currentDrawing
            scheduleSavePages()
        }
    }
    @Published var selectedTool: EditingTool = .pen
    @Published var useCustomSmoothingModel = false
    @Published private(set) var smoothingStatus: String?
    @Published private(set) var isSmoothing = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var storageLocation: NoteStorageLocation = .local
    @Published private(set) var storageStatus = "Checking iCloud note storage…"

    private var undoManager: UndoManager?
    private var isLoadingPageDrawing = false
    private var isRestoringStoredPages = false
    private var drawingRevision: UInt64 = 0
    private var smoothingRequestID: UInt64 = 0
    private var saveRequestID: UInt64 = 0
    private var smoothingTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var hasRestoredPages = false
    private let strokeSmoothingService = StrokeSmoothingService()
    private let noteStorage: any NoteStorageControlling

    init(noteStorage: any NoteStorageControlling = NoteStorage()) {
        self.noteStorage = noteStorage
        loadCurrentPageDrawing()
    }

    var pageLabel: String {
        "Page \(selectedPageIndex + 1) of \(pages.count)"
    }

    func restoreIfNeeded() async {
        guard !hasRestoredPages else { return }
        hasRestoredPages = true
        await restorePages()
    }

    var storageStatusIconName: String {
        switch storageLocation {
        case .iCloud:
            return "icloud"
        case .local:
            return "internaldrive"
        }
    }

    func addNewPage() {
        pages.append(NotePage())
        scheduleSavePages()
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
        let sourceDrawing = currentDrawing
        let sourceRevision = drawingRevision
        let useCustomModel = useCustomSmoothingModel
        smoothingRequestID &+= 1
        let requestID = smoothingRequestID
        isSmoothing = true

        smoothingTask?.cancel()
        smoothingTask = Task { [strokeSmoothingService] in
            let workerTask = Task.detached(priority: .userInitiated) {
                strokeSmoothingService.smooth(sourceDrawing, useCustomModel: useCustomModel)
            }
            let result = await withTaskCancellationHandler {
                await workerTask.value
            } onCancel: {
                workerTask.cancel()
            }
            guard !Task.isCancelled else {
                await MainActor.run {
                    guard requestID == smoothingRequestID else { return }
                    isSmoothing = false
                    smoothingTask = nil
                }
                return
            }

            await MainActor.run {
                guard requestID == smoothingRequestID else { return }
                defer {
                    isSmoothing = false
                    smoothingTask = nil
                }

                guard drawingRevision == sourceRevision else {
                    smoothingStatus = "Drawing changed before smoothing completed. Run smoothing again."
                    return
                }

                guard result.didChange else {
                    smoothingStatus = statusMessage(for: result, changed: false)
                    return
                }

                transitionDrawing(from: currentDrawing, to: result.drawing, actionName: "Smooth Handwriting")
                smoothingStatus = statusMessage(for: result, changed: true)
            }
        }
    }

    private func loadCurrentPageDrawing() {
        guard pages.indices.contains(selectedPageIndex) else { return }
        isLoadingPageDrawing = true
        defer { isLoadingPageDrawing = false }
        currentDrawing = pages[selectedPageIndex].drawing
    }

    @MainActor
    private func restorePages() async {
        var shouldCreateInitialFile = false
        do {
            let storage = noteStorage
            let snapshot = try await Task.detached {
                try await storage.loadSnapshot()
            }.value
            do {
                isRestoringStoredPages = true
                defer { isRestoringStoredPages = false }
                pages = snapshot.pages
                selectedPageIndex = min(selectedPageIndex, max(0, pages.count - 1))
                if pages.isEmpty {
                    pages = [NotePage()]
                    selectedPageIndex = 0
                }
                loadCurrentPageDrawing()
                storageStatus = snapshot.location.statusMessage
                storageLocation = snapshot.location
                if snapshot.didMigrateFromLocalStorage {
                    storageStatus = "Moved existing notes into iCloud."
                }
                shouldCreateInitialFile = snapshot.shouldCreateInitialFile
            }
            if shouldCreateInitialFile {
                scheduleSavePages(immediate: true)
            }
        } catch {
            let storage = noteStorage
            try? await Task.detached {
                try await storage.ensureLocalFallbackNotebookExists()
            }.value
            if let fallbackSnapshot = try? await Task.detached {
                try await storage.loadLocalSnapshot()
            }.value {
                pages = fallbackSnapshot.pages
                selectedPageIndex = min(selectedPageIndex, max(0, fallbackSnapshot.pages.count - 1))
                loadCurrentPageDrawing()
                storageLocation = .local
                storageStatus = "Couldn't open iCloud notes. Restored local notes instead."
            } else {
                pages = [NotePage()]
                selectedPageIndex = 0
                loadCurrentPageDrawing()
                storageLocation = .local
                storageStatus = "Couldn't open saved notes. Started a new local notebook."
            }
        }
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

    private func scheduleSavePages(immediate: Bool = false) {
        guard !isLoadingPageDrawing, !isRestoringStoredPages else { return }
        saveRequestID &+= 1
        let requestID = saveRequestID
        let requestedPages = immediate ? pages : nil

        saveTask?.cancel()
        saveTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard !Task.isCancelled else { return }
            let pagesToSave = requestedPages ?? pages

            do {
                let storage = noteStorage
                let location = try await Task.detached {
                    try await storage.savePages(pagesToSave)
                }.value
                guard !Task.isCancelled else { return }
                guard requestID == saveRequestID else { return }
                storageLocation = location
                storageStatus = location.statusMessage
            } catch {
                guard !Task.isCancelled else { return }
                guard requestID == saveRequestID else { return }
                storageLocation = .local
                storageStatus = "Couldn't save notes right now. Keep the app open and try again."
            }
        }
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
        case .customModelRejectedByConfidence:
            return "Custom model confidence was low for all strokes. Kept original handwriting."
        case .interpolationOnly:
            return changed
                ? "Applied interpolation smoothing."
                : "Interpolation smoothing made no visible changes."
        }
    }

    deinit {
        let latestPages = pages
        let storage = noteStorage
        Task.detached {
            try? await storage.savePages(latestPages)
        }
        smoothingTask?.cancel()
        saveTask?.cancel()
    }
}
