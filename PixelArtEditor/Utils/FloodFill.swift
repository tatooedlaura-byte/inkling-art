import UIKit

enum FloodFill {
    static func fill(grid: inout PixelGrid, row: Int, col: Int, newColor: UIColor) {
        let targetColor = grid[row, col]
        if colorsEqual(targetColor, newColor) { return }

        var stack: [(Int, Int)] = [(row, col)]
        while let (r, c) = stack.popLast() {
            guard r >= 0, r < grid.height, c >= 0, c < grid.width else { continue }
            guard colorsEqual(grid[r, c], targetColor) else { continue }

            grid[r, c] = newColor
            stack.append((r - 1, c))
            stack.append((r + 1, c))
            stack.append((r, c - 1))
            stack.append((r, c + 1))
        }
    }

    private static func colorsEqual(_ a: UIColor?, _ b: UIColor?) -> Bool {
        if a == nil && b == nil { return true }
        guard let a = a, let b = b else { return false }
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let eps: CGFloat = 0.01
        return abs(r1 - r2) < eps && abs(g1 - g2) < eps && abs(b1 - b2) < eps && abs(a1 - a2) < eps
    }
}
