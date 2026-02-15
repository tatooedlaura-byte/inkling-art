import SwiftUI

struct ContentView: View {
    @State private var canvasMode: CanvasMode = .pixel
    @State private var currentTool: Tool = .pencil
    @State private var currentColor: UIColor = .black
    @State private var gridWidth: Int = 16
    @State private var gridHeight: Int = 16
    @State private var undoTrigger: Int = 0
    @State private var redoTrigger: Int = 0
    @State private var selectedPaletteIndex: Int = 0
    @State private var currentShapeKind: ShapeKind = .line
    @State private var shapeFilled: Bool = false
    @State private var templateGrid: PixelGrid?
    @State private var brushWidth: CGFloat = 5.0
    @State private var referenceImage: UIImage?
    @State private var referenceOpacity: CGFloat = 0.3
    @StateObject private var canvasStore = CanvasStore()
    @StateObject private var animationStore = AnimationStore()
    @State private var layers: [DrawingLayer] = [DrawingLayer(name: "Layer 1")]
    @State private var activeLayerIndex: Int = 0
    @State private var showLayerPanel: Bool = false
    @State private var shapeRecognitionEnabled: Bool = true
    @State private var layerUpdateTrigger: Int = 0
    @State private var showGridOverlay: Bool = false
    @State private var gridSnapEnabled: Bool = false
    @State private var mirrorModeEnabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(
                canvasMode: $canvasMode,
                gridWidth: $gridWidth,
                gridHeight: $gridHeight,
                brushWidth: $brushWidth,
                undoTrigger: $undoTrigger,
                redoTrigger: $redoTrigger,
                templateGrid: $templateGrid,
                referenceImage: $referenceImage,
                referenceOpacity: $referenceOpacity,
                showLayerPanel: $showLayerPanel,
                shapeRecognitionEnabled: $shapeRecognitionEnabled,
                showGridOverlay: $showGridOverlay,
                gridSnapEnabled: $gridSnapEnabled,
                mirrorModeEnabled: $mirrorModeEnabled,
                onResetLayers: {
                    layers = [DrawingLayer(name: "Layer 1")]
                    activeLayerIndex = 0
                    layerUpdateTrigger += 1
                },
                canvasStore: canvasStore,
                animationStore: animationStore
            )

            ZStack(alignment: .leading) {
                // Canvas - switch based on mode
                switch canvasMode {
                case .pixel:
                    CanvasView(
                        currentColor: $currentColor,
                        currentTool: $currentTool,
                        currentShapeKind: $currentShapeKind,
                        shapeFilled: $shapeFilled,
                        gridWidth: $gridWidth,
                        gridHeight: $gridHeight,
                        undoTrigger: $undoTrigger,
                        redoTrigger: $redoTrigger,
                        templateGrid: $templateGrid,
                        showGridOverlay: $showGridOverlay,
                        onPickColor: { color in
                            currentColor = color
                            currentTool = .pencil
                        },
                        canvasStore: canvasStore,
                        animationStore: animationStore
                    )
                    .background(Color(.systemGray6))

                case .smooth:
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
                        shapeRecognitionEnabled: shapeRecognitionEnabled,
                        showGridOverlay: $showGridOverlay,
                        mirrorModeEnabled: $mirrorModeEnabled,
                        canvasStore: canvasStore,
                        animationStore: animationStore,
                        layers: layers,
                        activeLayerIndex: activeLayerIndex,
                        onPickColor: { color in
                            currentColor = color
                            currentTool = .pencil
                        },
                        onCanvasChanged: {
                            // Sync active layer's drawing from canvas
                            if activeLayerIndex < layers.count,
                               let smoothView = canvasStore.smoothCanvasView {
                                layers[activeLayerIndex].drawing = smoothView.drawing
                            }
                        }
                    )
                    .background(Color(.systemGray6))

                case .dotArt:
                    DotArtCanvasView(
                        currentColor: $currentColor,
                        currentTool: $currentTool,
                        gridSnapEnabled: $gridSnapEnabled,
                        undoTrigger: $undoTrigger,
                        redoTrigger: $redoTrigger,
                        canvasStore: canvasStore,
                        onPickColor: { color in
                            currentColor = color
                            currentTool = .pencil
                        }
                    )
                    .background(Color(.systemGray6))
                }

                // Floating toolbar on the left
                ToolbarView(selectedTool: $currentTool,
                           selectedShapeKind: $currentShapeKind,
                           shapeFilled: $shapeFilled,
                           showLayerPanel: $showLayerPanel,
                           canvasMode: canvasMode)
                    .padding(.leading, 12)

                // Layer panel on the right (smooth mode only)
                if canvasMode == .smooth && showLayerPanel {
                    HStack {
                        Spacer()
                        LayerPanelView(
                            layers: $layers,
                            activeLayerIndex: $activeLayerIndex,
                            onLayerChanged: {
                                layerUpdateTrigger += 1
                            }
                        )
                        .padding(.trailing, 12)
                    }
                }
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
