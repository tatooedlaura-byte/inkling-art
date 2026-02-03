import SwiftUI
import UniformTypeIdentifiers

struct TopBarView: View {
    @Binding var gridWidth: Int
    @Binding var gridHeight: Int
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    @Binding var templateGrid: PixelGrid?
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

            // Grid size picker
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

            Spacer()

            // Zoom
            Button {
                canvasStore.canvasView?.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.title3)
            }

            Button {
                canvasStore.canvasView?.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.title3)
            }

            Button {
                canvasStore.canvasView?.resetZoom()
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
                let clampedW = max(4, min(w, 128))
                let clampedH = max(4, min(h, 128))
                gridWidth = clampedW
                gridHeight = clampedH
                newProject()
            }
        } message: {
            Text("Enter width and height (4–128).")
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
    }

    private func closeProject() {
        currentProjectName = ""
        gridWidth = 16
        gridHeight = 16
        animationStore.initialize(width: gridWidth, height: gridHeight)
        if let cv = canvasStore.canvasView {
            cv.changeGridSize(width: gridWidth, height: gridHeight)
            animationStore.loadFrameToCanvas(cv, index: 0)
        }
    }

    private func newProject() {
        currentProjectName = ""
        animationStore.initialize(width: gridWidth, height: gridHeight)
        if let cv = canvasStore.canvasView {
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
