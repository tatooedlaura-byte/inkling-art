import SwiftUI

struct ContentView: View {
    @State private var currentTool: Tool = .pencil
    @State private var currentColor: UIColor = .black
    @State private var gridWidth: Int = 16
    @State private var gridHeight: Int = 16
    @State private var undoTrigger: Int = 0
    @State private var redoTrigger: Int = 0
    @State private var selectedPaletteIndex: Int = 0
    @State private var templateGrid: PixelGrid?
    @StateObject private var canvasStore = CanvasStore()
    @StateObject private var animationStore = AnimationStore()

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(
                gridWidth: $gridWidth,
                gridHeight: $gridHeight,
                undoTrigger: $undoTrigger,
                redoTrigger: $redoTrigger,
                templateGrid: $templateGrid,
                canvasStore: canvasStore,
                animationStore: animationStore
            )

            ZStack(alignment: .leading) {
                // Canvas
                CanvasView(
                    currentColor: $currentColor,
                    currentTool: $currentTool,
                    gridWidth: $gridWidth,
                    gridHeight: $gridHeight,
                    undoTrigger: $undoTrigger,
                    redoTrigger: $redoTrigger,
                    templateGrid: $templateGrid,
                    onPickColor: { color in
                        currentColor = color
                        currentTool = .pencil
                    },
                    canvasStore: canvasStore,
                    animationStore: animationStore
                )
                .background(Color(.systemGray6))

                // Floating toolbar on the left
                ToolbarView(selectedTool: $currentTool)
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
            animationStore.initialize(width: gridWidth, height: gridHeight)
        }
        .ignoresSafeArea(.keyboard)
    }
}
