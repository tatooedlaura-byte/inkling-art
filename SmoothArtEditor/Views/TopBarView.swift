import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct TopBarView: View {
    @Binding var brushWidth: CGFloat
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    @Binding var referenceImage: UIImage?
    @Binding var referenceOpacity: CGFloat
    @Binding var projectName: String
    @ObservedObject var canvasStore: CanvasStore
    @ObservedObject var animationStore: AnimationStore

    @State private var showSaveAlert = false
    @State private var saveSuccess = false
    @State private var saveError = ""
    @State private var showSaveNameAlert = false
    @State private var saveName = ""
    @State private var showSavedProjectsSheet = false
    @State private var showOpenPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCloseConfirm = false

    var body: some View {
        HStack(spacing: 16) {
            // File menu
            Menu {
                Button("New") {
                    newProject()
                }
                Button("Save…") {
                    saveName = projectName.isEmpty ? "" : projectName
                    showSaveNameAlert = true
                }
                if !projectName.isEmpty {
                    Button("Quick Save") {
                        quickSave()
                    }
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
                    ForEach([1, 2, 4], id: \.self) { scale in
                        Button("\(scale)x Scale") {
                            exportPNG(scale: CGFloat(scale))
                        }
                    }
                }
                Button("Copy to Clipboard") {
                    if let cv = canvasStore.canvasView,
                       let image = cv.renderImage(scale: 2.0) {
                        UIPasteboard.general.image = image
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

            // Project name
            if !projectName.isEmpty {
                Text(projectName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Reference image / Templates
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
                Divider()
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose Image…", systemImage: "photo")
                }
                if referenceImage != nil {
                    Divider()
                    Menu("Opacity") {
                        Button("20%") { referenceOpacity = 0.2 }
                        Button("30%") { referenceOpacity = 0.3 }
                        Button("40%") { referenceOpacity = 0.4 }
                        Button("50%") { referenceOpacity = 0.5 }
                        Button("60%") { referenceOpacity = 0.6 }
                    }
                    Divider()
                    Button("Remove Reference", role: .destructive) {
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
            .onChange(of: selectedPhotoItem) { item in
                loadReferenceImage(from: item)
            }

            // Brush width
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

            // Zoom controls
            HStack(spacing: 4) {
                Button {
                    canvasStore.canvasView?.zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                Button {
                    canvasStore.canvasView?.resetZoom()
                } label: {
                    Image(systemName: "1.magnifyingglass")
                }
                Button {
                    canvasStore.canvasView?.zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .alert(saveSuccess ? "Saved!" : "Save Failed", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveSuccess ? "Saved successfully." : saveError.isEmpty ? "Unknown error" : saveError)
        }
        .alert("Save Project", isPresented: $showSaveNameAlert) {
            TextField("Project name", text: $saveName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveProject()
            }
        }
        .alert("Close Project?", isPresented: $showCloseConfirm) {
            Button("Save & Close") {
                if projectName.isEmpty {
                    saveName = ""
                    showSaveNameAlert = true
                } else {
                    saveName = projectName
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
    }

    private func loadReferenceImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        item.loadTransferable(type: Data.self) { result in
            if case .success(let data) = result, let data = data,
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    referenceImage = image
                }
            }
        }
    }

    private func newProject() {
        animationStore.initialize()
        if let cv = canvasStore.canvasView {
            cv.clearCanvas()
            animationStore.loadFrameToCanvas(cv, index: 0)
        }
        projectName = ""
        referenceImage = nil
    }

    private func closeProject() {
        animationStore.initialize()
        if let cv = canvasStore.canvasView {
            cv.clearCanvas()
            animationStore.loadFrameToCanvas(cv, index: 0)
        }
        projectName = ""
        referenceImage = nil
    }

    private func saveProject() {
        let name = saveName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let canvasSize = CGSize(width: 1024, height: 1024)
        let data = ProjectData.from(animationStore: animationStore, canvas: canvasStore.canvasView, canvasSize: canvasSize)

        do {
            _ = try ProjectFileManager.save(data: data, name: name)
            projectName = name
        } catch {
            saveError = error.localizedDescription
            saveSuccess = false
            showSaveAlert = true
        }
    }

    private func quickSave() {
        guard !projectName.isEmpty else { return }
        saveName = projectName
        saveProject()
    }

    private func openProject(url: URL) {
        do {
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
            let data = try ProjectFileManager.load(url: url)
            data.restore(to: animationStore, canvas: canvasStore.canvasView)
            projectName = url.deletingPathExtension().lastPathComponent
        } catch {
            saveError = error.localizedDescription
            saveSuccess = false
            showSaveAlert = true
        }
    }

    private func exportPNG(scale: CGFloat) {
        guard let cv = canvasStore.canvasView,
              let image = cv.renderImage(scale: scale) else {
            saveError = "Failed to render image"
            saveSuccess = false
            showSaveAlert = true
            return
        }

        PNGExporter.saveToPhotos(image: image) { success, error in
            saveError = error ?? ""
            saveSuccess = success
            showSaveAlert = true
        }
    }

    private func exportGIF() {
        if let cv = canvasStore.canvasView {
            animationStore.syncCurrentFrameFromCanvas(cv)
        }

        let images: [UIImage] = animationStore.frames.compactMap { frame in
            frame.canvas.render(size: CGSize(width: 512, height: 512), scale: 1.0)
        }

        GIFExporter.saveToPhotos(images: images, fps: animationStore.fps) { success, error in
            saveError = error ?? ""
            saveSuccess = success
            showSaveAlert = true
        }
    }

    private func exportSpriteSheet() {
        if let cv = canvasStore.canvasView {
            animationStore.syncCurrentFrameFromCanvas(cv)
        }

        let images: [UIImage] = animationStore.frames.compactMap { frame in
            frame.canvas.render(size: CGSize(width: 256, height: 256), scale: 1.0)
        }

        SpriteSheetExporter.saveToPhotos(images: images) { success, error in
            saveError = error ?? ""
            saveSuccess = success
            showSaveAlert = true
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "sart") ?? .json])
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
