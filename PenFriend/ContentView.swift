import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NotesViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                controlBar

                PencilCanvasView(
                    drawing: $viewModel.currentDrawing,
                    selectedTool: $viewModel.selectedTool,
                    onUndoStateChange: { undoManager in
                        viewModel.bindUndoManager(undoManager)
                    }
                )
                .id(viewModel.selectedPageIndex)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .padding()
            .navigationTitle("PenFriend")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("New Page", systemImage: "plus.square.on.square") {
                        viewModel.addNewPage()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        viewModel.undo()
                    }
                    .disabled(!viewModel.canUndo)

                    Button("Redo", systemImage: "arrow.uturn.forward") {
                        viewModel.redo()
                    }
                    .disabled(!viewModel.canRedo)
                }
            }
        }
    }

    private var controlBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    viewModel.goToPreviousPage()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(viewModel.selectedPageIndex == 0)

                Menu {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, _ in
                        Button("Page \(index + 1)") {
                            viewModel.selectedPageIndex = index
                        }
                    }
                } label: {
                    Label(viewModel.pageLabel, systemImage: "doc.text")
                }

                Button {
                    viewModel.goToNextPage()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(viewModel.selectedPageIndex >= viewModel.pages.count - 1)
            }

            Menu {
                ForEach(EditingTool.allCases) { tool in
                    Button(tool.rawValue) {
                        viewModel.selectedTool = tool
                    }
                }
            } label: {
                Label("Tool: \(viewModel.selectedTool.rawValue)", systemImage: "pencil.tip.crop.circle")
            }
            .accessibilityLabel("Editing Tool")

            Toggle("Use Custom Machine Learning Smoothing Model", isOn: $viewModel.useCustomSmoothingModel)
                .accessibilityHint("Uses a bundled custom model when available and falls back to interpolation when unavailable.")
                .disabled(viewModel.isSmoothing)

            Button {
                viewModel.smoothCurrentDrawing()
            } label: {
                Label("Smooth Handwriting", systemImage: "wand.and.stars")
            }
            .disabled(viewModel.currentDrawing.strokes.isEmpty || viewModel.isSmoothing)

            Text(viewModel.smoothingStatus ?? " ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .opacity(viewModel.smoothingStatus == nil ? 0 : 1)
                .accessibilityLabel("Smoothing status")
                .accessibilityValue(viewModel.smoothingStatus ?? "No smoothing status")
                .accessibilityLiveRegion(.polite)
        }
    }
}

#Preview {
    ContentView()
}
