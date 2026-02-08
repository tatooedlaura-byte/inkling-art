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
    private var shapeConfirmTapGesture: UITapGestureRecognizer!
    private var shapePendingCommit = false
    private var isMovingShape = false
    private var lastPanLocation: CGPoint?
    private var eyedropperTapGesture: UITapGestureRecognizer!

    // Selection tool state
    private var selectionPanGesture: UIPanGestureRecognizer!
    private var selectionTapGesture: UITapGestureRecognizer!
    private let selectionPreviewLayer = CAShapeLayer()
    private var selectionStartPoint: CGPoint?
    private var selectionEndPoint: CGPoint?
    private var selectionRect: CGRect?
    private var selectedStrokeIndices: [Int] = []
    private var hasActiveSelection = false
    private var isMovingSelection = false
    private var movingStrokeIndices: [Int] = []
    private var lastSelectionPanLocation: CGPoint?
    private var flipButton: UIButton!

    // Reference image
    private let referenceImageView = UIImageView()

    // Layer compositing
    private let belowLayersImageView = UIImageView()
    private let aboveLayersImageView = UIImageView()

    // Shape recognition
    var shapeRecognitionEnabled: Bool = false
    private var recognizedShape: RecognizedShape?
    private var recognizedShapePendingCommit = false
    private var isResizingShape = false
    private var activeResizeHandle: ResizeHandle?
    private var resizeAnchorPoint: CGPoint?
    private var resizeOriginalRect: CGRect?
    private var recognizedShapeRect: CGRect?
    private let resizeHandleLayer = ResizeHandleLayer()
    private var recognizedShapePanGesture: UIPanGestureRecognizer!
    private var recognizedShapeTapGesture: UITapGestureRecognizer!
    private var lastRecognizedStrokeCount = 0
    private var drawingBeforeRecognition: PKDrawing?

    var drawing: PKDrawing {
        get { pkCanvasView.drawing }
        set {
            pkCanvasView.drawing = newValue
        }
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
            if shapePendingCommit {
                commitShape()
                clearShapePendingState()
            }
            if hasActiveSelection {
                clearSelection()
            }
            if recognizedShapePendingCommit {
                commitRecognizedShape()
            }
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

        // Below layers (rendered beneath active layer)
        contentView.addSubview(belowLayersImageView)
        belowLayersImageView.contentMode = .scaleToFill
        belowLayersImageView.backgroundColor = .clear
        belowLayersImageView.isOpaque = false
        belowLayersImageView.translatesAutoresizingMaskIntoConstraints = false

        // PencilKit canvas
        contentView.addSubview(pkCanvasView)
        pkCanvasView.delegate = self
        pkCanvasView.backgroundColor = .clear
        pkCanvasView.isOpaque = false
        pkCanvasView.drawingPolicy = .anyInput
        pkCanvasView.translatesAutoresizingMaskIntoConstraints = false
        pkCanvasView.isScrollEnabled = false
        pkCanvasView.overrideUserInterfaceStyle = .light

        // Above layers (rendered above active layer)
        contentView.addSubview(aboveLayersImageView)
        aboveLayersImageView.contentMode = .scaleToFill
        aboveLayersImageView.backgroundColor = .clear
        aboveLayersImageView.isOpaque = false
        aboveLayersImageView.isUserInteractionEnabled = false
        aboveLayersImageView.translatesAutoresizingMaskIntoConstraints = false

        // Shape preview layer
        shapePreviewLayer.fillColor = nil
        shapePreviewLayer.lineCap = .round
        shapePreviewLayer.frame = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
        contentView.layer.addSublayer(shapePreviewLayer)

        // Selection preview layer
        selectionPreviewLayer.strokeColor = UIColor.systemBlue.cgColor
        selectionPreviewLayer.lineWidth = 2
        selectionPreviewLayer.lineDashPattern = [6, 4]
        selectionPreviewLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.08).cgColor
        selectionPreviewLayer.frame = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
        contentView.layer.addSublayer(selectionPreviewLayer)

        // Shape tool gesture
        shapePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleShapePan(_:)))
        shapePanGesture.isEnabled = false
        shapePanGesture.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(shapePanGesture)

        // Shape confirm tap gesture
        shapeConfirmTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleShapeConfirmTap(_:)))
        shapeConfirmTapGesture.isEnabled = false
        scrollView.addGestureRecognizer(shapeConfirmTapGesture)

        // Eyedropper tap gesture
        eyedropperTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleEyedropperTap(_:)))
        eyedropperTapGesture.isEnabled = false
        scrollView.addGestureRecognizer(eyedropperTapGesture)

        // Selection pan gesture
        selectionPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSelectionPan(_:)))
        selectionPanGesture.isEnabled = false
        selectionPanGesture.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(selectionPanGesture)

        // Selection tap gesture (tap outside to deselect)
        selectionTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSelectionTap(_:)))
        selectionTapGesture.isEnabled = false
        scrollView.addGestureRecognizer(selectionTapGesture)

        // Resize handle layer (for shape recognition)
        resizeHandleLayer.frame = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
        resizeHandleLayer.isHidden = true
        contentView.layer.addSublayer(resizeHandleLayer)

        // Shape recognition gestures (disabled by default)
        recognizedShapePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleRecognizedShapePan(_:)))
        recognizedShapePanGesture.isEnabled = false
        recognizedShapePanGesture.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(recognizedShapePanGesture)

        recognizedShapeTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleRecognizedShapeTap(_:)))
        recognizedShapeTapGesture.isEnabled = false
        scrollView.addGestureRecognizer(recognizedShapeTapGesture)

        // Flip button
        flipButton = UIButton(type: .system)
        flipButton.setTitle("Flip", for: .normal)
        flipButton.setImage(UIImage(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right"), for: .normal)
        flipButton.backgroundColor = UIColor.systemBlue
        flipButton.setTitleColor(.white, for: .normal)
        flipButton.tintColor = .white
        flipButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        flipButton.layer.cornerRadius = 8
        flipButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        flipButton.addTarget(self, action: #selector(flipButtonTapped), for: .touchUpInside)
        flipButton.isHidden = true
        contentView.addSubview(flipButton)

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

            belowLayersImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            belowLayersImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            belowLayersImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            belowLayersImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            pkCanvasView.topAnchor.constraint(equalTo: contentView.topAnchor),
            pkCanvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pkCanvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pkCanvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            aboveLayersImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            aboveLayersImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            aboveLayersImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            aboveLayersImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
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
            shapeConfirmTapGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = false
            selectionPanGesture.isEnabled = false
            selectionTapGesture.isEnabled = false

        case .eraser:
            pkCanvasView.tool = PKEraserTool(.vector)
            pkCanvasView.isUserInteractionEnabled = true
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
            shapePanGesture.isEnabled = false
            shapeConfirmTapGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = false
            selectionPanGesture.isEnabled = false
            selectionTapGesture.isEnabled = false

        case .fill:
            // Fill not supported in smooth mode (only pixel mode)
            pkCanvasView.isUserInteractionEnabled = false
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
            shapePanGesture.isEnabled = false
            shapeConfirmTapGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = false
            selectionPanGesture.isEnabled = false
            selectionTapGesture.isEnabled = false

        case .eyedropper:
            pkCanvasView.isUserInteractionEnabled = false
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
            shapePanGesture.isEnabled = false
            shapeConfirmTapGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = true
            selectionPanGesture.isEnabled = false
            selectionTapGesture.isEnabled = false

        case .shape:
            pkCanvasView.isUserInteractionEnabled = false
            scrollView.isScrollEnabled = false
            scrollView.pinchGestureRecognizer?.isEnabled = false
            shapePanGesture.isEnabled = true
            shapeConfirmTapGesture.isEnabled = true
            eyedropperTapGesture.isEnabled = false
            selectionPanGesture.isEnabled = false
            selectionTapGesture.isEnabled = false

        case .select:
            pkCanvasView.isUserInteractionEnabled = false
            scrollView.isScrollEnabled = false
            scrollView.pinchGestureRecognizer?.isEnabled = false
            shapePanGesture.isEnabled = false
            shapeConfirmTapGesture.isEnabled = false
            eyedropperTapGesture.isEnabled = false
            selectionPanGesture.isEnabled = true
            selectionTapGesture.isEnabled = true
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

    // MARK: - Shape Tool

    @objc private func handleShapePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: contentView)

        switch gesture.state {
        case .began:
            if shapePendingCommit, isPointNearShape(location) {
                // Start moving the pending shape
                isMovingShape = true
                lastPanLocation = location
            } else {
                // Commit any pending shape, then start drawing a new one
                if shapePendingCommit {
                    commitShape()
                    clearShapePendingState()
                }
                shapeStartPoint = location
                shapeEndPoint = location
                isDrawingShape = true
                isMovingShape = false
                updateShapePreview()
            }

        case .changed:
            if isMovingShape, let last = lastPanLocation,
               let start = shapeStartPoint, let end = shapeEndPoint {
                let dx = location.x - last.x
                let dy = location.y - last.y
                shapeStartPoint = CGPoint(x: start.x + dx, y: start.y + dy)
                shapeEndPoint = CGPoint(x: end.x + dx, y: end.y + dy)
                lastPanLocation = location
                updateShapePreview()
            } else {
                shapeEndPoint = location
                updateShapePreview()
            }

        case .ended:
            if isMovingShape {
                // Finished moving — keep as pending
                isMovingShape = false
                lastPanLocation = nil
            } else {
                // Finished drawing — enter pending state
                shapeEndPoint = location
                updateShapePreview()
                isDrawingShape = false
                shapePendingCommit = true
            }

        case .cancelled, .failed:
            if isMovingShape {
                isMovingShape = false
                lastPanLocation = nil
            } else {
                isDrawingShape = false
                shapePreviewLayer.path = nil
                clearShapePendingState()
            }

        default:
            break
        }
    }

    @objc private func handleShapeConfirmTap(_ gesture: UITapGestureRecognizer) {
        guard shapePendingCommit else { return }
        commitShape()
        clearShapePendingState()
    }

    private func clearShapePendingState() {
        shapePendingCommit = false
        isMovingShape = false
        lastPanLocation = nil
        shapePreviewLayer.path = nil
    }

    private func shapeBoundingBox() -> CGRect? {
        guard let start = shapeStartPoint, let end = shapeEndPoint else { return nil }
        let constrained = constrainedEnd(start: start, end: end)
        return CGRect(x: min(start.x, constrained.x),
                      y: min(start.y, constrained.y),
                      width: abs(constrained.x - start.x),
                      height: abs(constrained.y - start.y))
    }

    private func isPointNearShape(_ point: CGPoint) -> Bool {
        guard let bbox = shapeBoundingBox() else { return false }
        let padding: CGFloat = 30
        return bbox.insetBy(dx: -padding, dy: -padding).contains(point)
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

        var newDrawing = pkCanvasView.drawing
        newDrawing.strokes.append(stroke)
        setDrawingWithUndo(newDrawing)

        delegate?.canvasDidChange()
    }

    // MARK: - Selection Tool

    @objc private func handleSelectionPan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: contentView)

        switch gesture.state {
        case .began:
            if hasActiveSelection, let rect = selectionRect, rect.insetBy(dx: -30, dy: -30).contains(location) {
                // Start moving the selected strokes
                isMovingSelection = true
                movingStrokeIndices = selectedStrokeIndices
                lastSelectionPanLocation = location
            } else if isMovingSelection, let rect = selectionRect, rect.insetBy(dx: -30, dy: -30).contains(location) {
                // Continue moving
                lastSelectionPanLocation = location
            } else if isMovingSelection {
                // Started dragging outside — finalize move, start new selection
                finalizeMove()
                selectionStartPoint = location
                selectionEndPoint = location
            } else if hasActiveSelection {
                // Has selection but tapped outside - clear and start new
                clearSelection()
                selectionStartPoint = location
                selectionEndPoint = location
            } else {
                // No selection - start new selection
                clearSelection()
                selectionStartPoint = location
                selectionEndPoint = location
            }

        case .changed:
            if isMovingSelection, let last = lastSelectionPanLocation {
                let dx = location.x - last.x
                let dy = location.y - last.y
                moveSelectedStrokes(dx: dx, dy: dy)
                lastSelectionPanLocation = location
            } else {
                selectionEndPoint = location
                updateSelectionPreview()
            }

        case .ended:
            if isMovingSelection {
                lastSelectionPanLocation = nil
                // Keep selection active and flip button visible
            } else {
                selectionEndPoint = location
                updateSelectionPreview()
                finalizeSelection()
            }

        case .cancelled, .failed:
            if isMovingSelection {
                lastSelectionPanLocation = nil
            } else {
                clearSelection()
            }

        default:
            break
        }
    }

    @objc private func handleSelectionTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: contentView)

        if hasActiveSelection || isMovingSelection {
            if let rect = selectionRect, !rect.insetBy(dx: -30, dy: -30).contains(location) {
                // Tapped outside selection - finalize and clear
                if isMovingSelection {
                    finalizeMove()
                } else {
                    clearSelection()
                }
            }
        }
    }

    @objc private func flipButtonTapped() {
        flipSelectionHorizontally()
    }

    private func updateSelectionPreview() {
        guard let start = selectionStartPoint, let end = selectionEndPoint else { return }
        let rect = CGRect(x: min(start.x, end.x),
                          y: min(start.y, end.y),
                          width: abs(end.x - start.x),
                          height: abs(end.y - start.y))
        selectionPreviewLayer.path = UIBezierPath(rect: rect).cgPath
    }

    private func finalizeSelection() {
        guard let start = selectionStartPoint, let end = selectionEndPoint else {
            clearSelection()
            return
        }

        let rect = CGRect(x: min(start.x, end.x),
                          y: min(start.y, end.y),
                          width: abs(end.x - start.x),
                          height: abs(end.y - start.y))

        // Skip tiny rects (accidental drags)
        guard rect.width >= 10, rect.height >= 10 else {
            clearSelection()
            return
        }

        selectionRect = rect

        // Find strokes inside the selection
        let strokes = pkCanvasView.drawing.strokes
        var indices: [Int] = []

        for (index, stroke) in strokes.enumerated() {
            let bounds = stroke.renderBounds
            // Check if stroke bounds are fully contained or intersect with any control point inside
            if rect.contains(bounds) {
                indices.append(index)
            } else if rect.intersects(bounds) {
                // Check if any control point is inside the selection
                var hasPointInside = false
                for point in stroke.path {
                    if rect.contains(point.location) {
                        hasPointInside = true
                        break
                    }
                }
                if hasPointInside {
                    indices.append(index)
                }
            }
        }

        if indices.isEmpty {
            clearSelection()
            return
        }

        selectedStrokeIndices = indices
        hasActiveSelection = true
        showFlipButton(below: rect)
    }

    private func showFlipButton(below rect: CGRect) {
        flipButton.isHidden = false
        flipButton.sizeToFit()
        let buttonWidth = flipButton.frame.width
        let buttonX = rect.midX - buttonWidth / 2
        let buttonY = rect.maxY + 12
        flipButton.frame = CGRect(x: buttonX, y: buttonY, width: buttonWidth, height: flipButton.frame.height)
    }

    private func clearSelection() {
        selectionPreviewLayer.path = nil
        selectionStartPoint = nil
        selectionEndPoint = nil
        selectionRect = nil
        selectedStrokeIndices = []
        hasActiveSelection = false
        isMovingSelection = false
        movingStrokeIndices = []
        lastSelectionPanLocation = nil
        flipButton.isHidden = true
    }

    private func flipSelectionHorizontally() {
        guard let rect = selectionRect, !selectedStrokeIndices.isEmpty else { return }

        let midX = rect.midX
        var newDrawing = pkCanvasView.drawing
        var newIndices: [Int] = []

        // Create flipped copies of selected strokes, keeping originals
        for index in selectedStrokeIndices {
            guard index < newDrawing.strokes.count else { continue }
            let stroke = newDrawing.strokes[index]

            var flippedPoints: [PKStrokePoint] = []
            for point in stroke.path {
                let flippedX = 2 * midX - point.location.x
                let flippedLocation = CGPoint(x: flippedX, y: point.location.y)
                let flippedPoint = PKStrokePoint(
                    location: flippedLocation,
                    timeOffset: point.timeOffset,
                    size: point.size,
                    opacity: point.opacity,
                    force: point.force,
                    azimuth: point.azimuth,
                    altitude: point.altitude
                )
                flippedPoints.append(flippedPoint)
            }

            guard flippedPoints.count >= 2 else { continue }

            let newPath = PKStrokePath(controlPoints: flippedPoints, creationDate: Date())
            let flippedStroke = PKStroke(ink: stroke.ink, path: newPath)
            newIndices.append(newDrawing.strokes.count)
            newDrawing.strokes.append(flippedStroke)
        }

        setDrawingWithUndo(newDrawing)
        delegate?.canvasDidChange()

        // Update selection to the new flipped copies, keep flip button visible
        selectedStrokeIndices = newIndices
        movingStrokeIndices = newIndices
        isMovingSelection = true
        // Keep flip button visible so user can flip again
        updateMovingSelectionPreview()
    }

    private func moveSelectedStrokes(dx: CGFloat, dy: CGFloat) {
        let offset = CGVector(dx: dx, dy: dy)
        var newDrawing = pkCanvasView.drawing

        for index in movingStrokeIndices {
            guard index < newDrawing.strokes.count else { continue }
            let stroke = newDrawing.strokes[index]

            var movedPoints: [PKStrokePoint] = []
            for point in stroke.path {
                let movedLocation = CGPoint(x: point.location.x + offset.dx, y: point.location.y + offset.dy)
                let movedPoint = PKStrokePoint(
                    location: movedLocation,
                    timeOffset: point.timeOffset,
                    size: point.size,
                    opacity: point.opacity,
                    force: point.force,
                    azimuth: point.azimuth,
                    altitude: point.altitude
                )
                movedPoints.append(movedPoint)
            }

            guard movedPoints.count >= 2 else { continue }

            let newPath = PKStrokePath(controlPoints: movedPoints, creationDate: Date())
            let movedStroke = PKStroke(ink: stroke.ink, path: newPath)
            newDrawing.strokes[index] = movedStroke
        }

        // Shift selection rect too
        if let rect = selectionRect {
            selectionRect = rect.offsetBy(dx: dx, dy: dy)
        }

        // Shift flip button too
        flipButton.frame = flipButton.frame.offsetBy(dx: dx, dy: dy)

        pkCanvasView.drawing = newDrawing
        delegate?.canvasDidChange()
        updateMovingSelectionPreview()
    }

    private func updateMovingSelectionPreview() {
        // Show dashed rect around the flipped copies
        guard let rect = selectionRect else { return }
        selectionPreviewLayer.path = UIBezierPath(rect: rect).cgPath
    }

    private func finalizeMove() {
        // Register the full change for undo (from before flip to now)
        let finalDrawing = pkCanvasView.drawing
        setDrawingWithUndo(finalDrawing)
        isMovingSelection = false
        movingStrokeIndices = []
        lastSelectionPanLocation = nil
        clearSelection()
    }

    // MARK: - Undo/Redo

    private func setDrawingWithUndo(_ newDrawing: PKDrawing) {
        let oldDrawing = pkCanvasView.drawing
        pkCanvasView.undoManager?.registerUndo(withTarget: self) { target in
            target.setDrawingWithUndo(oldDrawing)
        }
        pkCanvasView.drawing = newDrawing
    }

    func performUndo() {
        if hasActiveSelection {
            clearSelection()
            return
        }
        if shapePendingCommit {
            clearShapePendingState()
            shapeStartPoint = nil
            shapeEndPoint = nil
            return
        }
        if recognizedShapePendingCommit {
            // Cancel recognition — restore the raw stroke
            if let saved = drawingBeforeRecognition {
                pkCanvasView.drawing = saved
                drawingBeforeRecognition = nil
            }
            exitRecognizedShapeMode()
            delegate?.canvasDidChange()
            return
        }
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
        if shapeRecognitionEnabled && currentTool == .pencil && !recognizedShapePendingCommit {
            attemptShapeRecognition(canvasView)
        }
        delegate?.canvasDidChange()
    }

    // MARK: - Shape Recognition

    private func attemptShapeRecognition(_ canvasView: PKCanvasView) {
        let currentCount = canvasView.drawing.strokes.count
        guard currentCount > lastRecognizedStrokeCount else {
            lastRecognizedStrokeCount = currentCount
            return
        }

        // Get the last stroke
        let lastStroke = canvasView.drawing.strokes[currentCount - 1]
        lastRecognizedStrokeCount = currentCount

        // Extract points from the stroke
        var points: [CGPoint] = []
        for point in lastStroke.path {
            points.append(point.location)
        }

        guard let shape = ShapeRecognizer.recognize(points: points) else { return }

        // Save drawing before removing the raw stroke
        drawingBeforeRecognition = canvasView.drawing

        // Remove the raw stroke
        var newDrawing = canvasView.drawing
        newDrawing.strokes.removeLast()
        pkCanvasView.drawing = newDrawing

        // Store recognized shape and enter recognition mode
        recognizedShape = shape
        recognizedShapeRect = shape.boundingRect
        recognizedShapePendingCommit = true

        showRecognizedShapePreview()
        enterRecognizedShapeMode()
    }

    private func showRecognizedShapePreview() {
        guard let shape = recognizedShape, let rect = recognizedShapeRect else { return }

        let path: UIBezierPath

        switch shape.kind {
        case .line:
            path = UIBezierPath()
            if let start = shape.lineStart, let end = shape.lineEnd {
                let origRect = shape.boundingRect
                let scaleX = origRect.width > 1 ? rect.width / origRect.width : 1
                let scaleY = origRect.height > 1 ? rect.height / origRect.height : 1
                let newStart = CGPoint(
                    x: rect.origin.x + (start.x - origRect.origin.x) * scaleX,
                    y: rect.origin.y + (start.y - origRect.origin.y) * scaleY
                )
                let newEnd = CGPoint(
                    x: rect.origin.x + (end.x - origRect.origin.x) * scaleX,
                    y: rect.origin.y + (end.y - origRect.origin.y) * scaleY
                )
                path.move(to: newStart)
                path.addLine(to: newEnd)
            }

        case .circle:
            path = UIBezierPath(ovalIn: rect)

        case .rectangle:
            path = UIBezierPath(rect: rect)

        case .arc:
            path = UIBezierPath()
            if let center = shape.arcCenter, let radius = shape.arcRadius,
               let startAngle = shape.arcStartAngle, let endAngle = shape.arcEndAngle,
               let clockwise = shape.arcClockwise {
                let origRect = shape.boundingRect
                let scaleX = origRect.width > 1 ? rect.width / origRect.width : 1
                let scaleY = origRect.height > 1 ? rect.height / origRect.height : 1
                let newCenter = CGPoint(
                    x: rect.origin.x + (center.x - origRect.origin.x) * scaleX,
                    y: rect.origin.y + (center.y - origRect.origin.y) * scaleY
                )
                let newRadius = radius * max(scaleX, scaleY)
                path.addArc(withCenter: newCenter, radius: newRadius,
                            startAngle: startAngle, endAngle: endAngle, clockwise: !clockwise)
            }

        case .triangle:
            path = UIBezierPath()
            if let verts = shape.triangleVertices, verts.count == 3 {
                let origRect = shape.boundingRect
                let scaleX = origRect.width > 1 ? rect.width / origRect.width : 1
                let scaleY = origRect.height > 1 ? rect.height / origRect.height : 1
                let scaled = verts.map { v in
                    CGPoint(
                        x: rect.origin.x + (v.x - origRect.origin.x) * scaleX,
                        y: rect.origin.y + (v.y - origRect.origin.y) * scaleY
                    )
                }
                path.move(to: scaled[0])
                path.addLine(to: scaled[1])
                path.addLine(to: scaled[2])
                path.close()
            }
        }

        shapePreviewLayer.strokeColor = currentColor.cgColor
        shapePreviewLayer.lineWidth = brushWidth
        shapePreviewLayer.fillColor = nil
        shapePreviewLayer.path = path.cgPath

        resizeHandleLayer.update(for: rect)
    }

    private func enterRecognizedShapeMode() {
        pkCanvasView.isUserInteractionEnabled = false
        scrollView.isScrollEnabled = false
        scrollView.pinchGestureRecognizer?.isEnabled = false
        recognizedShapePanGesture.isEnabled = true
        recognizedShapeTapGesture.isEnabled = true
    }

    private func exitRecognizedShapeMode() {
        recognizedShape = nil
        recognizedShapeRect = nil
        recognizedShapePendingCommit = false
        isResizingShape = false
        activeResizeHandle = nil
        resizeAnchorPoint = nil
        resizeOriginalRect = nil
        drawingBeforeRecognition = nil

        shapePreviewLayer.path = nil
        resizeHandleLayer.hide()

        // Restore normal pencil mode
        recognizedShapePanGesture.isEnabled = false
        recognizedShapeTapGesture.isEnabled = false
        pkCanvasView.isUserInteractionEnabled = true
        scrollView.isScrollEnabled = true
        scrollView.pinchGestureRecognizer?.isEnabled = true

        lastRecognizedStrokeCount = pkCanvasView.drawing.strokes.count
    }

    @objc private func handleRecognizedShapePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: contentView)

        switch gesture.state {
        case .began:
            guard let rect = recognizedShapeRect else { return }

            // Hit-test resize handles first
            if let handle = resizeHandleLayer.hitTestHandle(point: location) {
                isResizingShape = true
                activeResizeHandle = handle
                resizeOriginalRect = rect
                return
            }

            // Hit-test shape body
            let bodyRect = rect.insetBy(dx: -30, dy: -30)
            if bodyRect.contains(location) {
                // Move mode
                isResizingShape = false
                lastPanLocation = location
                return
            }

            // Outside — commit the shape
            commitRecognizedShape()

        case .changed:
            if isResizingShape, let handle = activeResizeHandle, let origRect = resizeOriginalRect {
                let newRect = ResizeHandleLayer.adjustedRect(original: origRect, dragging: handle, from: .zero, to: location)
                recognizedShapeRect = newRect
                showRecognizedShapePreview()
            } else if let last = lastPanLocation, let rect = recognizedShapeRect {
                let dx = location.x - last.x
                let dy = location.y - last.y
                recognizedShapeRect = rect.offsetBy(dx: dx, dy: dy)
                lastPanLocation = location
                showRecognizedShapePreview()
            }

        case .ended:
            isResizingShape = false
            activeResizeHandle = nil
            resizeOriginalRect = nil
            lastPanLocation = nil

        case .cancelled, .failed:
            isResizingShape = false
            activeResizeHandle = nil
            resizeOriginalRect = nil
            lastPanLocation = nil

        default:
            break
        }
    }

    @objc private func handleRecognizedShapeTap(_ gesture: UITapGestureRecognizer) {
        guard recognizedShapePendingCommit else { return }
        commitRecognizedShape()
    }

    private func commitRecognizedShape() {
        guard let shape = recognizedShape, let rect = recognizedShapeRect else {
            exitRecognizedShapeMode()
            return
        }

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

        let origRect = shape.boundingRect
        let scaleX = origRect.width > 1 ? rect.width / origRect.width : 1
        let scaleY = origRect.height > 1 ? rect.height / origRect.height : 1

        switch shape.kind {
        case .line:
            if let start = shape.lineStart, let end = shape.lineEnd {
                let newStart = CGPoint(
                    x: rect.origin.x + (start.x - origRect.origin.x) * scaleX,
                    y: rect.origin.y + (start.y - origRect.origin.y) * scaleY
                )
                let newEnd = CGPoint(
                    x: rect.origin.x + (end.x - origRect.origin.x) * scaleX,
                    y: rect.origin.y + (end.y - origRect.origin.y) * scaleY
                )
                addPoint(newStart, time: 0)
                addPoint(newEnd, time: 0.1)
            }

        case .circle:
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

        case .rectangle:
            let pts = 20
            var time: Double = 0
            for i in 0...pts {
                let t = CGFloat(i) / CGFloat(pts)
                addPoint(CGPoint(x: rect.minX + rect.width * t, y: rect.minY), time: time)
                time += 0.005
            }
            for i in 1...pts {
                let t = CGFloat(i) / CGFloat(pts)
                addPoint(CGPoint(x: rect.maxX, y: rect.minY + rect.height * t), time: time)
                time += 0.005
            }
            for i in 1...pts {
                let t = CGFloat(i) / CGFloat(pts)
                addPoint(CGPoint(x: rect.maxX - rect.width * t, y: rect.maxY), time: time)
                time += 0.005
            }
            for i in 1...pts {
                let t = CGFloat(i) / CGFloat(pts)
                addPoint(CGPoint(x: rect.minX, y: rect.maxY - rect.height * t), time: time)
                time += 0.005
            }

        case .arc:
            if let center = shape.arcCenter, let radius = shape.arcRadius,
               let startAngle = shape.arcStartAngle, let endAngle = shape.arcEndAngle,
               let clockwise = shape.arcClockwise {
                let newCenter = CGPoint(
                    x: rect.origin.x + (center.x - origRect.origin.x) * scaleX,
                    y: rect.origin.y + (center.y - origRect.origin.y) * scaleY
                )
                let newRadius = radius * max(scaleX, scaleY)
                var sweep = clockwise ? startAngle - endAngle : endAngle - startAngle
                if sweep < 0 { sweep += 2 * .pi }
                let segments = 30
                for i in 0...segments {
                    let t = CGFloat(i) / CGFloat(segments)
                    let a = clockwise ? startAngle - t * sweep : startAngle + t * sweep
                    let x = newCenter.x + newRadius * cos(a)
                    let y = newCenter.y + newRadius * sin(a)
                    addPoint(CGPoint(x: x, y: y), time: Double(i) * 0.01)
                }
            }

        case .triangle:
            if let verts = shape.triangleVertices, verts.count == 3 {
                let scaled = verts.map { v in
                    CGPoint(
                        x: rect.origin.x + (v.x - origRect.origin.x) * scaleX,
                        y: rect.origin.y + (v.y - origRect.origin.y) * scaleY
                    )
                }
                let ptsPerEdge = 15
                var time: Double = 0
                for edge in 0..<3 {
                    let p1 = scaled[edge]
                    let p2 = scaled[(edge + 1) % 3]
                    let startJ = edge == 0 ? 0 : 1
                    for j in startJ...ptsPerEdge {
                        let t = CGFloat(j) / CGFloat(ptsPerEdge)
                        let x = p1.x + (p2.x - p1.x) * t
                        let y = p1.y + (p2.y - p1.y) * t
                        addPoint(CGPoint(x: x, y: y), time: time)
                        time += 0.005
                    }
                }
            }
        }

        guard strokePoints.count >= 2 else {
            exitRecognizedShapeMode()
            return
        }

        let strokePath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        let stroke = PKStroke(ink: ink, path: strokePath)

        var newDrawing = pkCanvasView.drawing
        newDrawing.strokes.append(stroke)
        setDrawingWithUndo(newDrawing)

        exitRecognizedShapeMode()
        delegate?.canvasDidChange()
    }

    // MARK: - Layer Support

    func clearUndoHistory() {
        pkCanvasView.undoManager?.removeAllActions()
    }

    func updateLayerComposites(layers: [DrawingLayer], activeIndex: Int) {
        let size = CGSize(width: canvasSize, height: canvasSize)
        let rect = CGRect(origin: .zero, size: size)

        // Render layers below the active layer
        let belowImage = renderLayerRange(layers: layers, range: 0..<activeIndex, rect: rect)
        belowLayersImageView.image = belowImage

        // Render layers above the active layer
        let aboveStart = activeIndex + 1
        let aboveImage = renderLayerRange(layers: layers, range: aboveStart..<layers.count, rect: rect)
        aboveLayersImageView.image = aboveImage
    }

    private func renderLayerRange(layers: [DrawingLayer], range: Range<Int>, rect: CGRect) -> UIImage? {
        guard !range.isEmpty else { return nil }
        var hasContent = false
        for i in range {
            if layers[i].isVisible { hasContent = true; break }
        }
        guard hasContent else { return nil }

        // Force light mode trait collection for consistent rendering
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)

        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { context in
            for i in range {
                let layer = layers[i]
                guard layer.isVisible else { continue }
                // Render with light mode trait collection to match canvas
                var layerImage: UIImage!
                lightTraits.performAsCurrent {
                    layerImage = layer.drawing.image(from: rect, scale: 1.0)
                }
                context.cgContext.saveGState()
                context.cgContext.setAlpha(layer.opacity)
                layerImage.draw(in: rect)
                context.cgContext.restoreGState()
            }
        }
    }

    // MARK: - Canvas Operations

    func clearCanvas() {
        pkCanvasView.drawing = PKDrawing()
    }

    func renderImage(scale: CGFloat = 1.0) -> UIImage? {
        let rect = CGRect(origin: .zero, size: CGSize(width: canvasSize, height: canvasSize))
        return pkCanvasView.drawing.image(from: rect, scale: scale)
    }

    func renderCompositeImage(layers: [DrawingLayer], activeIndex: Int, scale: CGFloat = 1.0) -> UIImage? {
        let size = CGSize(width: canvasSize, height: canvasSize)
        let rect = CGRect(origin: .zero, size: size)
        // Force light mode trait collection for consistent rendering
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize * scale, height: canvasSize * scale))
        return renderer.image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            for (i, layer) in layers.enumerated() {
                guard layer.isVisible else { continue }
                let layerDrawing: PKDrawing
                if i == activeIndex {
                    layerDrawing = pkCanvasView.drawing
                } else {
                    layerDrawing = layer.drawing
                }
                // Render with light mode trait collection to match canvas
                var layerImage: UIImage!
                lightTraits.performAsCurrent {
                    layerImage = layerDrawing.image(from: rect, scale: 1.0)
                }
                context.cgContext.saveGState()
                context.cgContext.setAlpha(layer.opacity)
                layerImage.draw(in: rect)
                context.cgContext.restoreGState()
            }
        }
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

    // MARK: - Canvas Size

    func changeCanvasSize(_ newSize: CGFloat) {
        canvasSize = newSize
        contentWidthConstraint?.constant = newSize
        contentHeightConstraint?.constant = newSize
        shapePreviewLayer.frame = CGRect(x: 0, y: 0, width: newSize, height: newSize)
        selectionPreviewLayer.frame = CGRect(x: 0, y: 0, width: newSize, height: newSize)
        resizeHandleLayer.frame = CGRect(x: 0, y: 0, width: newSize, height: newSize)
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
