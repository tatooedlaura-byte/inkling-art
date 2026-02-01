import UIKit

protocol PixelCanvasDelegate: AnyObject {
    func canvasDidPickColor(_ color: UIColor)
    func canvasDidChange()
}

class PixelCanvasUIView: UIView {

    weak var delegate: PixelCanvasDelegate?

    var grid: PixelGrid {
        didSet { setNeedsDisplay() }
    }

    var currentColor: UIColor = .black
    var currentTool: Tool = .pencil
    var onionSkinGrid: PixelGrid?

    // Transform state
    private var canvasScale: CGFloat = 1.0
    private var canvasOffset: CGPoint = .zero

    // Line tool state
    private var lineStart: (Int, Int)?
    private var lineEnd: (Int, Int)?
    private var isDrawingLine = false

    // Undo/redo
    private(set) var undoStack: [PixelGrid] = []
    private(set) var redoStack: [PixelGrid] = []
    private var strokeStartGrid: PixelGrid?

    // Checkerboard tile
    private var checkerPattern: UIColor?

    init(gridSize: Int) {
        self.grid = PixelGrid(width: gridSize, height: gridSize)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.grid = PixelGrid(width: 16, height: 16)
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        contentMode = .redraw

        // Pan gesture (two fingers)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        addGestureRecognizer(pan)

        // Pinch gesture
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)

        // Three-finger swipe left = undo
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeLeft))
        swipeLeft.direction = .left
        swipeLeft.numberOfTouchesRequired = 3
        addGestureRecognizer(swipeLeft)

        // Three-finger swipe right = redo
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeRight))
        swipeRight.direction = .right
        swipeRight.numberOfTouchesRequired = 3
        addGestureRecognizer(swipeRight)

        buildCheckerPattern()
    }

    private func buildCheckerPattern() {
        let size: CGFloat = 10
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size * 2, height: size * 2), true, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        UIColor(white: 0.9, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: size * 2, height: size * 2))
        UIColor(white: 0.75, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.fill(CGRect(x: size, y: size, width: size, height: size))
        if let img = UIGraphicsGetImageFromCurrentImageContext() {
            checkerPattern = UIColor(patternImage: img)
        }
        UIGraphicsEndImageContext()
    }

    // MARK: - Grid size

    func changeGridSize(_ size: Int) {
        pushUndo()
        grid = PixelGrid(width: size, height: size)
        canvasScale = 1.0
        canvasOffset = .zero
        redoStack.removeAll()
        setNeedsDisplay()
    }

    // MARK: - Undo/Redo

    private func pushUndo() {
        undoStack.append(grid)
        if undoStack.count > 100 { undoStack.removeFirst() }
    }

    func performUndo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(grid)
        grid = prev
        delegate?.canvasDidChange()
    }

    func performRedo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(grid)
        grid = next
        delegate?.canvasDidChange()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func loadGrid(_ newGrid: PixelGrid) {
        pushUndo()
        grid = newGrid
        redoStack.removeAll()
        setNeedsDisplay()
        delegate?.canvasDidChange()
    }

    func loadGridWithoutUndo(_ newGrid: PixelGrid) {
        grid = newGrid
        setNeedsDisplay()
    }

    func exportUndoState() -> (undo: [PixelGrid], redo: [PixelGrid]) {
        return (undoStack, redoStack)
    }

    func importUndoState(undoStack: [PixelGrid], redoStack: [PixelGrid]) {
        self.undoStack = undoStack
        self.redoStack = redoStack
    }

    // MARK: - Coordinate conversion

    private var cellSize: CGFloat {
        let w = bounds.width / CGFloat(grid.width)
        let h = bounds.height / CGFloat(grid.height)
        return min(w, h) * canvasScale
    }

    private var gridOrigin: CGPoint {
        let totalW = cellSize * CGFloat(grid.width)
        let totalH = cellSize * CGFloat(grid.height)
        return CGPoint(
            x: (bounds.width - totalW) / 2 + canvasOffset.x,
            y: (bounds.height - totalH) / 2 + canvasOffset.y
        )
    }

    private func gridPosition(for point: CGPoint) -> (row: Int, col: Int)? {
        let origin = gridOrigin
        let cs = cellSize
        let col = Int((point.x - origin.x) / cs)
        let row = Int((point.y - origin.y) / cs)
        guard row >= 0, row < grid.height, col >= 0, col < grid.width else { return nil }
        return (row, col)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let origin = gridOrigin
        let cs = cellSize
        let totalW = cs * CGFloat(grid.width)
        let totalH = cs * CGFloat(grid.height)
        let gridRect = CGRect(x: origin.x, y: origin.y, width: totalW, height: totalH)

        // Checkerboard background
        ctx.saveGState()
        ctx.addRect(gridRect)
        ctx.clip()
        checkerPattern?.setFill()
        ctx.fill(gridRect)
        ctx.restoreGState()

        // Onion skin (previous frame at 25% opacity)
        if let onion = onionSkinGrid {
            for row in 0..<onion.height {
                for col in 0..<onion.width {
                    if let color = onion[row, col] {
                        ctx.setFillColor(color.withAlphaComponent(0.25).cgColor)
                        ctx.fill(CGRect(x: origin.x + CGFloat(col) * cs,
                                        y: origin.y + CGFloat(row) * cs,
                                        width: cs, height: cs))
                    }
                }
            }
        }

        // Pixels
        for row in 0..<grid.height {
            for col in 0..<grid.width {
                if let color = grid[row, col] {
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(CGRect(x: origin.x + CGFloat(col) * cs,
                                    y: origin.y + CGFloat(row) * cs,
                                    width: cs, height: cs))
                }
            }
        }

        // Line tool preview
        if isDrawingLine, let start = lineStart, let end = lineEnd {
            let points = bresenhamLine(x0: start.1, y0: start.0, x1: end.1, y1: end.0)
            ctx.setFillColor(currentColor.cgColor)
            for (py, px) in points {
                guard py >= 0, py < grid.height, px >= 0, px < grid.width else { continue }
                ctx.fill(CGRect(x: origin.x + CGFloat(px) * cs,
                                y: origin.y + CGFloat(py) * cs,
                                width: cs, height: cs))
            }
        }

        // Grid lines
        let gridAlpha = min(1.0, max(0, (canvasScale - 0.5) / 1.5))
        if gridAlpha > 0.01 {
            ctx.setStrokeColor(UIColor(white: 0.3, alpha: gridAlpha * 0.4).cgColor)
            ctx.setLineWidth(0.5)
            for col in 0...grid.width {
                let x = origin.x + CGFloat(col) * cs
                ctx.move(to: CGPoint(x: x, y: origin.y))
                ctx.addLine(to: CGPoint(x: x, y: origin.y + totalH))
            }
            for row in 0...grid.height {
                let y = origin.y + CGFloat(row) * cs
                ctx.move(to: CGPoint(x: origin.x, y: y))
                ctx.addLine(to: CGPoint(x: origin.x + totalW, y: y))
            }
            ctx.strokePath()
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // Only handle stylus or single-finger drawing touches
        if touch.type != .pencil && touches.count < 2 {
            // Allow single finger drawing too for simulator
        }

        let loc = touch.location(in: self)
        guard let pos = gridPosition(for: loc) else { return }

        switch currentTool {
        case .pencil:
            strokeStartGrid = grid
            pushUndo()
            redoStack.removeAll()
            grid[pos.row, pos.col] = currentColor
            setNeedsDisplay()

        case .eraser:
            strokeStartGrid = grid
            pushUndo()
            redoStack.removeAll()
            grid[pos.row, pos.col] = nil
            setNeedsDisplay()

        case .fill:
            pushUndo()
            redoStack.removeAll()
            FloodFill.fill(grid: &grid, row: pos.row, col: pos.col, newColor: currentColor)
            setNeedsDisplay()
            delegate?.canvasDidChange()

        case .eyedropper:
            if let color = grid[pos.row, pos.col] {
                delegate?.canvasDidPickColor(color)
            }

        case .line:
            strokeStartGrid = grid
            lineStart = (pos.row, pos.col)
            lineEnd = (pos.row, pos.col)
            isDrawingLine = true
            pushUndo()
            redoStack.removeAll()
            setNeedsDisplay()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        guard let pos = gridPosition(for: loc) else { return }

        switch currentTool {
        case .pencil:
            grid[pos.row, pos.col] = currentColor
            setNeedsDisplay()
        case .eraser:
            grid[pos.row, pos.col] = nil
            setNeedsDisplay()
        case .line:
            lineEnd = (pos.row, pos.col)
            setNeedsDisplay()
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if currentTool == .line, isDrawingLine, let start = lineStart, let end = lineEnd {
            let points = bresenhamLine(x0: start.1, y0: start.0, x1: end.1, y1: end.0)
            for (py, px) in points {
                guard py >= 0, py < grid.height, px >= 0, px < grid.width else { continue }
                grid[py, px] = currentColor
            }
            isDrawingLine = false
            lineStart = nil
            lineEnd = nil
            setNeedsDisplay()
        }

        strokeStartGrid = nil
        delegate?.canvasDidChange()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDrawingLine = false
        lineStart = nil
        lineEnd = nil
        strokeStartGrid = nil
        setNeedsDisplay()
    }

    // MARK: - Gestures

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        canvasOffset.x += translation.x
        canvasOffset.y += translation.y
        gesture.setTranslation(.zero, in: self)
        setNeedsDisplay()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        canvasScale *= gesture.scale
        canvasScale = max(0.25, min(canvasScale, 20))
        gesture.scale = 1
        setNeedsDisplay()
    }

    @objc private func handleThreeFingerSwipeLeft() {
        performUndo()
    }

    @objc private func handleThreeFingerSwipeRight() {
        performRedo()
    }

    // MARK: - Bresenham line

    private func bresenhamLine(x0: Int, y0: Int, x1: Int, y1: Int) -> [(Int, Int)] {
        var points: [(Int, Int)] = []
        var x0 = x0, y0 = y0
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            points.append((y0, x0))
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy {
                err += dy
                x0 += sx
            }
            if e2 <= dx {
                err += dx
                y0 += sy
            }
        }
        return points
    }
}
