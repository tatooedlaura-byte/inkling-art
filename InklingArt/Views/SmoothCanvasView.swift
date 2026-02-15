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
    var shapeRecognitionEnabled: Bool
    @Binding var showGridOverlay: Bool
    @Binding var mirrorModeEnabled: Bool
    var canvasStore: CanvasStore
    var animationStore: AnimationStore
    var layers: [DrawingLayer]
    var activeLayerIndex: Int
    var onPickColor: ((UIColor) -> Void)?
    var onCanvasChanged: (() -> Void)?

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
        view.shapeRecognitionEnabled = shapeRecognitionEnabled
        view.showGridOverlay = showGridOverlay
        view.mirrorModeEnabled = mirrorModeEnabled

        if activeLayerIndex < layers.count {
            view.drawing = layers[activeLayerIndex].drawing
        }

        context.coordinator.layers = layers
        context.coordinator.activeLayerIndex = activeLayerIndex
        context.coordinator.onCanvasChanged = onCanvasChanged

        DispatchQueue.main.async {
            canvasStore.smoothCanvasView = view
            view.updateLayerComposites(layers: layers, activeIndex: activeLayerIndex)
        }
        return view
    }

    func updateUIView(_ uiView: SmoothCanvasUIView, context: Context) {
        print("🔄 SmoothCanvasView.updateUIView called with shapeRecognitionEnabled=\(shapeRecognitionEnabled)")
        uiView.currentColor = currentColor
        uiView.currentTool = currentTool
        uiView.currentShapeKind = currentShapeKind
        uiView.shapeFilled = shapeFilled
        uiView.brushWidth = brushWidth
        uiView.referenceImage = referenceImage
        uiView.referenceOpacity = referenceOpacity
        uiView.shapeRecognitionEnabled = shapeRecognitionEnabled
        uiView.showGridOverlay = showGridOverlay
        uiView.mirrorModeEnabled = mirrorModeEnabled
        print("✅ Set uiView.shapeRecognitionEnabled to \(uiView.shapeRecognitionEnabled)")
        context.coordinator.onPickColor = onPickColor
        context.coordinator.onCanvasChanged = onCanvasChanged

        // Layer switch detection
        let prevIndex = context.coordinator.activeLayerIndex
        let prevLayers = context.coordinator.layers

        if prevIndex != activeLayerIndex || !layerIDsMatch(prevLayers, layers) {
            // Save current drawing back to previous layer
            if prevIndex < prevLayers.count {
                prevLayers[prevIndex].drawing = uiView.drawing
            }
            // Load new active layer
            if activeLayerIndex < layers.count {
                uiView.drawing = layers[activeLayerIndex].drawing
                uiView.clearUndoHistory()
            }
        }

        context.coordinator.layers = layers
        context.coordinator.activeLayerIndex = activeLayerIndex

        // Update layer composites
        uiView.updateLayerComposites(layers: layers, activeIndex: activeLayerIndex)

        if context.coordinator.lastUndoTrigger != undoTrigger {
            context.coordinator.lastUndoTrigger = undoTrigger
            uiView.performUndo()
        }
        if context.coordinator.lastRedoTrigger != redoTrigger {
            context.coordinator.lastRedoTrigger = redoTrigger
            uiView.performRedo()
        }
    }

    private func layerIDsMatch(_ a: [DrawingLayer], _ b: [DrawingLayer]) -> Bool {
        guard a.count == b.count else { return false }
        for i in a.indices {
            if a[i].id != b[i].id { return false }
        }
        return true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(animationStore: animationStore, onPickColor: onPickColor)
    }

    class Coordinator: NSObject, SmoothCanvasDelegate {
        var lastUndoTrigger = 0
        var lastRedoTrigger = 0
        var animationStore: AnimationStore
        var onPickColor: ((UIColor) -> Void)?
        var onCanvasChanged: (() -> Void)?
        var layers: [DrawingLayer] = []
        var activeLayerIndex: Int = 0

        init(animationStore: AnimationStore, onPickColor: ((UIColor) -> Void)?) {
            self.animationStore = animationStore
            self.onPickColor = onPickColor
        }

        func canvasDidChange() {
            onCanvasChanged?()
        }

        func didPickColor(_ color: UIColor) {
            onPickColor?(color)
        }
    }
}
