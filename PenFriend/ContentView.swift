import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = NotesViewModel()
    @State private var selectedElementID: UUID?
    @State private var workspaceSize = CGSize(width: 1024, height: 768)
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isPresentingImagePicker = false
    @State private var isPresentingLinkComposer = false
    @State private var pendingLinkTitle = ""
    @State private var pendingLinkURL = "https://"
    @State private var imageImportStatus: String?
    @State private var imageImportTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                controlBar

                GeometryReader { proxy in
                    let size = proxy.size

                    ZStack(alignment: .topLeading) {
                        PageLayoutBackgroundView(style: viewModel.currentPageLayoutStyle)

                        PencilCanvasView(
                            drawing: $viewModel.currentDrawing,
                            selectedTool: $viewModel.selectedTool,
                            onUndoStateChange: { undoManager in
                                viewModel.bindUndoManager(undoManager)
                            }
                        )
                        .id(viewModel.selectedPageIndex)

                        ForEach(viewModel.currentPageElements) { element in
                            MixedContentElementView(
                                element: element,
                                isSelected: selectedElementID == element.id,
                                onSelect: {
                                    selectedElementID = element.id
                                    viewModel.bringElementToFront(id: element.id)
                                },
                                onFrameChange: { center, newSize in
                                    viewModel.updateElementFrame(
                                        id: element.id,
                                        center: center,
                                        size: newSize,
                                        in: workspaceSize
                                    )
                                }
                            )
                        }
                    }
                    .onAppear {
                        workspaceSize = size
                    }
                    .onChange(of: size) { _, newSize in
                        workspaceSize = newSize
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .padding()
            .navigationTitle("PenFriend")
            .task {
                await viewModel.restoreIfNeeded()
            }
            .onChange(of: viewModel.selectedPageIndex) { _, _ in
                selectedElementID = nil
            }
            .onChange(of: viewModel.currentPageElements.map(\.id)) { _, _ in
                if let selectedElementID,
                   !viewModel.currentPageElements.contains(where: { $0.id == selectedElementID }) {
                    self.selectedElementID = nil
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                imageImportTask?.cancel()
                imageImportTask = Task {
                    defer { Task { @MainActor in selectedPhotoItem = nil } }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else {
                            guard !Task.isCancelled else { return }
                            await MainActor.run { imageImportStatus = "Couldn't import image." }
                            return
                        }
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            selectedElementID = viewModel.addImageElement(data: data, in: workspaceSize)
                            imageImportStatus = "Inserted image."
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        await MainActor.run { imageImportStatus = "Couldn't import image." }
                    }
                }
            }
            .onChange(of: imageImportStatus) { _, newStatus in
                if let newStatus {
                    AccessibilityNotification.Announcement(newStatus).post()
                }
            }
            .photosPicker(isPresented: $isPresentingImagePicker, selection: $selectedPhotoItem, matching: .images)
            .alert("Insert Link", isPresented: $isPresentingLinkComposer) {
                TextField("Title", text: $pendingLinkTitle)
                    .accessibilityLabel("Link title")
                TextField("URL", text: $pendingLinkURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .accessibilityLabel("Link URL")
                Button("Cancel", role: .cancel) { }
                Button("Insert") {
                    let trimmedTitle = pendingLinkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedURL = pendingLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let validatedURL = normalizedLinkString(from: trimmedURL) else {
                        imageImportStatus = "Invalid link URL."
                        return
                    }
                    selectedElementID = viewModel.addLinkElement(title: trimmedTitle, urlString: validatedURL, in: workspaceSize)
                    imageImportStatus = "Inserted link."
                    pendingLinkTitle = ""
                    pendingLinkURL = "https://"
                }
            } message: {
                Text("Add a link card to the current page.")
            }
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
            .onDisappear {
                imageImportTask?.cancel()
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

            Picker("Layout", selection: Binding(
                get: { viewModel.currentPageLayoutStyle },
                set: { viewModel.setCurrentPageLayoutStyle($0) }
            )) {
                ForEach(PageLayoutStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                Button("Text", systemImage: "text.alignleft") {
                    selectedElementID = viewModel.addTextElement(in: workspaceSize)
                }
                Button("Shape", systemImage: "square.on.circle") {
                    selectedElementID = viewModel.addShapeElement(in: workspaceSize)
                }
                Button("Link", systemImage: "link") {
                    isPresentingLinkComposer = true
                }
                Button("Image", systemImage: "photo") {
                    isPresentingImagePicker = true
                }
            } label: {
                Label("Insert", systemImage: "plus")
            }

            if let selectedElement = selectedElement {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Selected: \(selectedElement.type.rawValue.capitalized)")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        Button("Smaller") {
                            resizeSelectedElement(selectedElement, scale: 0.9)
                        }
                        Button("Larger") {
                            resizeSelectedElement(selectedElement, scale: 1.1)
                        }
                        Button("Bring to Front") {
                            viewModel.bringElementToFront(id: selectedElement.id)
                        }
                        Button("Remove", role: .destructive) {
                            viewModel.removeElement(id: selectedElement.id)
                        }
                    }

                    if selectedElement.type == .text || selectedElement.type == .shape || selectedElement.type == .link {
                        TextField(
                            "Label",
                            text: Binding(
                                get: { selectedElement.text },
                                set: { viewModel.updateElementText(id: selectedElement.id, text: $0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Selected element label")
                    }

                    if selectedElement.type == .link {
                        TextField(
                            "URL",
                            text: Binding(
                                get: { selectedElement.urlString ?? "" },
                                set: { viewModel.updateElementURL(id: selectedElement.id, urlString: $0) }
                            )
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Selected element URL")

                        if let url = linkURL(for: selectedElement) {
                            Button("Open Link") {
                                openURL(url)
                            }
                            .font(.footnote)
                        }
                    }
                }
            }

            Toggle("Use Custom Machine Learning Smoothing Model", isOn: $viewModel.useCustomSmoothingModel)
                .accessibilityHint("Uses a bundled custom model when available and falls back to interpolation when unavailable.")
                .disabled(viewModel.isSmoothing)

            Label(viewModel.storageStatus, systemImage: viewModel.storageStatusIconName)
                .font(.footnote)
                .foregroundStyle(.primary)
                .onChange(of: viewModel.storageStatus) { _, newStatus in
                    AccessibilityNotification.Announcement(newStatus).post()
                }

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
                .onChange(of: viewModel.smoothingStatus) { _, newStatus in
                    if let newStatus {
                        AccessibilityNotification.Announcement(newStatus).post()
                    }
                }

            if let imageImportStatus {
                Text(imageImportStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedElement: MixedContentElement? {
        guard let selectedElementID else { return nil }
        return viewModel.currentPageElements.first { $0.id == selectedElementID }
    }

    private func resizeSelectedElement(_ element: MixedContentElement, scale: CGFloat) {
        let resized = CGSize(
            width: element.size.width.cgFloatValue * scale,
            height: element.size.height.cgFloatValue * scale
        )
        viewModel.updateElementFrame(
            id: element.id,
            center: CGPoint(x: element.center.x.cgFloatValue, y: element.center.y.cgFloatValue),
            size: resized,
            in: workspaceSize
        )
    }

    private func normalizedLinkString(from rawURL: String) -> String? {
        guard !rawURL.isEmpty else { return nil }
        if let parsedURL = URL(string: rawURL), parsedURL.scheme != nil {
            guard let scheme = parsedURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                return nil
            }
            return rawURL
        }
        let prefixed = "https://\(rawURL)"
        guard let parsedURL = URL(string: prefixed), parsedURL.host != nil else { return nil }
        return prefixed
    }

    private func linkURL(for element: MixedContentElement) -> URL? {
        guard let rawURL = element.urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty else {
            return nil
        }
        guard let normalizedURL = normalizedLinkString(from: rawURL) else { return nil }
        return URL(string: normalizedURL)
    }
}

private struct PageLayoutBackgroundView: View {
    let style: PageLayoutStyle

    var body: some View {
        GeometryReader { proxy in
            switch style {
            case .canvas:
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            case .notebook:
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                    Path { path in
                        let spacing: CGFloat = 26
                        var y: CGFloat = 18
                        while y < proxy.size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                            y += spacing
                        }
                    }
                    .stroke(Color.blue.opacity(0.15), lineWidth: 0.6)
                }
            }
        }
    }
}

private struct MixedContentElementView: View {
    let element: MixedContentElement
    let isSelected: Bool
    let onSelect: () -> Void
    let onFrameChange: (CGPoint, CGSize) -> Void

    @State private var dragStartCenter: CGPoint?
    @State private var resizeStartSize: CGSize?
    @State private var decodedImage: UIImage?
    @State private var decodeTask: Task<Void, Never>?

    var body: some View {
        content
            .frame(width: element.size.width.cgFloatValue, height: element.size.height.cgFloatValue)
            .background(Color(.systemBackground).opacity(element.type == .shape ? 0 : 0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: isSelected ? 2 : 1)
            )
            .position(x: element.center.x.cgFloatValue, y: element.center.y.cgFloatValue)
            .shadow(radius: isSelected ? 4 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            .gesture(dragGesture)
            .simultaneousGesture(magnificationGesture)
            .onAppear {
                refreshDecodedImage()
            }
            .onChange(of: element.imageData) { _, _ in
                refreshDecodedImage()
            }
            .onDisappear {
                decodeTask?.cancel()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch element.type {
        case .text:
            Text(element.text.isEmpty ? "Text" : element.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(12)
        case .shape:
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.25))
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.8), lineWidth: 2)
                Text(element.text.isEmpty ? "Shape" : element.text)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .padding(2)
        case .link:
            VStack(alignment: .leading, spacing: 6) {
                Label(element.text.isEmpty ? "Link" : element.text, systemImage: "link")
                    .font(.subheadline.weight(.semibold))
                Text(element.urlString?.isEmpty == false ? (element.urlString ?? "") : "No URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(10)
        case .image:
            if let decodedImage {
                Image(uiImage: decodedImage)
                    .resizable()
                    .scaledToFill()
            } else if element.imageData != nil {
                ZStack {
                    Color.gray.opacity(0.12)
                    ProgressView()
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.12)
                    Label("Image unavailable", systemImage: "photo")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartCenter == nil {
                    dragStartCenter = CGPoint(x: element.center.x.cgFloatValue, y: element.center.y.cgFloatValue)
                }
                guard let dragStartCenter else { return }
                let updatedCenter = CGPoint(
                    x: dragStartCenter.x + value.translation.width,
                    y: dragStartCenter.y + value.translation.height
                )
                onFrameChange(updatedCenter, CGSize(width: element.size.width.cgFloatValue, height: element.size.height.cgFloatValue))
            }
            .onEnded { _ in
                dragStartCenter = nil
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if resizeStartSize == nil {
                    resizeStartSize = CGSize(width: element.size.width.cgFloatValue, height: element.size.height.cgFloatValue)
                }
                guard let resizeStartSize else { return }
                let updatedSize = CGSize(
                    width: resizeStartSize.width * value,
                    height: resizeStartSize.height * value
                )
                onFrameChange(CGPoint(x: element.center.x.cgFloatValue, y: element.center.y.cgFloatValue), updatedSize)
            }
            .onEnded { _ in
                resizeStartSize = nil
            }
    }

    private func refreshDecodedImage() {
        guard element.type == .image else {
            decodeTask?.cancel()
            decodedImage = nil
            return
        }
        guard let imageData = element.imageData else {
            decodeTask?.cancel()
            decodedImage = nil
            return
        }
        decodeTask?.cancel()
        decodeTask = Task {
            let image = await Task.detached(priority: .utility) {
                UIImage(data: imageData)
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run {
                decodedImage = image
            }
        }
    }
}

private extension Double {
    var cgFloatValue: CGFloat { CGFloat(self) }
}

#Preview {
    ContentView()
}
