import Foundation
import PencilKit

enum PageLayoutStyle: String, CaseIterable, Identifiable, Codable {
    case notebook = "Notebook"
    case canvas = "Canvas"

    var id: String { rawValue }
}

enum MixedContentElementType: String, CaseIterable, Codable {
    case text
    case shape
    case link
    case image
}

struct MixedContentElement: Identifiable, Codable {
    struct Point: Codable, Equatable {
        var x: Double
        var y: Double
    }

    struct ElementSize: Codable, Equatable {
        var width: Double
        var height: Double
    }

    let id: UUID
    var type: MixedContentElementType
    var text: String
    var urlString: String?
    var imageData: Data?
    var center: Point
    var size: ElementSize
    var zIndex: Int

    init(
        id: UUID = UUID(),
        type: MixedContentElementType,
        text: String,
        urlString: String? = nil,
        imageData: Data? = nil,
        center: Point,
        size: ElementSize,
        zIndex: Int
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.urlString = urlString
        self.imageData = imageData
        self.center = center
        self.size = size
        self.zIndex = zIndex
    }
}

struct NotePage: Identifiable {
    let id: UUID
    var drawing: PKDrawing
    var layoutStyle: PageLayoutStyle
    var elements: [MixedContentElement]

    init(
        id: UUID = UUID(),
        drawing: PKDrawing = PKDrawing(),
        layoutStyle: PageLayoutStyle = .notebook,
        elements: [MixedContentElement] = []
    ) {
        self.id = id
        self.drawing = drawing
        self.layoutStyle = layoutStyle
        self.elements = elements
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

    var currentPageLayoutStyle: PageLayoutStyle {
        guard pages.indices.contains(selectedPageIndex) else { return .notebook }
        return pages[selectedPageIndex].layoutStyle
    }

    var currentPageElements: [MixedContentElement] {
        guard pages.indices.contains(selectedPageIndex) else { return [] }
        return pages[selectedPageIndex].elements.sorted { $0.zIndex < $1.zIndex }
    }

    func restoreIfNeeded() async {
        let shouldRestore = await MainActor.run { () -> Bool in
            guard !hasRestoredPages else { return false }
            hasRestoredPages = true
            return true
        }
        guard shouldRestore else { return }
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

    private func restorePages() async {
        do {
            let storage = noteStorage
            let snapshot = try await Task.detached {
                try await storage.loadSnapshot()
            }.value
            await MainActor.run {
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
            }
        } catch {
            let storage = noteStorage
            try? await Task.detached {
                try await storage.ensureLocalFallbackNotebookExists()
            }.value
            let fallbackSnapshot = try? await Task.detached {
                try await storage.loadLocalSnapshot()
            }.value
            if let fallbackSnapshot {
                await MainActor.run {
                    isRestoringStoredPages = true
                    defer { isRestoringStoredPages = false }
                    pages = fallbackSnapshot.pages
                    if pages.isEmpty {
                        pages = [NotePage()]
                    }
                    selectedPageIndex = min(selectedPageIndex, max(0, fallbackSnapshot.pages.count - 1))
                    loadCurrentPageDrawing()
                    storageLocation = .local
                    storageStatus = "Couldn't open iCloud notes. Restored local notes instead."
                }
            } else {
                await MainActor.run {
                    isRestoringStoredPages = true
                    defer { isRestoringStoredPages = false }
                    pages = [NotePage()]
                    selectedPageIndex = 0
                    loadCurrentPageDrawing()
                    storageLocation = .local
                    storageStatus = "Couldn't open saved notes. Started a new local notebook."
                }
                await MainActor.run {
                    scheduleSavePages(immediate: true)
                }
            }
        }
    }

    func refreshUndoState() {
        // Only publish when the value actually changes to avoid redundant view updates.
        let newCanUndo = undoManager?.canUndo ?? false
        let newCanRedo = undoManager?.canRedo ?? false
        if canUndo != newCanUndo { canUndo = newCanUndo }
        if canRedo != newCanRedo { canRedo = newCanRedo }
    }

    func setCurrentPageLayoutStyle(_ style: PageLayoutStyle) {
        guard pages.indices.contains(selectedPageIndex) else { return }
        guard pages[selectedPageIndex].layoutStyle != style else { return }
        pages[selectedPageIndex].layoutStyle = style
        scheduleSavePages()
    }

    @discardableResult
    func addTextElement(in canvasSize: CGSize) -> UUID? {
        addElement(
            type: .text,
            text: "New Text",
            urlString: nil,
            imageData: nil,
            size: .init(width: 220, height: 90),
            in: canvasSize
        )
    }

    @discardableResult
    func addShapeElement(in canvasSize: CGSize) -> UUID? {
        addElement(
            type: .shape,
            text: "Shape",
            urlString: nil,
            imageData: nil,
            size: .init(width: 200, height: 130),
            in: canvasSize
        )
    }

    @discardableResult
    func addLinkElement(title: String, urlString: String, in canvasSize: CGSize) -> UUID? {
        addElement(
            type: .link,
            text: title.isEmpty ? "Link" : title,
            urlString: urlString,
            imageData: nil,
            size: .init(width: 260, height: 90),
            in: canvasSize
        )
    }

    @discardableResult
    func addImageElement(data: Data, in canvasSize: CGSize) -> UUID? {
        addElement(
            type: .image,
            text: "Image",
            urlString: nil,
            imageData: data,
            size: .init(width: 240, height: 180),
            in: canvasSize
        )
    }

    func updateElementText(id: UUID, text: String) {
        updateElement(id: id) { $0.text = text }
    }

    func updateElementURL(id: UUID, urlString: String) {
        updateElement(id: id) { $0.urlString = urlString }
    }

    func bringElementToFront(id: UUID) {
        guard pages.indices.contains(selectedPageIndex) else { return }
        guard let elementIndex = pages[selectedPageIndex].elements.firstIndex(where: { $0.id == id }) else { return }
        let maxZIndex = pages[selectedPageIndex].elements.map(\.zIndex).max() ?? 0
        pages[selectedPageIndex].elements[elementIndex].zIndex = maxZIndex + 1
        normalizeZIndexesForCurrentPage()
        scheduleSavePages()
    }

    func removeElement(id: UUID) {
        guard pages.indices.contains(selectedPageIndex) else { return }
        pages[selectedPageIndex].elements.removeAll { $0.id == id }
        scheduleSavePages()
    }

    func updateElementFrame(id: UUID, center: CGPoint, size: CGSize, in canvasSize: CGSize) {
        let minWidth: CGFloat = 80
        let minHeight: CGFloat = 60
        let maxWidth = max(minWidth, canvasSize.width)
        let maxHeight = max(minHeight, canvasSize.height)
        let clampedSize = CGSize(
            width: min(max(size.width, minWidth), maxWidth),
            height: min(max(size.height, minHeight), maxHeight)
        )
        let halfWidth = clampedSize.width / 2
        let halfHeight = clampedSize.height / 2
        let clampedCenter = CGPoint(
            x: min(max(center.x, halfWidth), max(halfWidth, canvasSize.width - halfWidth)),
            y: min(max(center.y, halfHeight), max(halfHeight, canvasSize.height - halfHeight))
        )

        updateElement(id: id) { element in
            element.center = .init(x: clampedCenter.x, y: clampedCenter.y)
            element.size = .init(width: clampedSize.width, height: clampedSize.height)
        }
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

    @discardableResult
    private func addElement(
        type: MixedContentElementType,
        text: String,
        urlString: String?,
        imageData: Data?,
        size: CGSize,
        in canvasSize: CGSize
    ) -> UUID? {
        guard pages.indices.contains(selectedPageIndex) else { return nil }
        let existingElementCount = pages[selectedPageIndex].elements.count
        let maxZIndex = pages[selectedPageIndex].elements.map(\.zIndex).max() ?? -1
        let offset = Double((existingElementCount % 6) * 24)
        let halfWidth = max(Double(size.width / 2), 40)
        let halfHeight = max(Double(size.height / 2), 30)
        let maxCenterX = max(halfWidth, Double(canvasSize.width) - halfWidth)
        let maxCenterY = max(halfHeight, Double(canvasSize.height) - halfHeight)
        let proposedX = Double(canvasSize.width / 2) + offset
        let proposedY = Double(canvasSize.height / 2) + offset
        let center = MixedContentElement.Point(
            x: min(max(proposedX, halfWidth), maxCenterX),
            y: min(max(proposedY, halfHeight), maxCenterY)
        )
        let element = MixedContentElement(
            type: type,
            text: text,
            urlString: urlString,
            imageData: imageData,
            center: center,
            size: .init(width: size.width, height: size.height),
            zIndex: maxZIndex + 1
        )
        pages[selectedPageIndex].elements.append(element)
        scheduleSavePages()
        return element.id
    }

    private func updateElement(id: UUID, mutation: (inout MixedContentElement) -> Void) {
        guard pages.indices.contains(selectedPageIndex) else { return }
        guard let elementIndex = pages[selectedPageIndex].elements.firstIndex(where: { $0.id == id }) else { return }
        mutation(&pages[selectedPageIndex].elements[elementIndex])
        scheduleSavePages()
    }

    private func normalizeZIndexesForCurrentPage() {
        guard pages.indices.contains(selectedPageIndex) else { return }
        let sorted = pages[selectedPageIndex].elements.sorted { lhs, rhs in
            if lhs.zIndex == rhs.zIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.zIndex < rhs.zIndex
        }
        pages[selectedPageIndex].elements = sorted.enumerated().map { index, element in
            var mutableElement = element
            mutableElement.zIndex = index
            return mutableElement
        }
    }

    deinit {
        smoothingTask?.cancel()
    }
}
