import SwiftUI

struct CanvasView: UIViewRepresentable {
    @Binding var currentColor: UIColor
    @Binding var currentTool: Tool
    @Binding var gridSize: Int
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    @Binding var templateGrid: PixelGrid?
    var onPickColor: (UIColor) -> Void
    var canvasStore: CanvasStore
    var animationStore: AnimationStore

    func makeUIView(context: Context) -> PixelCanvasUIView {
        let view = PixelCanvasUIView(gridSize: gridSize)
        view.delegate = context.coordinator
        view.currentColor = currentColor
        view.currentTool = currentTool
        DispatchQueue.main.async {
            canvasStore.canvasView = view
        }
        return view
    }

    func updateUIView(_ uiView: PixelCanvasUIView, context: Context) {
        uiView.currentColor = currentColor
        uiView.currentTool = currentTool
        uiView.onionSkinGrid = animationStore.previousFrameGrid

        if context.coordinator.lastUndoTrigger != undoTrigger {
            context.coordinator.lastUndoTrigger = undoTrigger
            uiView.performUndo()
        }
        if context.coordinator.lastRedoTrigger != redoTrigger {
            context.coordinator.lastRedoTrigger = redoTrigger
            uiView.performRedo()
        }
        if let template = templateGrid {
            DispatchQueue.main.async { templateGrid = nil }
            uiView.loadGrid(template)
            context.coordinator.lastGridSize = template.width
        } else if context.coordinator.lastGridSize != gridSize {
            context.coordinator.lastGridSize = gridSize
            uiView.changeGridSize(gridSize)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPickColor: onPickColor, animationStore: animationStore)
    }

    class Coordinator: NSObject, PixelCanvasDelegate {
        var lastUndoTrigger = 0
        var lastRedoTrigger = 0
        var lastGridSize = 16
        var onPickColor: (UIColor) -> Void
        var animationStore: AnimationStore

        init(onPickColor: @escaping (UIColor) -> Void, animationStore: AnimationStore) {
            self.onPickColor = onPickColor
            self.animationStore = animationStore
        }

        func canvasDidPickColor(_ color: UIColor) {
            onPickColor(color)
        }

        func canvasDidChange() {
            // Keep current frame in sync when canvas changes
        }
    }
}
