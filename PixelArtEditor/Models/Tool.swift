import Foundation

enum CanvasMode: String, CaseIterable {
    case pixel
    case smooth
}

enum ShapeKind: String, CaseIterable, Identifiable {
    case line
    case rectangle
    case square
    case circle
    case oval
    case star

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .square: return "square"
        case .circle: return "circle"
        case .oval: return "oval"
        case .star: return "star"
        }
    }

    var displayName: String {
        switch self {
        case .line: return "Line"
        case .rectangle: return "Rectangle"
        case .square: return "Square"
        case .circle: return "Circle"
        case .oval: return "Oval"
        case .star: return "Star"
        }
    }
}

enum Tool: String, CaseIterable, Identifiable {
    case pencil
    case eraser
    case fill
    case eyedropper
    case shape
    case select

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .pencil: return "pencil"
        case .eraser: return "eraser"
        case .fill: return "paintbrush.pointed.fill"
        case .eyedropper: return "eyedropper"
        case .shape: return "square.on.circle"
        case .select: return "rectangle.dashed"
        }
    }

    var displayName: String {
        switch self {
        case .pencil: return "Pencil"
        case .eraser: return "Eraser"
        case .fill: return "Fill"
        case .eyedropper: return "Eyedropper"
        case .shape: return "Shape"
        case .select: return "Select"
        }
    }
}
