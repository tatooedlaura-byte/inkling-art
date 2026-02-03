import UIKit
import Combine

class AnimationFrame {
    var grid: PixelGrid
    var undoStack: [PixelGrid] = []
    var redoStack: [PixelGrid] = []

    init(grid: PixelGrid) {
        self.grid = grid
    }

    init(copying frame: AnimationFrame) {
        self.grid = frame.grid
        self.undoStack = frame.undoStack
        self.redoStack = frame.redoStack
    }
}

class AnimationStore: ObservableObject {
    @Published var frames: [AnimationFrame] = []
    @Published var currentFrameIndex: Int = 0
    @Published var fps: Int = 8
    @Published var onionSkinEnabled: Bool = false
    @Published var isPlaying: Bool = false

    private var playbackTimer: Timer?
    private weak var playbackCanvas: PixelCanvasUIView?

    var currentFrame: AnimationFrame? {
        guard currentFrameIndex >= 0, currentFrameIndex < frames.count else { return nil }
        return frames[currentFrameIndex]
    }

    var previousFrameGrid: PixelGrid? {
        guard onionSkinEnabled, currentFrameIndex > 0 else { return nil }
        return frames[currentFrameIndex - 1].grid
    }

    func initialize(gridSize: Int) {
        initialize(width: gridSize, height: gridSize)
    }

    func initialize(width: Int, height: Int) {
        stopPlayback()
        let grid = PixelGrid(width: width, height: height)
        frames = [AnimationFrame(grid: grid)]
        currentFrameIndex = 0
    }

    func syncCurrentFrameFromCanvas(_ canvas: PixelCanvasUIView) {
        guard let frame = currentFrame else { return }
        frame.grid = canvas.grid
        frame.undoStack = canvas.undoStack
        frame.redoStack = canvas.redoStack
    }

    func loadFrameToCanvas(_ canvas: PixelCanvasUIView, index: Int) {
        guard index >= 0, index < frames.count else { return }
        let frame = frames[index]
        canvas.loadGridWithoutUndo(frame.grid)
        canvas.importUndoState(undoStack: frame.undoStack, redoStack: frame.redoStack)
    }

    func selectFrame(index: Int, canvas: PixelCanvasUIView) {
        guard index >= 0, index < frames.count, index != currentFrameIndex else { return }
        syncCurrentFrameFromCanvas(canvas)
        currentFrameIndex = index
        loadFrameToCanvas(canvas, index: index)
    }

    func addFrame(canvas: PixelCanvasUIView) {
        syncCurrentFrameFromCanvas(canvas)
        let w = frames.first?.grid.width ?? 16
        let h = frames.first?.grid.height ?? 16
        let newFrame = AnimationFrame(grid: PixelGrid(width: w, height: h))
        frames.insert(newFrame, at: currentFrameIndex + 1)
        currentFrameIndex += 1
        loadFrameToCanvas(canvas, index: currentFrameIndex)
    }

    func duplicateFrame(at index: Int, canvas: PixelCanvasUIView) {
        syncCurrentFrameFromCanvas(canvas)
        let copy = AnimationFrame(copying: frames[index])
        frames.insert(copy, at: index + 1)
        currentFrameIndex = index + 1
        loadFrameToCanvas(canvas, index: currentFrameIndex)
    }

    func deleteFrame(at index: Int, canvas: PixelCanvasUIView) {
        guard frames.count > 1 else { return }
        frames.remove(at: index)
        if currentFrameIndex >= frames.count {
            currentFrameIndex = frames.count - 1
        }
        loadFrameToCanvas(canvas, index: currentFrameIndex)
    }

    func startPlayback(canvas: PixelCanvasUIView) {
        guard frames.count > 1 else { return }
        syncCurrentFrameFromCanvas(canvas)
        isPlaying = true
        playbackCanvas = canvas
        canvas.isUserInteractionEnabled = false
        schedulePlaybackTimer()
    }

    private func schedulePlaybackTimer() {
        playbackTimer?.invalidate()
        guard isPlaying, let canvas = playbackCanvas else { return }
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(fps), repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let next = (self.currentFrameIndex + 1) % self.frames.count
            self.currentFrameIndex = next
            canvas.loadGridWithoutUndo(self.frames[next].grid)
        }
    }

    func updatePlaybackSpeed() {
        guard isPlaying else { return }
        schedulePlaybackTimer()
    }

    func stopPlayback(canvas: PixelCanvasUIView? = nil) {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        canvas?.isUserInteractionEnabled = true
        if let canvas = canvas, let frame = currentFrame {
            canvas.importUndoState(undoStack: frame.undoStack, redoStack: frame.redoStack)
        }
    }

    func renderThumbnail(for index: Int, size: CGFloat) -> UIImage? {
        guard index >= 0, index < frames.count else { return nil }
        return PNGExporter.renderImage(grid: frames[index].grid, scale: max(1, Int(size) / frames[index].grid.width))
    }
}
