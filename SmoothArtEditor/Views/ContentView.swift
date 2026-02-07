import SwiftUI

struct ContentView: View {
    @State private var currentTool: Tool = .pencil
    @State private var currentShapeKind: ShapeKind = .line
    @State private var shapeFilled: Bool = false
    @State private var currentColor: UIColor = .black
    @State private var brushWidth: CGFloat = 5.0
    @State private var undoTrigger: Int = 0
    @State private var redoTrigger: Int = 0
    @State private var selectedPaletteIndex: Int = 0
    @State private var referenceImage: UIImage?
    @State private var referenceOpacity: CGFloat = 0.3
    @State private var projectName: String = ""
    @StateObject private var canvasStore = CanvasStore()
    @StateObject private var animationStore = AnimationStore()

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(
                brushWidth: $brushWidth,
                undoTrigger: $undoTrigger,
                redoTrigger: $redoTrigger,
                referenceImage: $referenceImage,
                referenceOpacity: $referenceOpacity,
                projectName: $projectName,
                canvasStore: canvasStore,
                animationStore: animationStore
            )

            ZStack(alignment: .leading) {
                // Canvas
                SmoothCanvasView(
                    currentColor: $currentColor,
                    currentTool: $currentTool,
                    currentShapeKind: $currentShapeKind,
                    shapeFilled: $shapeFilled,
                    brushWidth: $brushWidth,
                    undoTrigger: $undoTrigger,
                    redoTrigger: $redoTrigger,
                    referenceImage: $referenceImage,
                    referenceOpacity: $referenceOpacity,
                    canvasStore: canvasStore,
                    animationStore: animationStore,
                    onPickColor: { color in
                        currentColor = color
                        currentTool = .pencil
                    }
                )
                .background(Color(.systemGray6))

                // Floating toolbar
                ToolbarView(
                    selectedTool: $currentTool,
                    selectedShapeKind: $currentShapeKind,
                    shapeFilled: $shapeFilled
                )
                .padding(.leading, 12)
            }

            FrameTimelineView(
                animationStore: animationStore,
                canvasStore: canvasStore
            )

            ColorPaletteView(
                selectedColor: $currentColor,
                selectedPaletteIndex: $selectedPaletteIndex
            )
        }
        .onAppear {
            animationStore.initialize()
        }
        .ignoresSafeArea(.keyboard)
    }
}
