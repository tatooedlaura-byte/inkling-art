import SwiftUI
import UniformTypeIdentifiers

struct TopBarView: View {
    @Binding var gridSize: Int
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
    @State private var savedProjects: [ProjectFileManager.ProjectInfo] = []

    private let sizes = [8, 16, 32, 64]

    var body: some View {
        HStack(spacing: 16) {
            // File menu
            Menu {
                Button("New") {
                    newProject()
                }
                Button("Save…") {
                    projectName = ""
                    showSaveNameAlert = true
                }
                Divider()
                if !savedProjects.isEmpty {
                    ForEach(savedProjects) { project in
                        Button(project.name) {
                            openProject(url: project.url)
                        }
                    }
                    Divider()
                }
                Button("Open File…") {
                    showOpenPicker = true
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
            .onAppear {
                savedProjects = ProjectFileManager.listProjects()
            }

            // Grid size picker
            Menu {
                ForEach(sizes, id: \.self) { size in
                    Menu("\(size)×\(size)") {
                        Button("Blank") {
                            gridSize = size
                        }
                        Button("Character Template") {
                            templateGrid = CharacterTemplates.template(for: size)
                            gridSize = size
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "grid")
                    Text("\(gridSize)×\(gridSize)")
                        .font(.subheadline.monospacedDigit())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }

            Spacer()

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

            // Export
            Menu {
                ForEach([1, 4, 8, 16, 32], id: \.self) { s in
                    Button("Save PNG (\(s)x — \(gridSize * s)×\(gridSize * s))") {
                        exportPNG(scale: s)
                    }
                }
                Button("Copy to Clipboard") {
                    if let cv = canvasStore.canvasView {
                        PNGExporter.copyToClipboard(grid: cv.grid, scale: 4)
                    }
                }
                Divider()
                Button("Export GIF") {
                    exportGIF()
                }
                Button("Export Sprite Sheet") {
                    exportSpriteSheet()
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
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
    }

    private func newProject() {
        animationStore.initialize(gridSize: gridSize)
        if let cv = canvasStore.canvasView {
            cv.changeGridSize(gridSize)
            animationStore.loadFrameToCanvas(cv, index: 0)
        }
    }

    private func saveProject() {
        let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let data = ProjectData.from(animationStore: animationStore, canvas: canvasStore.canvasView)
        do {
            _ = try ProjectFileManager.save(data: data, name: name)
            savedProjects = ProjectFileManager.listProjects()
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
            gridSize = data.gridWidth
            if let cv = canvasStore.canvasView {
                cv.changeGridSize(data.gridWidth)
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
