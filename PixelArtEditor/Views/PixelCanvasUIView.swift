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
    var currentShapeKind: ShapeKind = .line
    var shapeFilled: Bool = false
    var onionSkinGrid: PixelGrid?

    // Reference image (for tracing)
    var referenceImage: UIImage?
    var referenceOpacity: CGFloat = 0.3

    // Transform state
    private var canvasScale: CGFloat = 1.0
    private var canvasOffset: CGPoint = .zero

    // Shape tool state (used for line + all shapes)
    private var shapeStart: (Int, Int)?
    private var shapeEnd: (Int, Int)?
    private var isDrawingShape = false

    // Undo/redo
    private(set) var undoStack: [PixelGrid] = []
    private(set) var redoStack: [PixelGrid] = []
    private var strokeStartGrid: PixelGrid?

    // Multi-touch tracking
    private var activeTouchCount = 0
    private var multiTouchDetected = false

    // Selection tool state
    private var selectionStart: (row: Int, col: Int)?
    private var selectionEnd: (row: Int, col: Int)?
    private var selectionGridRect: (minRow: Int, minCol: Int, maxRow: Int, maxCol: Int)?
    private var hasActiveSelection = false
    private var isDrawingSelection = false
    private var isMovingSelection = false
    private var moveLastGridPos: (row: Int, col: Int)?
    private var flippedPixels: [(row: Int, col: Int, color: UIColor)] = []
    private var flipButton: UIButton?

    // Checkerboard tile
    private var checkerPattern: UIColor?

    init(gridSize: Int) {
        self.grid = PixelGrid(width: gridSize, height: gridSize)
        super.init(frame: .zero)
        setup()
    }

    init(gridWidth: Int, gridHeight: Int) {
        self.grid = PixelGrid(width: gridWidth, height: gridHeight)
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

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeLeft))
        swipeLeft.direction = .left
        swipeLeft.numberOfTouchesRequired = 3
        addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeRight))
        swipeRight.direction = .right
        swipeRight.numberOfTouchesRequired = 3
        addGestureRecognizer(swipeRight)

        buildCheckerPattern()

        // Flip button for selection tool
        let btn = UIButton(type: .system)
        btn.setTitle("Flip", for: .normal)
        btn.setImage(UIImage(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right"), for: .normal)
        btn.backgroundColor = UIColor.systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.tintColor = .white
        btn.titleLabel?.font = .boldSystemFont(ofSize: 15)
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        btn.addTarget(self, action: #selector(flipButtonTapped), for: .touchUpInside)
        btn.isHidden = true
        addSubview(btn)
        flipButton = btn
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
        changeGridSize(width: size, height: size)
    }

    func changeGridSize(width: Int, height: Int) {
        pushUndo()
        grid = PixelGrid(width: width, height: height)
        canvasScale = 1.0
        canvasOffset = .zero
        redoStack.removeAll()
        setNeedsDisplay()
    }

    // MARK: - Zoom

    func zoomIn() {
        canvasScale = min(canvasScale * 1.5, 20)
        setNeedsDisplay()
    }

    func zoomOut() {
        canvasScale = max(canvasScale / 1.5, 0.25)
        setNeedsDisplay()
    }

    func resetZoom() {
        canvasScale = 1.0
        canvasOffset = .zero
        setNeedsDisplay()
    }

    // MARK: - Undo/Redo

    private func pushUndo() {
        undoStack.append(grid)
        if undoStack.count > 100 { undoStack.removeFirst() }
    }

    func performUndo() {
        if hasActiveSelection || isMovingSelection {
            // Discard flipped pixels without committing
            flippedPixels = []
            selectionStart = nil
            selectionEnd = nil
            selectionGridRect = nil
            hasActiveSelection = false
            isDrawingSelection = false
            isMovingSelection = false
            moveLastGridPos = nil
            flipButton?.isHidden = true
            setNeedsDisplay()
            return
        }
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

        // Reference image (for tracing)
        if let refImage = referenceImage {
            ctx.saveGState()
            ctx.setAlpha(referenceOpacity)
            refImage.draw(in: gridRect)
            ctx.restoreGState()
        }

        // Onion skin
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

        // Shape preview
        if isDrawingShape, let start = shapeStart, let end = shapeEnd {
            let points = ShapeRasterizer.rasterize(
                shape: currentShapeKind,
                r0: start.0, c0: start.1, r1: end.0, c1: end.1,
                filled: currentShapeKind == .line ? false : shapeFilled
            )
            ctx.setFillColor(currentColor.cgColor)
            for (py, px) in points {
                guard py >= 0, py < grid.height, px >= 0, px < grid.width else { continue }
                ctx.fill(CGRect(x: origin.x + CGFloat(px) * cs,
                                y: origin.y + CGFloat(py) * cs,
                                width: cs, height: cs))
            }
        }

        // Flipped pixel preview (before committing)
        if !flippedPixels.isEmpty {
            for pixel in flippedPixels {
                guard pixel.row >= 0, pixel.row < grid.height, pixel.col >= 0, pixel.col < grid.width else { continue }
                ctx.setFillColor(pixel.color.cgColor)
                ctx.fill(CGRect(x: origin.x + CGFloat(pixel.col) * cs,
                                y: origin.y + CGFloat(pixel.row) * cs,
                                width: cs, height: cs))
            }
        }

        // Selection marquee
        if let rect = selectionGridRect, (hasActiveSelection || isDrawingSelection) {
            let selRect = CGRect(
                x: origin.x + CGFloat(rect.minCol) * cs,
                y: origin.y + CGFloat(rect.minRow) * cs,
                width: CGFloat(rect.maxCol - rect.minCol + 1) * cs,
                height: CGFloat(rect.maxRow - rect.minRow + 1) * cs
            )
            // Light blue fill
            ctx.setFillColor(UIColor.systemBlue.withAlphaComponent(0.08).cgColor)
            ctx.fill(selRect)
            // Dashed blue stroke
            ctx.setStrokeColor(UIColor.systemBlue.cgColor)
            ctx.setLineWidth(2)
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            ctx.stroke(selRect)
            ctx.setLineDash(phase: 0, lengths: [])
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
        activeTouchCount = event?.allTouches?.count ?? touches.count
        if activeTouchCount > 1 {
            multiTouchDetected = true
            if let startGrid = strokeStartGrid {
                _ = undoStack.popLast()
                grid = startGrid
                strokeStartGrid = nil
                setNeedsDisplay()
            }
            return
        }
        multiTouchDetected = false

        guard let touch = touches.first else { return }
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

        case .shape:
            strokeStartGrid = grid
            shapeStart = (pos.row, pos.col)
            shapeEnd = (pos.row, pos.col)
            isDrawingShape = true
            pushUndo()
            redoStack.removeAll()
            setNeedsDisplay()

        case .select:
            if isMovingSelection, let rect = selectionGridRect {
                // Check if tap is near the flipped pixels area
                let moveRect = flippedPixelsBounds() ?? rect
                if pos.row >= moveRect.minRow - 1 && pos.row <= moveRect.maxRow + 1 &&
                   pos.col >= moveRect.minCol - 1 && pos.col <= moveRect.maxCol + 1 {
                    moveLastGridPos = (pos.row, pos.col)
                } else {
                    commitFlippedPixels()
                    clearSelection()
                }
            } else if hasActiveSelection {
                // Tap outside clears
                if let rect = selectionGridRect,
                   (pos.row < rect.minRow || pos.row > rect.maxRow || pos.col < rect.minCol || pos.col > rect.maxCol) {
                    clearSelection()
                }
            } else {
                clearSelection()
                selectionStart = (pos.row, pos.col)
                selectionEnd = (pos.row, pos.col)
                isDrawingSelection = true
                setNeedsDisplay()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouchCount = event?.allTouches?.count ?? touches.count
        if activeTouchCount > 1 { multiTouchDetected = true }
        guard !multiTouchDetected else { return }

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
        case .shape:
            shapeEnd = (pos.row, pos.col)
            setNeedsDisplay()
        case .select:
            if isMovingSelection, let last = moveLastGridPos {
                let dRow = pos.row - last.row
                let dCol = pos.col - last.col
                if dRow != 0 || dCol != 0 {
                    moveFlippedPixels(dRow: dRow, dCol: dCol)
                    moveLastGridPos = (pos.row, pos.col)
                    setNeedsDisplay()
                }
            } else if isDrawingSelection {
                selectionEnd = (pos.row, pos.col)
                if let start = selectionStart {
                    selectionGridRect = (min(start.row, pos.row), min(start.col, pos.col),
                                         max(start.row, pos.row), max(start.col, pos.col))
                }
                setNeedsDisplay()
            }
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouchCount = max(0, (event?.allTouches?.count ?? 1) - touches.count)
        if multiTouchDetected {
            if activeTouchCount == 0 { multiTouchDetected = false }
            strokeStartGrid = nil
            isDrawingShape = false
            shapeStart = nil
            shapeEnd = nil
            return
        }

        if currentTool == .select {
            if isMovingSelection {
                moveLastGridPos = nil
            } else if isDrawingSelection {
                isDrawingSelection = false
                finalizeSelection()
            }
            return
        }

        if currentTool == .shape, isDrawingShape, let start = shapeStart, let end = shapeEnd {
            let points = ShapeRasterizer.rasterize(
                shape: currentShapeKind,
                r0: start.0, c0: start.1, r1: end.0, c1: end.1,
                filled: currentShapeKind == .line ? false : shapeFilled
            )
            for (py, px) in points {
                guard py >= 0, py < grid.height, px >= 0, px < grid.width else { continue }
                grid[py, px] = currentColor
            }
            isDrawingShape = false
            shapeStart = nil
            shapeEnd = nil
            setNeedsDisplay()
        }

        strokeStartGrid = nil
        delegate?.canvasDidChange()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDrawingShape = false
        shapeStart = nil
        shapeEnd = nil
        strokeStartGrid = nil
        setNeedsDisplay()
    }

    // MARK: - Selection Tool

    private func finalizeSelection() {
        guard let start = selectionStart, let end = selectionEnd else {
            clearSelection()
            return
        }

        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)

        // Skip tiny selections
        guard maxRow - minRow >= 1 || maxCol - minCol >= 1 else {
            clearSelection()
            return
        }

        // Check if any pixels exist in selection
        var hasPixels = false
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                if grid[row, col] != nil {
                    hasPixels = true
                    break
                }
            }
            if hasPixels { break }
        }

        guard hasPixels else {
            clearSelection()
            return
        }

        selectionGridRect = (minRow, minCol, maxRow, maxCol)
        hasActiveSelection = true
        showFlipButton()
    }

    private func showFlipButton() {
        guard let rect = selectionGridRect, let btn = flipButton else { return }
        let origin = gridOrigin
        let cs = cellSize
        let selMidX = origin.x + (CGFloat(rect.minCol) + CGFloat(rect.maxCol - rect.minCol + 1) / 2) * cs
        let selBottomY = origin.y + CGFloat(rect.maxRow + 1) * cs + 12
        btn.sizeToFit()
        btn.frame = CGRect(x: selMidX - btn.frame.width / 2, y: selBottomY,
                           width: btn.frame.width, height: btn.frame.height)
        btn.isHidden = false
    }

    @objc private func flipButtonTapped() {
        flipSelectionHorizontally()
    }

    private func flipSelectionHorizontally() {
        guard let rect = selectionGridRect else { return }

        pushUndo()
        redoStack.removeAll()

        // Collect pixels from selection and create flipped copies
        let selWidth = rect.maxCol - rect.minCol + 1
        flippedPixels = []

        for row in rect.minRow...rect.maxRow {
            for col in rect.minCol...rect.maxCol {
                if let color = grid[row, col] {
                    let flippedCol = rect.minCol + (selWidth - 1) - (col - rect.minCol)
                    flippedPixels.append((row: row, col: flippedCol, color: color))
                }
            }
        }

        // Enter move mode
        isMovingSelection = true
        hasActiveSelection = false
        flipButton?.isHidden = true
        setNeedsDisplay()
    }

    private func moveFlippedPixels(dRow: Int, dCol: Int) {
        flippedPixels = flippedPixels.map { (row: $0.row + dRow, col: $0.col + dCol, color: $0.color) }
        if let rect = selectionGridRect {
            selectionGridRect = (rect.minRow + dRow, rect.minCol + dCol, rect.maxRow + dRow, rect.maxCol + dCol)
        }
    }

    private func flippedPixelsBounds() -> (minRow: Int, minCol: Int, maxRow: Int, maxCol: Int)? {
        guard !flippedPixels.isEmpty else { return nil }
        let rows = flippedPixels.map { $0.row }
        let cols = flippedPixels.map { $0.col }
        return (rows.min()!, cols.min()!, rows.max()!, cols.max()!)
    }

    private func commitFlippedPixels() {
        guard !flippedPixels.isEmpty else { return }
        for pixel in flippedPixels {
            guard pixel.row >= 0, pixel.row < grid.height, pixel.col >= 0, pixel.col < grid.width else { continue }
            grid[pixel.row, pixel.col] = pixel.color
        }
        flippedPixels = []
        setNeedsDisplay()
        delegate?.canvasDidChange()
    }

    private func clearSelection() {
        if isMovingSelection && !flippedPixels.isEmpty {
            commitFlippedPixels()
        }
        selectionStart = nil
        selectionEnd = nil
        selectionGridRect = nil
        hasActiveSelection = false
        isDrawingSelection = false
        isMovingSelection = false
        moveLastGridPos = nil
        flippedPixels = []
        flipButton?.isHidden = true
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
}
