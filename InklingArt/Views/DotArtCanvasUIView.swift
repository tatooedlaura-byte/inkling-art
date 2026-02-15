import UIKit

protocol DotArtCanvasDelegate: AnyObject {
    func canvasDidChange()
    func didPickColor(_ color: UIColor)
}

class DotArtCanvasUIView: UIView {
    weak var delegate: DotArtCanvasDelegate?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let canvasView = UIView()
    private let checkerboardView = UIView()

    private let canvasSize: CGFloat = 1024
    private var canvas = DotCanvas()

    // Left-hand size slider
    private let sizeSlider = UISlider()
    private let sizePreviewView = UIView()
    private var dotSize: CGFloat = 10 {
        didSet {
            updateSizePreview()
        }
    }

    // Grid snap
    var gridSnapEnabled: Bool = false
    private var gridSize: CGFloat {
        return dotSize * 2  // Grid spacing = dot diameter
    }

    // Current state
    var currentColor: UIColor = .black
    var currentTool: Tool = .pencil

    // Tap gesture
    private var tapGesture: UITapGestureRecognizer!
    private var panGesture: UIPanGestureRecognizer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .systemBackground

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

        // Canvas view (where dots are drawn)
        contentView.addSubview(canvasView)
        canvasView.backgroundColor = .clear
        canvasView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.widthAnchor.constraint(equalToConstant: canvasSize),
            contentView.heightAnchor.constraint(equalToConstant: canvasSize),

            checkerboardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            checkerboardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            checkerboardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            checkerboardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Gestures
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delaysTouchesBegan = false
        scrollView.addGestureRecognizer(tapGesture)

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        panGesture.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(panGesture)

        // Left-hand size slider
        setupSizeSlider()

        updateTool()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.contentSize = CGSize(width: canvasSize, height: canvasSize)
        centerContent()
    }

    private func centerContent() {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width * scrollView.zoomScale) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height * scrollView.zoomScale) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
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

    // MARK: - Size Slider

    private func setupSizeSlider() {
        // Vertical slider on left edge
        sizeSlider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        sizeSlider.minimumValue = 2
        sizeSlider.maximumValue = 60
        sizeSlider.value = Float(dotSize)
        sizeSlider.addTarget(self, action: #selector(sizeSliderChanged), for: .valueChanged)
        sizeSlider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sizeSlider)

        // Size preview circle
        sizePreviewView.backgroundColor = .clear
        sizePreviewView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sizePreviewView)

        NSLayoutConstraint.activate([
            sizeSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            sizeSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            sizeSlider.widthAnchor.constraint(equalToConstant: 200),

            // Position preview at bottom left, below color picker
            sizePreviewView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            sizePreviewView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -100),
            sizePreviewView.widthAnchor.constraint(equalToConstant: 80),
            sizePreviewView.heightAnchor.constraint(equalToConstant: 80),
        ])

        updateSizePreview()
    }

    @objc private func sizeSliderChanged() {
        dotSize = CGFloat(sizeSlider.value)
    }

    private func updateSizePreview() {
        sizePreviewView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let previewLayer = CAShapeLayer()
        let diameter = min(dotSize * 2, 60)
        let rect = CGRect(
            x: (80 - diameter) / 2,
            y: (80 - diameter) / 2,
            width: diameter,
            height: diameter
        )
        previewLayer.path = UIBezierPath(ovalIn: rect).cgPath
        // Always white fill with dark border so it's visible against any background
        previewLayer.fillColor = UIColor.white.cgColor
        previewLayer.strokeColor = UIColor.darkGray.cgColor
        previewLayer.lineWidth = 2
        sizePreviewView.layer.addSublayer(previewLayer)
    }

    // MARK: - Tool Management

    private func updateTool() {
        switch currentTool {
        case .pencil:
            tapGesture.isEnabled = true
            panGesture.isEnabled = true
            scrollView.isScrollEnabled = false
            scrollView.pinchGestureRecognizer?.isEnabled = false

        case .eraser:
            tapGesture.isEnabled = true
            panGesture.isEnabled = true
            scrollView.isScrollEnabled = false
            scrollView.pinchGestureRecognizer?.isEnabled = false

        case .eyedropper:
            tapGesture.isEnabled = true
            panGesture.isEnabled = false
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true

        case .fill:
            tapGesture.isEnabled = true
            panGesture.isEnabled = false
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true

        default:
            tapGesture.isEnabled = false
            panGesture.isEnabled = false
            scrollView.isScrollEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
        }

        updateSizePreview()
    }

    // MARK: - Gesture Handlers

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: canvasView)

        switch currentTool {
        case .pencil:
            placeDot(at: location)

        case .eraser:
            eraseDot(at: location)

        case .eyedropper:
            pickColor(at: location)

        case .fill:
            fillCanvas()

        default:
            break
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: canvasView)

        switch currentTool {
        case .pencil:
            placeDot(at: location)

        case .eraser:
            eraseDot(at: location)

        default:
            break
        }
    }

    // MARK: - Drawing Operations

    private func placeDot(at point: CGPoint) {
        var finalPoint = point

        // Grid snap if enabled
        if gridSnapEnabled {
            finalPoint = CGPoint(
                x: round(point.x / gridSize) * gridSize,
                y: round(point.y / gridSize) * gridSize
            )
        }

        let dot = DotMark(center: finalPoint, radius: dotSize, color: currentColor)
        canvas.addDot(dot)
        redrawCanvas()
        delegate?.canvasDidChange()
    }

    private func eraseDot(at point: CGPoint) {
        let removed = canvas.removeDotsNear(point: point, radius: dotSize)
        if removed > 0 {
            redrawCanvas()
            delegate?.canvasDidChange()
        }
    }

    private func pickColor(at point: CGPoint) {
        if let index = canvas.dotAt(point: point, tolerance: 20) {
            let dot = canvas.dots[index]
            delegate?.didPickColor(dot.color)
        }
    }

    private func fillCanvas() {
        // Fill canvas with dots at current size/color in a grid pattern
        let spacing = dotSize * 2.5
        var y: CGFloat = dotSize
        while y < canvasSize {
            var x: CGFloat = dotSize
            while x < canvasSize {
                let dot = DotMark(center: CGPoint(x: x, y: y), radius: dotSize, color: currentColor)
                canvas.addDot(dot)
                x += spacing
            }
            y += spacing
        }
        redrawCanvas()
        delegate?.canvasDidChange()
    }

    private func redrawCanvas() {
        // Render dots using Core Graphics
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize, height: canvasSize))
        let image = renderer.image { context in
            canvas.render(in: context.cgContext, size: CGSize(width: canvasSize, height: canvasSize))
        }

        canvasView.layer.contents = image.cgImage
    }

    // MARK: - Public Methods

    func clearCanvas() {
        canvas.clear()
        redrawCanvas()
        delegate?.canvasDidChange()
    }

    func performUndo() {
        canvas.undo()
        redrawCanvas()
    }

    func performRedo() {
        canvas.redo()
        redrawCanvas()
    }

    var canUndo: Bool {
        canvas.canUndo
    }

    var canRedo: Bool {
        canvas.canRedo
    }

    func renderImage(scale: CGFloat = 1.0) -> UIImage? {
        return canvas.renderToImage(size: CGSize(width: canvasSize, height: canvasSize), scale: scale)
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
}

// MARK: - UIScrollViewDelegate

extension DotArtCanvasUIView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
    }
}
