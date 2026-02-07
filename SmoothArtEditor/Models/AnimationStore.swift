import SwiftUI
import PencilKit

class AnimationFrame: Identifiable, ObservableObject {
    let id = UUID()
    @Published var canvas: VectorCanvas

    init(canvas: VectorCanvas = VectorCanvas()) {
        self.canvas = canvas
    }
}

class AnimationStore: ObservableObject {
    @Published var frames: [AnimationFrame] = []
    @Published var currentFrameIndex: Int = 0
    @Published var fps: Int = 8
    @Published var isPlaying: Bool = false

    private var playbackTimer: Timer?

    var currentFrame: AnimationFrame? {
        guard currentFrameIndex >= 0 && currentFrameIndex < frames.count else { return nil }
        return frames[currentFrameIndex]
    }

    var previousFrameCanvas: VectorCanvas? {
        guard currentFrameIndex > 0 else { return nil }
        return frames[currentFrameIndex - 1].canvas
    }

    func initialize() {
        frames = [AnimationFrame()]
        currentFrameIndex = 0
        stopPlayback()
    }

    func addFrame() {
        let newFrame = AnimationFrame()
        frames.insert(newFrame, at: currentFrameIndex + 1)
        currentFrameIndex += 1
    }

    func duplicateCurrentFrame() {
        guard let current = currentFrame else { return }
        let newFrame = AnimationFrame(canvas: current.canvas)
        frames.insert(newFrame, at: currentFrameIndex + 1)
        currentFrameIndex += 1
    }

    func deleteCurrentFrame() {
        guard frames.count > 1 else { return }
        frames.remove(at: currentFrameIndex)
        if currentFrameIndex >= frames.count {
            currentFrameIndex = frames.count - 1
        }
    }

    func selectFrame(at index: Int) {
        guard index >= 0 && index < frames.count else { return }
        currentFrameIndex = index
    }

    func syncCurrentFrameFromCanvas(_ canvasView: SmoothCanvasUIView) {
        guard let frame = currentFrame else { return }
        frame.canvas = VectorCanvas(drawing: canvasView.drawing)
    }

    func loadFrameToCanvas(_ canvasView: SmoothCanvasUIView, index: Int) {
        guard index >= 0 && index < frames.count else { return }
        canvasView.drawing = frames[index].canvas.drawing
    }

    // MARK: - Playback

    func startPlayback(canvas: SmoothCanvasUIView?) {
        guard !isPlaying else { return }
        isPlaying = true

        if let cv = canvas {
            syncCurrentFrameFromCanvas(cv)
        }

        let interval = 1.0 / Double(fps)
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
                if let cv = canvas {
                    self.loadFrameToCanvas(cv, index: self.currentFrameIndex)
                }
            }
        }
    }

    func stopPlayback(canvas: SmoothCanvasUIView? = nil) {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
    }

    func togglePlayback(canvas: SmoothCanvasUIView?) {
        if isPlaying {
            stopPlayback(canvas: canvas)
        } else {
            startPlayback(canvas: canvas)
        }
    }
}
