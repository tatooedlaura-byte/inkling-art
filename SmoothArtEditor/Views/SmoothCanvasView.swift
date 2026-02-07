import SwiftUI
import PencilKit

struct SmoothCanvasView: UIViewRepresentable {
    @Binding var currentColor: UIColor
    @Binding var currentTool: Tool
    @Binding var currentShapeKind: ShapeKind
    @Binding var shapeFilled: Bool
    @Binding var brushWidth: CGFloat
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    @Binding var referenceImage: UIImage?
    @Binding var referenceOpacity: CGFloat
    var canvasStore: CanvasStore
    var animationStore: AnimationStore
    var onPickColor: ((UIColor) -> Void)?

    func makeUIView(context: Context) -> SmoothCanvasUIView {
        let view = SmoothCanvasUIView(frame: .zero)
        view.delegate = context.coordinator
        view.currentColor = currentColor
        view.currentTool = currentTool
        view.currentShapeKind = currentShapeKind
        view.shapeFilled = shapeFilled
        view.brushWidth = brushWidth
        view.referenceImage = referenceImage
        view.referenceOpacity = referenceOpacity

        DispatchQueue.main.async {
            canvasStore.canvasView = view
            if let frame = animationStore.currentFrame {
                view.drawing = frame.canvas.drawing
            }
        }
        return view
    }

    func updateUIView(_ uiView: SmoothCanvasUIView, context: Context) {
        uiView.currentColor = currentColor
        uiView.currentTool = currentTool
        uiView.currentShapeKind = currentShapeKind
        uiView.shapeFilled = shapeFilled
        uiView.brushWidth = brushWidth
        uiView.referenceImage = referenceImage
        uiView.referenceOpacity = referenceOpacity
        context.coordinator.onPickColor = onPickColor

        if context.coordinator.lastUndoTrigger != undoTrigger {
            context.coordinator.lastUndoTrigger = undoTrigger
            uiView.performUndo()
        }
        if context.coordinator.lastRedoTrigger != redoTrigger {
            context.coordinator.lastRedoTrigger = redoTrigger
            uiView.performRedo()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(animationStore: animationStore, onPickColor: onPickColor)
    }

    class Coordinator: NSObject, SmoothCanvasDelegate {
        var lastUndoTrigger = 0
        var lastRedoTrigger = 0
        var animationStore: AnimationStore
        var onPickColor: ((UIColor) -> Void)?

        init(animationStore: AnimationStore, onPickColor: ((UIColor) -> Void)?) {
            self.animationStore = animationStore
            self.onPickColor = onPickColor
        }

        func canvasDidChange() {
            // Canvas changed
        }

        func didPickColor(_ color: UIColor) {
            onPickColor?(color)
        }
    }
}
