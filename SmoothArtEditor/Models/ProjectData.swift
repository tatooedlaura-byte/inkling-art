import Foundation
import PencilKit

struct ProjectData: Codable {
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let frames: [Data]  // PKDrawing.dataRepresentation()
    let fps: Int
    let currentFrameIndex: Int

    static func from(animationStore: AnimationStore, canvas: SmoothCanvasUIView?, canvasSize: CGSize) -> ProjectData {
        if let cv = canvas {
            animationStore.syncCurrentFrameFromCanvas(cv)
        }

        let frameData = animationStore.frames.map { $0.canvas.drawing.dataRepresentation() }

        return ProjectData(
            canvasWidth: canvasSize.width,
            canvasHeight: canvasSize.height,
            frames: frameData,
            fps: animationStore.fps,
            currentFrameIndex: animationStore.currentFrameIndex
        )
    }

    func restore(to animationStore: AnimationStore, canvas: SmoothCanvasUIView?) {
        var newFrames: [AnimationFrame] = []
        for data in frames {
            if let drawing = try? PKDrawing(data: data) {
                newFrames.append(AnimationFrame(canvas: VectorCanvas(drawing: drawing)))
            } else {
                newFrames.append(AnimationFrame())
            }
        }

        if newFrames.isEmpty {
            newFrames = [AnimationFrame()]
        }

        animationStore.frames = newFrames
        animationStore.fps = fps
        animationStore.currentFrameIndex = min(currentFrameIndex, newFrames.count - 1)

        if let cv = canvas {
            animationStore.loadFrameToCanvas(cv, index: animationStore.currentFrameIndex)
        }
    }
}
