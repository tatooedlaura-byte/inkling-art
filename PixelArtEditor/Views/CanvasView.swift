import SwiftUI

struct CanvasView: UIViewRepresentable {
    @Binding var currentColor: UIColor
    @Binding var currentTool: Tool
    @Binding var currentShapeKind: ShapeKind
    @Binding var shapeFilled: Bool
    @Binding var gridWidth: Int
    @Binding var gridHeight: Int
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    @Binding var templateGrid: PixelGrid?
    var onPickColor: (UIColor) -> Void
    var canvasStore: CanvasStore
    var animationStore: AnimationStore

    func makeUIView(context: Context) -> PixelCanvasUIView {
        let view = PixelCanvasUIView(gridWidth: gridWidth, gridHeight: gridHeight)
        view.delegate = context.coordinator
        view.currentColor = currentColor
        view.currentTool = currentTool
        view.currentShapeKind = currentShapeKind
        view.shapeFilled = shapeFilled
        DispatchQueue.main.async {
            canvasStore.canvasView = view
        }
        return view
    }

    func updateUIView(_ uiView: PixelCanvasUIView, context: Context) {
        uiView.currentColor = currentColor
        uiView.currentTool = currentTool
        uiView.currentShapeKind = currentShapeKind
        uiView.shapeFilled = shapeFilled
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
            context.coordinator.lastGridWidth = template.width
            context.coordinator.lastGridHeight = template.height
        } else if context.coordinator.lastGridWidth != gridWidth || context.coordinator.lastGridHeight != gridHeight {
            context.coordinator.lastGridWidth = gridWidth
            context.coordinator.lastGridHeight = gridHeight
            uiView.changeGridSize(width: gridWidth, height: gridHeight)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPickColor: onPickColor, animationStore: animationStore)
    }

    class Coordinator: NSObject, PixelCanvasDelegate {
        var lastUndoTrigger = 0
        var lastRedoTrigger = 0
        var lastGridWidth = 16
        var lastGridHeight = 16
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
