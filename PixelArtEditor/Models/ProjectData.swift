import UIKit

struct PixelColor: Codable {
    let r: Float
    let g: Float
    let b: Float
    let a: Float

    init(from color: UIColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        r = Float(red)
        g = Float(green)
        b = Float(blue)
        a = Float(alpha)
    }

    func toUIColor() -> UIColor {
        UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}

struct ProjectData: Codable {
    let gridWidth: Int
    let gridHeight: Int
    let frames: [[[PixelColor?]]]
    let fps: Int
    let currentFrameIndex: Int

    static func from(animationStore: AnimationStore, canvas: PixelCanvasUIView?) -> ProjectData {
        if let canvas = canvas {
            animationStore.syncCurrentFrameFromCanvas(canvas)
        }
        let frameData: [[[PixelColor?]]] = animationStore.frames.map { frame in
            frame.grid.pixels.map { row in
                row.map { color in
                    color.map { PixelColor(from: $0) }
                }
            }
        }
        let grid = animationStore.frames.first?.grid
        return ProjectData(
            gridWidth: grid?.width ?? 16,
            gridHeight: grid?.height ?? 16,
            frames: frameData,
            fps: animationStore.fps,
            currentFrameIndex: animationStore.currentFrameIndex
        )
    }

    func restore(to animationStore: AnimationStore, canvas: PixelCanvasUIView?) {
        animationStore.stopPlayback(canvas: canvas)
        var newFrames: [AnimationFrame] = []
        for framePixels in frames {
            var grid = PixelGrid(width: gridWidth, height: gridHeight)
            for (row, rowColors) in framePixels.enumerated() {
                for (col, pixelColor) in rowColors.enumerated() {
                    if let pc = pixelColor {
                        grid[row, col] = pc.toUIColor()
                    }
                }
            }
            newFrames.append(AnimationFrame(grid: grid))
        }
        if newFrames.isEmpty {
            newFrames.append(AnimationFrame(grid: PixelGrid(width: gridWidth, height: gridHeight)))
        }
        animationStore.frames = newFrames
        animationStore.fps = fps
        animationStore.currentFrameIndex = min(currentFrameIndex, newFrames.count - 1)
        if let canvas = canvas {
            animationStore.loadFrameToCanvas(canvas, index: animationStore.currentFrameIndex)
        }
    }
}
