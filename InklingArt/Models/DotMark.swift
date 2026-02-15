import UIKit

/// Represents a single dot in the pointillism canvas
struct DotMark: Codable, Equatable {
    var center: CGPoint
    var radius: CGFloat
    var color: UIColor

    // Codable conformance for UIColor
    enum CodingKeys: String, CodingKey {
        case center, radius, colorData
    }

    init(center: CGPoint, radius: CGFloat, color: UIColor) {
        self.center = center
        self.radius = radius
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        center = try container.decode(CGPoint.self, forKey: .center)
        radius = try container.decode(CGFloat.self, forKey: .radius)
        let colorData = try container.decode(Data.self, forKey: .colorData)
        color = (try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData)) ?? .black
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(center, forKey: .center)
        try container.encode(radius, forKey: .radius)
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        try container.encode(colorData, forKey: .colorData)
    }
}

/// Canvas for pointillism-style dot art
class DotCanvas: Codable {
    private(set) var dots: [DotMark] = []
    private var undoStack: [[DotMark]] = []
    private var redoStack: [[DotMark]] = []

    init() {}

    // MARK: - Dot Operations

    func addDot(_ dot: DotMark) {
        saveStateForUndo()
        dots.append(dot)
    }

    func removeDot(at index: Int) {
        guard index >= 0, index < dots.count else { return }
        saveStateForUndo()
        dots.remove(at: index)
    }

    func removeDotsNear(point: CGPoint, radius: CGFloat) -> Int {
        let indicesToRemove = dots.enumerated().compactMap { index, dot -> Int? in
            let distance = hypot(dot.center.x - point.x, dot.center.y - point.y)
            return distance <= (dot.radius + radius) ? index : nil
        }

        guard !indicesToRemove.isEmpty else { return 0 }

        saveStateForUndo()
        for index in indicesToRemove.reversed() {
            dots.remove(at: index)
        }
        return indicesToRemove.count
    }

    func clear() {
        saveStateForUndo()
        dots.removeAll()
    }

    // MARK: - Hit Testing

    func dotAt(point: CGPoint, tolerance: CGFloat = 20) -> Int? {
        // Find closest dot within tolerance
        var closestIndex: Int?
        var closestDistance: CGFloat = tolerance

        for (index, dot) in dots.enumerated().reversed() {
            let distance = hypot(dot.center.x - point.x, dot.center.y - point.y)
            if distance <= dot.radius + tolerance && distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }

        return closestIndex
    }

    // MARK: - Undo/Redo

    private func saveStateForUndo() {
        undoStack.append(dots)
        redoStack.removeAll()

        // Limit undo stack to 50 states
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(dots)
        dots = previousState
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(dots)
        dots = nextState
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    // MARK: - Rendering

    func render(in context: CGContext, size: CGSize) {
        for dot in dots {
            context.setFillColor(dot.color.cgColor)
            let rect = CGRect(
                x: dot.center.x - dot.radius,
                y: dot.center.y - dot.radius,
                width: dot.radius * 2,
                height: dot.radius * 2
            )
            context.fillEllipse(in: rect)
        }
    }

    func renderToImage(size: CGSize, scale: CGFloat = 1.0) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            render(in: context.cgContext, size: size)
        }
    }
}
