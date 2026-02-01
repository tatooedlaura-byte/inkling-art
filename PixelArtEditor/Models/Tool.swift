import Foundation

enum Tool: String, CaseIterable, Identifiable {
    case pencil
    case eraser
    case fill
    case eyedropper
    case line

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .pencil: return "pencil"
        case .eraser: return "eraser"
        case .fill: return "drop.fill"
        case .eyedropper: return "eyedropper"
        case .line: return "line.diagonal"
        }
    }

    var displayName: String {
        switch self {
        case .pencil: return "Pencil"
        case .eraser: return "Eraser"
        case .fill: return "Fill"
        case .eyedropper: return "Eyedropper"
        case .line: return "Line"
        }
    }
}
