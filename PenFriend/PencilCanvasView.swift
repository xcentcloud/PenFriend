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

        applySelectedTool(to: canvasView)
        context.coordinator.installToolPickerIfNeeded(for: canvasView)
        onUndoStateChange(canvasView.undoManager)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self

        if uiView.drawing.dataRepresentation() != drawing.dataRepresentation() {
            uiView.drawing = drawing
        }

        applySelectedTool(to: uiView)
        context.coordinator.installToolPickerIfNeeded(for: uiView)
        onUndoStateChange(uiView.undoManager)
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

        init(_ parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onUndoStateChange(canvasView.undoManager)
        }

        func installToolPickerIfNeeded(for canvasView: PKCanvasView) {
            guard canvasView.window != nil else { return }
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
    }
}
