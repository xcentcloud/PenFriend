import SwiftUI
import PencilKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var selectedTool: EditingTool
    let onUndoStateChange: (UndoManager?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .systemBackground
        canvasView.drawingPolicy = .anyInput
        canvasView.alwaysBounceVertical = true
        canvasView.delegate = context.coordinator
        canvasView.minimumZoomScale = 1.0
        canvasView.maximumZoomScale = 4.0
        canvasView.contentSize = CGSize(width: 2000, height: 3000)
        canvasView.becomeFirstResponder()

        context.coordinator.lastCanvasDrawingData = drawing.dataRepresentation()
        canvasView.drawing = drawing
        applySelectedTool(to: canvasView)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self

        let updatedDrawingData = drawing.dataRepresentation()
        if context.coordinator.suppressNextUIViewSync {
            context.coordinator.suppressNextUIViewSync = false
        } else if context.coordinator.lastCanvasDrawingData != updatedDrawingData {
            // Setting the drawing fires the delegate synchronously; ignore that callback
            // so we don't write back into the binding during a SwiftUI view update.
            context.coordinator.isApplyingDrawingFromSwiftUI = true
            uiView.drawing = drawing
            context.coordinator.isApplyingDrawingFromSwiftUI = false
        }
        context.coordinator.lastCanvasDrawingData = updatedDrawingData

        applySelectedTool(to: uiView)
        context.coordinator.installToolPickerIfNeeded(for: uiView)

        // Defer undo-state reporting until after the current view update finishes,
        // since it publishes changes on the view model.
        let onUndoStateChange = onUndoStateChange
        let undoManager = uiView.undoManager
        Task { @MainActor in
            onUndoStateChange(undoManager)
        }
    }

    private func applySelectedTool(to canvasView: PKCanvasView) {
        switch selectedTool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: .label, width: 5)
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: .systemBlue, width: 10)
        case .pencil:
            canvasView.tool = PKInkingTool(.pencil, color: .label, width: 4)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        case .lasso:
            canvasView.tool = PKLassoTool()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasView
        private let toolPicker = PKToolPicker()
        private weak var observedCanvasView: PKCanvasView?
        var suppressNextUIViewSync = false
        var lastCanvasDrawingData = Data()
        var isApplyingDrawingFromSwiftUI = false

        init(_ parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingDrawingFromSwiftUI else { return }
            suppressNextUIViewSync = true
            lastCanvasDrawingData = canvasView.drawing.dataRepresentation()
            parent.drawing = canvasView.drawing
            parent.onUndoStateChange(canvasView.undoManager)
        }

        func installToolPickerIfNeeded(for canvasView: PKCanvasView) {
            guard canvasView.window != nil else { return }

            if observedCanvasView !== canvasView {
                if let observedCanvasView {
                    toolPicker.removeObserver(observedCanvasView)
                }
                toolPicker.addObserver(canvasView)
                observedCanvasView = canvasView
            }

            toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        deinit {
            if let observedCanvasView {
                toolPicker.removeObserver(observedCanvasView)
            }
        }
    }
}
