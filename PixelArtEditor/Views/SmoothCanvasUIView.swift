import UIKit
import PencilKit

protocol SmoothCanvasDelegate: AnyObject {
    func canvasDidChange()
    func didPickColor(_ color: UIColor)
}

class SmoothCanvasUIView: UIView, PKCanvasViewDelegate, UIScrollViewDelegate {
    weak var delegate: SmoothCanvasDelegate?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let pkCanvasView = PKCanvasView()
    private let checkerboardView = UIView()
    private let shapePreviewLayer = CAShapeLayer()

    private var canvasSize: CGFloat = 1024
    private var contentWidthConstraint: NSLayoutConstraint?
    private var contentHeightConstraint: NSLayoutConstraint?

    // Shape tool state
    private var isDrawingShape = false
    private var shapeStartPoint: CGPoint?
    private var shapeEndPoint: CGPoint?
    private var shapePanGesture: UIPanGestureRecognizer!
    private var eyedropperTapGesture: UITapGestureRecognizer!
    private var fillTapGesture: UITapGestureRecognizer!

    // Reference image
    private let referenceImageView = UIImageView()

    var drawing: PKDrawing {
        get { pkCanvasView.drawing }
        set { pkCanvasView.drawing = newValue }
    }

    var referenceImage: UIImage? {
        didSet {
            referenceImageView.image = referenceImage
        }
    }

    var referenceOpacity: CGFloat = 0.3 {
        didSet {
            referenceImageView.alpha = referenceOpacity
        }
    }

    var currentColor: UIColor = .black {
        didSet { updateTool() }
    }

    var currentTool: Tool = .pencil {
        didSet {
            updateTool()
            shapePreviewLayer.path = nil
            isDrawingShape = false
        }
    }

    var currentShapeKind: ShapeKind = .line

    var shapeFilled: Bool = false

    var brushWidth: CGFloat = 5.0 {
        didSet { updateTool() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        // Scroll view for zoom/pan
        addSubview(scrollView)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.25
        scrollView.maximumZoomScale = 8.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Content view that will be zoomed
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Checkerboard background
        contentView.addSubview(checkerboardView)
        checkerboardView.backgroundColor = buildCheckerPattern()
        checkerboardView.translatesAutoresizingMaskIntoConstraints = false

        // Reference image
        contentView.addSubview(referenceImageView)
        referenceImageView.contentMode = .scaleAspectFit
        referenceImageView.alpha = referenceOpacity
        referenceImageView.translatesAutoresizingMaskIntoConstraints = false

        // PencilKit canvas
        contentView.addSubview(pkCanvasView)
        pkCanvasView.delegate = self
        pkCanvasView.backgroundColor = .clear
        pkCanvasView.isOpaque = false
        pkCanvasView.drawingPolicy = .anyInput
        pkCanvasView.translatesAutoresizingMaskIntoConstraints = false
        pkCanvasView.isScrollEnabled = false
        pkCanvasView.overrideUserInterfaceStyle = .light

        // Shape preview layer
        shapePreviewLayer.fillColor = nil
        shapePreviewLayer.lineCap = .round
        shapePreviewLayer.frame = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
        contentView.layer.addSublayer(shapePreviewLayer)

        // Shape tool gesture
        shapePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleShapePan(_:)))
        shapePanGesture.isEnabled = false
        shapePanGesture.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(shapePanGesture)

        // Eyedropper tap gesture
        eyedropperTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleEyedropperTap(_:)))
        eyedropperTapGesture.isEnabled = false
        scrollView.addGestureRecognizer(eyedropperTapGesture)

        // Fill tap gesture
        fillTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleFillTap(_:)))
        fillTapGesture.isEnabled = false
        scrollView.addGestureRecognizer(fillTapGesture)

        contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: canvasSize)
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: canvasSize)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentWidthConstraint!,
            contentHeightConstraint!,

            checkerboardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            checkerboardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            checkerboardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            checkerboardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            referenceImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            referenceImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            referenceImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            referenceImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            pkCanvasView.topAnchor.constraint(equalTo: contentView.topAnchor),
            pkCanvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pkCanvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pkCanvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Undo/redo gestures
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeLeft))
        swipeLeft.direction = .left
        swipeLeft.numberOfTouchesRequired = 3
        addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeRight))
        swipeRight.direction = .right
        swipeRight.numberOfTouchesRequired = 3
        addGestureRecognizer(swipeRight)

        updateTool()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.contentSize = CGSize(width: canvasSize, height: canvasSize)
        if scrollView.zoomScale == 1.0 {
            centerContent()
        }
    }

    private func centerContent() {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width * scrollView.zoomScale) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height * scrollView.zoomScale) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
    }

    private func buildCheckerPattern() -> UIColor {
        let size: CGFloat = 10
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size * 2, height: size * 2), true, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return .white }
        UIColor(white: 0.9, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: size * 2, height: size * 2))
        UIColor(white: 0.75, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.fill(CGRect(x: size, y: size, width: size, height: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img.map { UIColor(patternImage: $0) } ?? .white
    }

    private func updateTool() {
        let inkingTool: PKInkingTool
        if #available(iOS 17.0, *) {
            inkingTool = PKInkingTool(.monoline, color: currentColor, width: brushWidth)
        } else {
            inkingTool = PKInkingTool(.marker, color: currentColor, width: brushWidth)
        }

        shapePreviewLayer.strokeColor = currentColor.cgColor
        shapePreviewLayer.lineWidth = brushWidth

        switch currentTool {
        case .pencil:
            pkCanvasView.tool = inkingTool
            pkCanvasView.isUserInteractionEnabled = true
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
            shapePanGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = false
            fillTapGesture.isEnabled = false

        case .eraser:
            pkCanvasView.tool = PKEraserTool(.vector)
            pkCanvasView.isUserInteractionEnabled = true
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
            shapePanGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = false
            fillTapGesture.isEnabled = false

        case .fill:
            pkCanvasView.isUserInteractionEnabled = false
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
            shapePanGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = false
            fillTapGesture.isEnabled = true

        case .eyedropper:
            pkCanvasView.isUserInteractionEnabled = false
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
            shapePanGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = true
            fillTapGesture.isEnabled = false

        case .shape:
            pkCanvasView.isUserInteractionEnabled = false
            scrollView.isScrollEnabled = false
            scrollView.pinchGestureRecognizer?.isEnabled = false
            shapePanGesture.isEnabled = true
            eyedropperTapGesture.isEnabled = false
            fillTapGesture.isEnabled = false
        }
    }

    // MARK: - Eyedropper

    @objc private func handleEyedropperTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: contentView)

        // Render the canvas to an image and sample the color at the tap point
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize, height: canvasSize))
        let image = renderer.image { context in
            // Draw checkerboard
            checkerboardView.layer.render(in: context.cgContext)
            // Draw the PKDrawing
            let drawingImage = pkCanvasView.drawing.image(from: CGRect(origin: .zero, size: CGSize(width: canvasSize, height: canvasSize)), scale: 1.0)
            drawingImage.draw(at: .zero)
        }

        // Sample color at location
        if let color = image.pixelColor(at: location) {
            delegate?.didPickColor(color)
        }
    }

    // MARK: - Fill Tool

    @objc private func handleFillTap(_ gesture: UITapGestureRecognizer) {
        // Fill creates a full-canvas rectangle with the current color
        let rect = CGRect(origin: .zero, size: CGSize(width: canvasSize, height: canvasSize))

        var strokePoints: [PKStrokePoint] = []
        var time: Double = 0

        func addPoint(_ point: CGPoint) {
            let strokePoint = PKStrokePoint(
                location: point,
                timeOffset: time,
                size: CGSize(width: 1, height: 1),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            )
            strokePoints.append(strokePoint)
            time += 0.001
        }

        // Create a filled rectangle by drawing many horizontal lines
        let step: CGFloat = 2
        var y: CGFloat = 0
        var goingRight = true

        while y <= canvasSize {
            if goingRight {
                addPoint(CGPoint(x: 0, y: y))
                addPoint(CGPoint(x: canvasSize, y: y))
            } else {
                addPoint(CGPoint(x: canvasSize, y: y))
                addPoint(CGPoint(x: 0, y: y))
            }
            y += step
            goingRight.toggle()
        }

        guard strokePoints.count >= 2 else { return }

        let ink: PKInk
        if #available(iOS 17.0, *) {
            ink = PKInk(.monoline, color: currentColor)
        } else {
            ink = PKInk(.marker, color: currentColor)
        }

        let strokePath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        let stroke = PKStroke(ink: ink, path: strokePath)

        var currentDrawing = pkCanvasView.drawing
        // Insert at beginning so it's behind other strokes
        currentDrawing.strokes.insert(stroke, at: 0)
        pkCanvasView.drawing = currentDrawing

        delegate?.canvasDidChange()
    }

    // MARK: - Shape Tool

    @objc private func handleShapePan(_ gesture: UIPanGestureRecognizer) {
        // Get location in contentView (where shapes are drawn)
        let location = gesture.location(in: contentView)

        switch gesture.state {
        case .began:
            shapeStartPoint = location
            shapeEndPoint = location
            isDrawingShape = true
            updateShapePreview()

        case .changed:
            shapeEndPoint = location
            updateShapePreview()

        case .ended:
            shapeEndPoint = location
            commitShape()
            isDrawingShape = false
            shapePreviewLayer.path = nil

        case .cancelled, .failed:
            isDrawingShape = false
            shapePreviewLayer.path = nil

        default:
            break
        }
    }

    private func constrainedEnd(start: CGPoint, end: CGPoint) -> CGPoint {
        // For square/circle, constrain to equal dimensions
        if currentShapeKind == .square || currentShapeKind == .circle {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let size = max(abs(dx), abs(dy))
            return CGPoint(x: start.x + (dx >= 0 ? size : -size),
                           y: start.y + (dy >= 0 ? size : -size))
        }
        return end
    }

    private func updateShapePreview() {
        guard let start = shapeStartPoint, let end = shapeEndPoint else { return }
        let constrainedEndPoint = constrainedEnd(start: start, end: end)

        let path: UIBezierPath

        switch currentShapeKind {
        case .line:
            path = UIBezierPath()
            path.move(to: start)
            path.addLine(to: constrainedEndPoint)

        case .rectangle, .square:
            let rect = CGRect(x: min(start.x, constrainedEndPoint.x),
                              y: min(start.y, constrainedEndPoint.y),
                              width: abs(constrainedEndPoint.x - start.x),
                              height: abs(constrainedEndPoint.y - start.y))
            path = UIBezierPath(rect: rect)

        case .oval, .circle:
            let rect = CGRect(x: min(start.x, constrainedEndPoint.x),
                              y: min(start.y, constrainedEndPoint.y),
                              width: abs(constrainedEndPoint.x - start.x),
                              height: abs(constrainedEndPoint.y - start.y))
            path = UIBezierPath(ovalIn: rect)

        case .star:
            path = starPath(from: start, to: constrainedEndPoint)
        }

        shapePreviewLayer.path = path.cgPath
        shapePreviewLayer.fillColor = shapeFilled && currentShapeKind != .line ? currentColor.cgColor : nil
    }

    private func starPath(from start: CGPoint, to end: CGPoint) -> UIBezierPath {
        let cx = (start.x + end.x) / 2
        let cy = (start.y + end.y) / 2
        let outerRadius = max(abs(end.x - start.x), abs(end.y - start.y)) / 2
        let innerRadius = outerRadius * 0.4

        let path = UIBezierPath()
        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5.0 - .pi / 2.0
            let radius = (i % 2 == 0) ? outerRadius : innerRadius
            let x = cx + radius * cos(angle)
            let y = cy + radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.close()
        return path
    }

    private func commitShape() {
        guard let start = shapeStartPoint, let rawEnd = shapeEndPoint else { return }
        let end = constrainedEnd(start: start, end: rawEnd)

        let ink: PKInk
        if #available(iOS 17.0, *) {
            ink = PKInk(.monoline, color: currentColor)
        } else {
            ink = PKInk(.marker, color: currentColor)
        }

        var strokePoints: [PKStrokePoint] = []
        let pointSize = CGSize(width: brushWidth, height: brushWidth)

        func addPoint(_ pt: CGPoint, time: Double) {
            strokePoints.append(PKStrokePoint(location: pt, timeOffset: time, size: pointSize,
                                               opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2))
        }

        switch currentShapeKind {
        case .line:
            addPoint(start, time: 0)
            addPoint(end, time: 0.1)

        case .rectangle, .square:
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                              width: abs(end.x - start.x), height: abs(end.y - start.y))
            let pts = 20
            var time: Double = 0
            // Top
            for i in 0...pts {
                let t = CGFloat(i) / CGFloat(pts)
                addPoint(CGPoint(x: rect.minX + rect.width * t, y: rect.minY), time: time)
                time += 0.005
            }
            // Right
            for i in 1...pts {
                let t = CGFloat(i) / CGFloat(pts)
                addPoint(CGPoint(x: rect.maxX, y: rect.minY + rect.height * t), time: time)
                time += 0.005
            }
            // Bottom
            for i in 1...pts {
                let t = CGFloat(i) / CGFloat(pts)
                addPoint(CGPoint(x: rect.maxX - rect.width * t, y: rect.maxY), time: time)
                time += 0.005
            }
            // Left
            for i in 1...pts {
                let t = CGFloat(i) / CGFloat(pts)
                addPoint(CGPoint(x: rect.minX, y: rect.maxY - rect.height * t), time: time)
                time += 0.005
            }

        case .oval, .circle:
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                              width: abs(end.x - start.x), height: abs(end.y - start.y))
            let cx = rect.midX
            let cy = rect.midY
            let rx = rect.width / 2
            let ry = rect.height / 2
            let segments = 40
            for i in 0...segments {
                let angle = CGFloat(i) / CGFloat(segments) * 2 * .pi
                let x = cx + rx * cos(angle)
                let y = cy + ry * sin(angle)
                addPoint(CGPoint(x: x, y: y), time: Double(i) * 0.01)
            }

        case .star:
            let cx = (start.x + end.x) / 2
            let cy = (start.y + end.y) / 2
            let outerRadius = max(abs(end.x - start.x), abs(end.y - start.y)) / 2
            let innerRadius = outerRadius * 0.4

            // Calculate all 10 vertices first (5 outer, 5 inner alternating)
            var vertices: [CGPoint] = []
            for i in 0..<10 {
                let angle = CGFloat(i) * .pi / 5.0 - .pi / 2.0
                let radius = (i % 2 == 0) ? outerRadius : innerRadius
                let x = cx + radius * cos(angle)
                let y = cy + radius * sin(angle)
                vertices.append(CGPoint(x: x, y: y))
            }

            // Draw edges with many intermediate points (crisp lines, no curves)
            let ptsPerEdge = 15
            var time: Double = 0
            for i in 0..<10 {
                let p1 = vertices[i]
                let p2 = vertices[(i + 1) % 10]
                for j in 0...ptsPerEdge {
                    let t = CGFloat(j) / CGFloat(ptsPerEdge)
                    let x = p1.x + (p2.x - p1.x) * t
                    let y = p1.y + (p2.y - p1.y) * t
                    addPoint(CGPoint(x: x, y: y), time: time)
                    time += 0.005
                }
            }
        }

        guard strokePoints.count >= 2 else { return }

        let strokePath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        let stroke = PKStroke(ink: ink, path: strokePath)

        var currentDrawing = pkCanvasView.drawing
        currentDrawing.strokes.append(stroke)
        pkCanvasView.drawing = currentDrawing

        delegate?.canvasDidChange()
    }

    // MARK: - Undo/Redo

    func performUndo() {
        pkCanvasView.undoManager?.undo()
    }

    func performRedo() {
        pkCanvasView.undoManager?.redo()
    }

    var canUndo: Bool {
        pkCanvasView.undoManager?.canUndo ?? false
    }

    var canRedo: Bool {
        pkCanvasView.undoManager?.canRedo ?? false
    }

    @objc private func handleThreeFingerSwipeLeft() {
        performUndo()
    }

    @objc private func handleThreeFingerSwipeRight() {
        performRedo()
    }

    // MARK: - PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        delegate?.canvasDidChange()
    }

    // MARK: - Canvas Operations

    func clearCanvas() {
        pkCanvasView.drawing = PKDrawing()
    }

    func renderImage(scale: CGFloat = 1.0) -> UIImage? {
        let rect = CGRect(origin: .zero, size: CGSize(width: canvasSize, height: canvasSize))
        return pkCanvasView.drawing.image(from: rect, scale: scale)
    }

    // MARK: - Zoom

    func zoomIn() {
        let newScale = min(scrollView.zoomScale * 1.5, scrollView.maximumZoomScale)
        scrollView.setZoomScale(newScale, animated: true)
    }

    func zoomOut() {
        let newScale = max(scrollView.zoomScale / 1.5, scrollView.minimumZoomScale)
        scrollView.setZoomScale(newScale, animated: true)
    }

    func resetZoom() {
        scrollView.setZoomScale(1.0, animated: true)
    }

    func changeCanvasSize(_ newSize: CGFloat) {
        canvasSize = newSize
        contentWidthConstraint?.constant = newSize
        contentHeightConstraint?.constant = newSize
        shapePreviewLayer.frame = CGRect(x: 0, y: 0, width: newSize, height: newSize)
        scrollView.contentSize = CGSize(width: newSize, height: newSize)
        checkerboardView.backgroundColor = buildCheckerPattern()
        layoutIfNeeded()
        centerContent()
    }

    func getCanvasSize() -> CGFloat {
        return canvasSize
    }
}

// MARK: - UIImage Color Sampling Extension

private extension UIImage {
    func pixelColor(at point: CGPoint) -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        guard point.x >= 0, point.x < CGFloat(width),
              point.y >= 0, point.y < CGFloat(height) else { return nil }

        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data else { return nil }

        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        let pixelIndex = Int(point.y) * bytesPerRow + Int(point.x) * bytesPerPixel

        let r = CGFloat(data[pixelIndex]) / 255.0
        let g = CGFloat(data[pixelIndex + 1]) / 255.0
        let b = CGFloat(data[pixelIndex + 2]) / 255.0
        let a = CGFloat(data[pixelIndex + 3]) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
