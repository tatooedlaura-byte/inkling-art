import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct TopBarView: View {
    @Binding var canvasMode: CanvasMode
    @Binding var gridWidth: Int
    @Binding var gridHeight: Int
    @Binding var brushWidth: CGFloat
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    @Binding var templateGrid: PixelGrid?
    @Binding var referenceImage: UIImage?
    @Binding var referenceOpacity: CGFloat
    @ObservedObject var canvasStore: CanvasStore
    @ObservedObject var animationStore: AnimationStore
    @State private var showExportMenu = false
    @State private var showSaveAlert = false
    @State private var saveSuccess = false
    @State private var saveError = ""
    @State private var showSaveNameAlert = false
    @State private var projectName = ""
    @State private var showOpenPicker = false
    @State private var showSavedProjectsSheet = false
    @State private var currentProjectName = ""
    @State private var showCustomSizeAlert = false
    @State private var customWidthText = ""
    @State private var customHeightText = ""
    @State private var showCloseConfirm = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingReferenceImage: UIImage?
    @State private var showReferenceSizeSheet = false

    private let sizes = [8, 16, 32, 64]

    var body: some View {
        HStack(spacing: 16) {
            // File menu
            Menu {
                Menu("New") {
                    ForEach(sizes, id: \.self) { size in
                        Button("\(size)×\(size)") {
                            gridWidth = size
                            gridHeight = size
                            newProject()
                        }
                    }
                    Divider()
                    Button("Custom Size…") {
                        customWidthText = "\(gridWidth)"
                        customHeightText = "\(gridHeight)"
                        showCustomSizeAlert = true
                    }
                }
                Button("Save") {
                    if currentProjectName.isEmpty {
                        projectName = ""
                        showSaveNameAlert = true
                    } else {
                        projectName = currentProjectName
                        saveProject()
                    }
                }
                Button("Save As…") {
                    projectName = currentProjectName
                    showSaveNameAlert = true
                }
                Divider()
                Button("Saved Projects…") {
                    showSavedProjectsSheet = true
                }
                Button("Import…") {
                    showOpenPicker = true
                }
                Divider()
                Menu("Export PNG") {
                    ForEach([1, 4, 8, 16, 32], id: \.self) { s in
                        Button("\(s)x — \(gridWidth * s)×\(gridHeight * s)") {
                            exportPNG(scale: s)
                        }
                    }
                }
                Button("Copy to Clipboard") {
                    if let cv = canvasStore.canvasView {
                        PNGExporter.copyToClipboard(grid: cv.grid, scale: 4)
                    }
                }
                Button("Export GIF") {
                    exportGIF()
                }
                Button("Export Sprite Sheet") {
                    exportSpriteSheet()
                }
                Divider()
                Button("Close Project", role: .destructive) {
                    showCloseConfirm = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc")
                    Text("File")
                        .font(.subheadline)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }

            // Mode picker
            Picker("Mode", selection: $canvasMode) {
                Text("Pixel").tag(CanvasMode.pixel)
                Text("Smooth").tag(CanvasMode.smooth)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            // Grid size picker (pixel mode) / Brush width (smooth mode)
            if canvasMode == .pixel {
                Menu {
                    ForEach(sizes, id: \.self) { size in
                        Menu("\(size)×\(size)") {
                            Button("Blank") {
                                gridWidth = size
                                gridHeight = size
                                newProject()
                            }
                            Button("Character Template") {
                                templateGrid = CharacterTemplates.template(for: size)
                                gridWidth = size
                                gridHeight = size
                            }
                        }
                    }
                    Divider()
                    Button("Custom Size…") {
                        customWidthText = "\(gridWidth)"
                        customHeightText = "\(gridHeight)"
                        showCustomSizeAlert = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "grid")
                        Text("\(gridWidth)×\(gridHeight)")
                            .font(.subheadline.monospacedDigit())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            } else {
                // Template menu for smooth mode
                Menu {
                    Menu("Character Template") {
                        Button("Adult (Large)") {
                            referenceImage = CharacterTemplate.readerTemplate(scale: 10)
                        }
                        Button("Adult (Medium)") {
                            referenceImage = CharacterTemplate.readerTemplate(scale: 8)
                        }
                        Button("Adult (Small)") {
                            referenceImage = CharacterTemplate.readerTemplate(scale: 6)
                        }
                        Divider()
                        Button("Kid (Large)") {
                            referenceImage = CharacterTemplate.kidTemplate(scale: 8)
                        }
                        Button("Kid (Medium)") {
                            referenceImage = CharacterTemplate.kidTemplate(scale: 6)
                        }
                        Button("Kid (Small)") {
                            referenceImage = CharacterTemplate.kidTemplate(scale: 4)
                        }
                    }
                    if referenceImage != nil {
                        Divider()
                        Button("Clear Template", role: .destructive) {
                            referenceImage = nil
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: referenceImage != nil ? "person.crop.rectangle.fill" : "person.crop.rectangle")
                        Text("Template")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(referenceImage != nil ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                    .cornerRadius(8)
                }

                // Brush width for smooth mode
                HStack(spacing: 4) {
                    Image(systemName: "pencil.tip")
                        .font(.caption)
                    Slider(value: $brushWidth, in: 1...30, step: 1)
                        .frame(width: 80)
                    Text("\(Int(brushWidth))")
                        .font(.caption.monospacedDigit())
                        .frame(width: 20)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }

            // Reference image menu
            Menu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Import Reference…", systemImage: "photo")
                }
                if referenceImage != nil {
                    Divider()
                    Menu("Opacity") {
                        Button("10%") { setReferenceOpacity(0.1) }
                        Button("20%") { setReferenceOpacity(0.2) }
                        Button("30%") { setReferenceOpacity(0.3) }
                        Button("40%") { setReferenceOpacity(0.4) }
                        Button("50%") { setReferenceOpacity(0.5) }
                    }
                    Divider()
                    Button(role: .destructive) {
                        referenceImage = nil
                        canvasStore.canvasView?.referenceImage = nil
                        canvasStore.canvasView?.setNeedsDisplay()
                    } label: {
                        Label("Remove Reference", systemImage: "trash")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: referenceImage != nil ? "photo.fill" : "photo")
                    Text("Ref")
                        .font(.subheadline)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(referenceImage != nil ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                .cornerRadius(8)
            }

            Spacer()

            // Project name
            Text(currentProjectName.isEmpty ? "Untitled" : currentProjectName)
                .font(.headline)
                .foregroundColor(currentProjectName.isEmpty ? .secondary : .primary)

            Spacer()

            // Zoom
            Button {
                if canvasMode == .pixel {
                    canvasStore.canvasView?.zoomOut()
                } else {
                    canvasStore.smoothCanvasView?.zoomOut()
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.title3)
            }

            Button {
                if canvasMode == .pixel {
                    canvasStore.canvasView?.zoomIn()
                } else {
                    canvasStore.smoothCanvasView?.zoomIn()
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.title3)
            }

            Button {
                if canvasMode == .pixel {
                    canvasStore.canvasView?.resetZoom()
                } else {
                    canvasStore.smoothCanvasView?.resetZoom()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise.magnifyingglass")
                    .font(.title3)
            }

            Divider()
                .frame(height: 20)

            // Undo / Redo
            Button {
                undoTrigger += 1
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }

            Button {
                redoTrigger += 1
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.title3)
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .alert(saveSuccess ? "Saved!" : "Save Failed", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveSuccess ? "Image saved to Photos." : saveError.isEmpty ? "Unknown error" : saveError)
        }
        .alert("Save Project", isPresented: $showSaveNameAlert) {
            TextField("Project name", text: $projectName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveProject()
            }
        } message: {
            Text("Enter a name for your project.")
        }
        .sheet(isPresented: $showOpenPicker) {
            DocumentPicker { url in
                openProject(url: url)
            }
        }
        .sheet(isPresented: $showSavedProjectsSheet) {
            SavedProjectsView { url in
                showSavedProjectsSheet = false
                openProject(url: url)
            }
        }
        .alert("Custom Size", isPresented: $showCustomSizeAlert) {
            TextField("Width", text: $customWidthText)
                .keyboardType(.numberPad)
            TextField("Height", text: $customHeightText)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let w = Int(customWidthText) ?? gridWidth
                let h = Int(customHeightText) ?? gridHeight
                let clampedW = max(4, min(w, 512))
                let clampedH = max(4, min(h, 512))
                gridWidth = clampedW
                gridHeight = clampedH
                newProject()
            }
        } message: {
            Text("Enter width and height (4–512).")
        }
        .alert("Close Project?", isPresented: $showCloseConfirm) {
            Button("Save & Close") {
                if currentProjectName.isEmpty {
                    projectName = ""
                    showSaveNameAlert = true
                } else {
                    projectName = currentProjectName
                    saveProject()
                }
                closeProject()
            }
            Button("Close Without Saving", role: .destructive) {
                closeProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save before closing?")
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pendingReferenceImage = image
                    showReferenceSizeSheet = true
                }
            }
        }
        .sheet(isPresented: $showReferenceSizeSheet) {
            ReferenceSizePickerView(
                image: pendingReferenceImage,
                onSelect: { width, height in
                    showReferenceSizeSheet = false
                    guard let image = pendingReferenceImage else { return }

                    // Update grid size
                    gridWidth = width
                    gridHeight = height
                    animationStore.initialize(width: width, height: height)
                    if let cv = canvasStore.canvasView {
                        cv.changeGridSize(width: width, height: height)
                        animationStore.loadFrameToCanvas(cv, index: 0)
                    }

                    // Apply reference image
                    referenceImage = image
                    canvasStore.canvasView?.referenceImage = image
                    canvasStore.canvasView?.referenceOpacity = referenceOpacity
                    canvasStore.canvasView?.setNeedsDisplay()
                    pendingReferenceImage = nil
                },
                onCancel: {
                    showReferenceSizeSheet = false
                    pendingReferenceImage = nil
                }
            )
        }
    }

    private func setReferenceOpacity(_ opacity: Double) {
        referenceOpacity = opacity
        canvasStore.canvasView?.referenceOpacity = opacity
        canvasStore.canvasView?.setNeedsDisplay()
    }

    private func closeProject() {
        currentProjectName = ""
        gridWidth = 16
        gridHeight = 16
        referenceImage = nil
        animationStore.initialize(width: gridWidth, height: gridHeight)
        if let cv = canvasStore.canvasView {
            cv.referenceImage = nil
            cv.changeGridSize(width: gridWidth, height: gridHeight)
            animationStore.loadFrameToCanvas(cv, index: 0)
        }
    }

    private func newProject() {
        currentProjectName = ""
        referenceImage = nil
        animationStore.initialize(width: gridWidth, height: gridHeight)
        if let cv = canvasStore.canvasView {
            cv.referenceImage = nil
            cv.changeGridSize(width: gridWidth, height: gridHeight)
            animationStore.loadFrameToCanvas(cv, index: 0)
        }
    }

    private func saveProject() {
        let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let data = ProjectData.from(animationStore: animationStore, canvas: canvasStore.canvasView)
        do {
            _ = try ProjectFileManager.save(data: data, name: name)
            currentProjectName = name
        } catch {
            saveError = error.localizedDescription
            saveSuccess = false
            showSaveAlert = true
        }
    }

    private func openProject(url: URL) {
        do {
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
            let data = try ProjectFileManager.load(url: url)
            currentProjectName = url.deletingPathExtension().lastPathComponent
            gridWidth = data.gridWidth
            gridHeight = data.gridHeight
            if let cv = canvasStore.canvasView {
                cv.changeGridSize(width: data.gridWidth, height: data.gridHeight)
            }
            data.restore(to: animationStore, canvas: canvasStore.canvasView)
        } catch {
            saveError = error.localizedDescription
            saveSuccess = false
            showSaveAlert = true
        }
    }

    private func exportGIF() {
        if let cv = canvasStore.canvasView {
            animationStore.syncCurrentFrameFromCanvas(cv)
        }
        let grids = animationStore.frames.map { $0.grid }
        GIFExporter.saveToPhotos(frames: grids, fps: animationStore.fps, scale: 4) { success, error in
            saveError = error ?? ""
            saveSuccess = success
            showSaveAlert = true
        }
    }

    private func exportSpriteSheet() {
        if let cv = canvasStore.canvasView {
            animationStore.syncCurrentFrameFromCanvas(cv)
        }
        let grids = animationStore.frames.map { $0.grid }
        SpriteSheetExporter.saveToPhotos(frames: grids, scale: 4) { success, error in
            saveError = error ?? ""
            saveSuccess = success
            showSaveAlert = true
        }
    }

    private func exportPNG(scale: Int) {
        guard let cv = canvasStore.canvasView else {
            saveError = "No canvas found"
            saveSuccess = false
            showSaveAlert = true
            return
        }
        PNGExporter.saveToPhotos(grid: cv.grid, scale: scale) { success, error in
            saveError = error ?? ""
            saveSuccess = success
            showSaveAlert = true
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "pxl") ?? .json])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct SavedProjectsView: View {
    let onOpen: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var projects: [ProjectFileManager.ProjectInfo] = []

    var body: some View {
        NavigationView {
            Group {
                if projects.isEmpty {
                    Text("No saved projects")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(projects) { project in
                            Button {
                                onOpen(project.url)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(project.name)
                                        .font(.body)
                                    Text(project.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                ProjectFileManager.deleteProject(url: projects[i].url)
                            }
                            projects = ProjectFileManager.listProjects()
                        }
                    }
                }
            }
            .navigationTitle("Saved Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            projects = ProjectFileManager.listProjects()
        }
    }
}

struct ReferenceSizePickerView: View {
    let image: UIImage?
    let onSelect: (Int, Int) -> Void
    let onCancel: () -> Void

    private var aspectRatio: CGFloat {
        guard let image = image else { return 1.0 }
        return image.size.width / image.size.height
    }

    private var sizeOptions: [(width: Int, height: Int, label: String)] {
        let baseSizes = [16, 32, 48, 64, 96, 128]
        var options: [(Int, Int, String)] = []

        for base in baseSizes {
            let width: Int
            let height: Int

            if aspectRatio >= 1.0 {
                // Landscape or square
                width = base
                height = max(4, Int(round(CGFloat(base) / aspectRatio)))
            } else {
                // Portrait
                height = base
                width = max(4, Int(round(CGFloat(base) * aspectRatio)))
            }

            options.append((width, height, "\(width) × \(height)"))
        }

        return options
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                        .padding()
                }

                Text("Choose Canvas Size")
                    .font(.headline)

                Text("Sizes matched to image aspect ratio")
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(sizeOptions, id: \.label) { option in
                        Button {
                            onSelect(option.width, option.height)
                        } label: {
                            Text(option.label)
                                .font(.body.monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Reference Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}
