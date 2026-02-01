import UIKit

struct PixelGrid {
    let width: Int
    let height: Int
    private(set) var pixels: [[UIColor?]]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: Array(repeating: nil as UIColor?, count: width), count: height)
    }

    subscript(row: Int, col: Int) -> UIColor? {
        get {
            guard row >= 0, row < height, col >= 0, col < width else { return nil }
            return pixels[row][col]
        }
        set {
            guard row >= 0, row < height, col >= 0, col < width else { return }
            pixels[row][col] = newValue
        }
    }

    mutating func clear() {
        pixels = Array(repeating: Array(repeating: nil as UIColor?, count: width), count: height)
    }

    func colorAt(_ row: Int, _ col: Int) -> UIColor? {
        return self[row, col]
    }
}
