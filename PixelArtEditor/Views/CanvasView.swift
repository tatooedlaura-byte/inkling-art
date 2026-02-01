import SwiftUI

struct CanvasView: UIViewRepresentable {
    @Binding var currentColor: UIColor
    @Binding var currentTool: Tool
    @Binding var gridSize: Int
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    var onPickColor: (UIColor) -> Void
    var onCanvasReady: (PixelCanvasUIView) -> Void

    func makeUIView(context: Context) -> PixelCanvasUIView {
        let view = PixelCanvasUIView(gridSize: gridSize)
        view.delegate = context.coordinator
        view.currentColor = currentColor
        view.currentTool = currentTool
        onCanvasReady(view)
        return view
    }

    func updateUIView(_ uiView: PixelCanvasUIView, context: Context) {
        uiView.currentColor = currentColor
        uiView.currentTool = currentTool

        if context.coordinator.lastUndoTrigger != undoTrigger {
            context.coordinator.lastUndoTrigger = undoTrigger
            uiView.performUndo()
        }
        if context.coordinator.lastRedoTrigger != redoTrigger {
            context.coordinator.lastRedoTrigger = redoTrigger
            uiView.performRedo()
        }
        if context.coordinator.lastGridSize != gridSize {
            context.coordinator.lastGridSize = gridSize
            uiView.changeGridSize(gridSize)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPickColor: onPickColor)
    }

    class Coordinator: NSObject, PixelCanvasDelegate {
        var lastUndoTrigger = 0
        var lastRedoTrigger = 0
        var lastGridSize = 16
        var onPickColor: (UIColor) -> Void

        init(onPickColor: @escaping (UIColor) -> Void) {
            self.onPickColor = onPickColor
        }

        func canvasDidPickColor(_ color: UIColor) {
            onPickColor(color)
        }

        func canvasDidChange() {}
    }
}
