import UIKit

enum CharacterTemplates {

    private static let outline = UIColor.darkGray

    static func template(for size: Int) -> PixelGrid {
        switch size {
        case 8:  return template8()
        case 16: return template16()
        case 32: return template32()
        case 64: return template64()
        default: return PixelGrid(width: size, height: size)
        }
    }

    // MARK: - 8×8
    // Bitizen: wide rounded head, narrower body, tiny legs

    private static func template8() -> PixelGrid {
        let O = Optional(outline)
        let n: UIColor? = nil

        let data: [[UIColor?]] = [
            [n, n, n, n, n, n, n, n],
            [n, n, O, O, O, O, n, n],
            [n, O, n, n, n, n, O, n],
            [n, O, n, n, n, n, O, n],
            [n, n, O, O, O, O, n, n],
            [n, n, O, n, n, O, n, n],
            [n, n, O, n, n, O, n, n],
            [n, n, n, n, n, n, n, n],
        ]
        return gridFrom(data: data, size: 8)
    }

    // MARK: - 16×16

    private static func template16() -> PixelGrid {
        let O = Optional(outline)
        let n: UIColor? = nil

        //        0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
        let data: [[UIColor?]] = [
            [n, n, n, n, n, n, n, n, n, n, n, n, n, n, n, n],  // 0
            [n, n, n, n, n, n, n, n, n, n, n, n, n, n, n, n],  // 1
            [n, n, n, n, O, O, O, O, O, O, O, n, n, n, n, n],  // 2  hair top
            [n, n, n, O, O, O, O, O, O, O, O, O, n, n, n, n],  // 3  hair
            [n, n, O, n, n, n, n, n, n, n, n, n, O, n, n, n],  // 4  face
            [n, n, O, n, n, n, n, n, n, n, n, n, O, n, n, n],  // 5  face
            [n, n, O, n, n, n, n, n, n, n, n, n, O, n, n, n],  // 6  face
            [n, n, n, O, O, O, O, O, O, O, O, O, n, n, n, n],  // 7  chin
            [n, n, n, n, O, n, n, n, n, n, O, n, n, n, n, n],  // 8  body
            [n, n, n, n, O, n, n, n, n, n, O, n, n, n, n, n],  // 9  body
            [n, n, n, n, O, n, n, n, n, n, O, n, n, n, n, n],  // 10 body
            [n, n, n, n, O, O, O, O, O, O, O, n, n, n, n, n],  // 11 belt/waist
            [n, n, n, n, n, O, n, n, n, O, n, n, n, n, n, n],  // 12 legs
            [n, n, n, n, n, O, n, n, n, O, n, n, n, n, n, n],  // 13 legs
            [n, n, n, n, O, O, n, n, n, O, O, n, n, n, n, n],  // 14 feet
            [n, n, n, n, n, n, n, n, n, n, n, n, n, n, n, n],  // 15
        ]
        return gridFrom(data: data, size: 16)
    }

    // MARK: - 32×32

    private static func template32() -> PixelGrid {
        var grid = PixelGrid(width: 32, height: 32)

        // Hair (flat across top of head, full width)
        hLine(&grid, x: 10, y: 5, w: 12)
        hLine(&grid, x: 9, y: 6, w: 14)

        // Head (wide, rounded corners)
        // left side
        vLine(&grid, x: 8, y: 7, h: 7)
        // right side
        vLine(&grid, x: 23, y: 7, h: 7)
        // bottom of head
        hLine(&grid, x: 9, y: 14, w: 14)

        // Body (narrower than head)
        strokeRect(&grid, x: 11, y: 15, w: 10, h: 8)

        // Legs (short stubby)
        // left
        vLine(&grid, x: 12, y: 23, h: 3)
        vLine(&grid, x: 14, y: 23, h: 3)
        // right
        vLine(&grid, x: 17, y: 23, h: 3)
        vLine(&grid, x: 19, y: 23, h: 3)

        // Feet (wider than legs)
        hLine(&grid, x: 11, y: 26, w: 4)
        hLine(&grid, x: 17, y: 26, w: 4)

        return grid
    }

    // MARK: - 64×64

    private static func template64() -> PixelGrid {
        var grid = PixelGrid(width: 64, height: 64)

        // Hair (flat rows on top)
        hLine(&grid, x: 20, y: 11, w: 24)
        hLine(&grid, x: 19, y: 12, w: 26)
        hLine(&grid, x: 18, y: 13, w: 28)
        hLine(&grid, x: 17, y: 14, w: 30)

        // Head sides
        vLine(&grid, x: 16, y: 15, h: 14)
        vLine(&grid, x: 47, y: 15, h: 14)

        // Bottom of head
        hLine(&grid, x: 17, y: 29, w: 30)

        // Body (narrower)
        strokeRect(&grid, x: 22, y: 30, w: 20, h: 16)

        // Legs (short and stubby)
        // left
        vLine(&grid, x: 24, y: 46, h: 6)
        vLine(&grid, x: 25, y: 46, h: 6)
        vLine(&grid, x: 28, y: 46, h: 6)
        vLine(&grid, x: 29, y: 46, h: 6)
        // right
        vLine(&grid, x: 34, y: 46, h: 6)
        vLine(&grid, x: 35, y: 46, h: 6)
        vLine(&grid, x: 38, y: 46, h: 6)
        vLine(&grid, x: 39, y: 46, h: 6)

        // Feet
        hLine(&grid, x: 22, y: 52, w: 8)
        hLine(&grid, x: 34, y: 52, w: 8)

        return grid
    }

    // MARK: - Helpers

    private static func gridFrom(data: [[UIColor?]], size: Int) -> PixelGrid {
        var grid = PixelGrid(width: size, height: size)
        for row in 0..<min(data.count, size) {
            for col in 0..<min(data[row].count, size) {
                grid[row, col] = data[row][col]
            }
        }
        return grid
    }

    private static func strokeRect(_ grid: inout PixelGrid, x: Int, y: Int, w: Int, h: Int) {
        for col in x..<(x + w) {
            grid[y, col] = outline
            grid[y + h - 1, col] = outline
        }
        for row in y..<(y + h) {
            grid[row, x] = outline
            grid[row, x + w - 1] = outline
        }
    }

    private static func hLine(_ grid: inout PixelGrid, x: Int, y: Int, w: Int) {
        for col in x..<(x + w) {
            grid[y, col] = outline
        }
    }

    private static func vLine(_ grid: inout PixelGrid, x: Int, y: Int, h: Int) {
        for row in y..<(y + h) {
            grid[row, x] = outline
        }
    }
}
