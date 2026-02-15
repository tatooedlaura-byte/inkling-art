import SwiftUI

struct DotArtCanvasView: UIViewRepresentable {
    @Binding var currentColor: UIColor
    @Binding var currentTool: Tool
    @Binding var gridSnapEnabled: Bool
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    var canvasStore: CanvasStore
    var onPickColor: ((UIColor) -> Void)?

    func makeUIView(context: Context) -> DotArtCanvasUIView {
        let view = DotArtCanvasUIView(frame: .zero)
        view.delegate = context.coordinator
        view.currentColor = currentColor
        view.currentTool = currentTool
        view.gridSnapEnabled = gridSnapEnabled

        DispatchQueue.main.async {
            canvasStore.dotArtCanvasView = view
        }

        return view
    }

    func updateUIView(_ uiView: DotArtCanvasUIView, context: Context) {
        uiView.currentColor = currentColor
        uiView.currentTool = currentTool
        uiView.gridSnapEnabled = gridSnapEnabled
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
        Coordinator(onPickColor: onPickColor)
    }

    class Coordinator: NSObject, DotArtCanvasDelegate {
        var lastUndoTrigger = 0
        var lastRedoTrigger = 0
        var onPickColor: ((UIColor) -> Void)?

        init(onPickColor: ((UIColor) -> Void)?) {
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
