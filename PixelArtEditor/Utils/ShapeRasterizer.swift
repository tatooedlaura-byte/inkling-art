import Foundation

enum ShapeRasterizer {

    /// Bresenham line from (r0,c0) to (r1,c1). Returns [(row, col)].
    static func line(r0: Int, c0: Int, r1: Int, c1: Int) -> [(Int, Int)] {
        var points: [(Int, Int)] = []
        var x0 = c0, y0 = r0, x1 = c1, y1 = r1
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            points.append((y0, x0))
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
        return points
    }

    /// Rectangle outline or filled between two corner points.
    static func rectangle(r0: Int, c0: Int, r1: Int, c1: Int, filled: Bool) -> [(Int, Int)] {
        let minR = min(r0, r1), maxR = max(r0, r1)
        let minC = min(c0, c1), maxC = max(c0, c1)
        var points: [(Int, Int)] = []
        if filled {
            for r in minR...maxR {
                for c in minC...maxC {
                    points.append((r, c))
                }
            }
        } else {
            for c in minC...maxC {
                points.append((minR, c))
                points.append((maxR, c))
            }
            if minR + 1 < maxR {
                for r in (minR + 1)..<maxR {
                    points.append((r, minC))
                    points.append((r, maxC))
                }
            }
        }
        return points
    }

    /// Square: constrained to equal width/height using the smaller dimension.
    static func square(r0: Int, c0: Int, r1: Int, c1: Int, filled: Bool) -> [(Int, Int)] {
        let dr = r1 - r0
        let dc = c1 - c0
        let side = min(abs(dr), abs(dc))
        let adjR1 = r0 + (dr >= 0 ? side : -side)
        let adjC1 = c0 + (dc >= 0 ? side : -side)
        return rectangle(r0: r0, c0: c0, r1: adjR1, c1: adjC1, filled: filled)
    }

    /// Ellipse (oval) rasterization.
    static func oval(r0: Int, c0: Int, r1: Int, c1: Int, filled: Bool) -> [(Int, Int)] {
        let minR = min(r0, r1), maxR = max(r0, r1)
        let minC = min(c0, c1), maxC = max(c0, c1)
        let cx = Double(minC + maxC) / 2.0
        let cy = Double(minR + maxR) / 2.0
        let a = Double(maxC - minC) / 2.0
        let b = Double(maxR - minR) / 2.0

        guard a > 0 && b > 0 else {
            return line(r0: r0, c0: c0, r1: r1, c1: c1)
        }

        var points: [(Int, Int)] = []

        if filled {
            for r in minR...maxR {
                let dy = Double(r) - cy
                let term = 1.0 - (dy * dy) / (b * b)
                if term < 0 { continue }
                let xSpan = a * term.squareRoot()
                let cLeft = Int((cx - xSpan).rounded(.up))
                let cRight = Int((cx + xSpan).rounded(.down))
                guard cLeft <= cRight else { continue }
                for c in cLeft...cRight {
                    points.append((r, c))
                }
            }
        } else {
            let steps = max(200, Int((a + b) * 4))
            for i in 0..<steps {
                let t = Double(i) / Double(steps) * 2.0 * .pi
                let px = cx + a * cos(t)
                let py = cy + b * sin(t)
                points.append((Int(py.rounded()), Int(px.rounded())))
            }
        }

        return points
    }

    /// Circle: constrained to square bounding box.
    static func circle(r0: Int, c0: Int, r1: Int, c1: Int, filled: Bool) -> [(Int, Int)] {
        let dr = r1 - r0
        let dc = c1 - c0
        let side = min(abs(dr), abs(dc))
        let adjR1 = r0 + (dr >= 0 ? side : -side)
        let adjC1 = c0 + (dc >= 0 ? side : -side)
        return oval(r0: r0, c0: c0, r1: adjR1, c1: adjC1, filled: filled)
    }

    /// 5-pointed star outline or filled.
    static func star(r0: Int, c0: Int, r1: Int, c1: Int, filled: Bool) -> [(Int, Int)] {
        let minR = Double(min(r0, r1)), maxR = Double(max(r0, r1))
        let minC = Double(min(c0, c1)), maxC = Double(max(c0, c1))
        let cx = (minC + maxC) / 2.0
        let cy = (minR + maxR) / 2.0
        let rx = (maxC - minC) / 2.0
        let ry = (maxR - minR) / 2.0

        guard rx > 0 && ry > 0 else {
            return line(r0: r0, c0: c0, r1: r1, c1: c1)
        }

        // Generate 10 vertices (outer and inner alternating)
        var vertices: [(Int, Int)] = []
        for i in 0..<10 {
            let angle = -Double.pi / 2.0 + Double(i) * .pi / 5.0
            let r = i % 2 == 0 ? 1.0 : 0.4
            let px = cx + rx * r * cos(angle)
            let py = cy + ry * r * sin(angle)
            vertices.append((Int(py.rounded()), Int(px.rounded())))
        }

        if filled {
            let allR = vertices.map(\.0)
            let scanMin = allR.min()!
            let scanMax = allR.max()!
            var points: [(Int, Int)] = []

            for scanRow in scanMin...scanMax {
                var intersections: [Double] = []
                for i in 0..<vertices.count {
                    let j = (i + 1) % vertices.count
                    let (r_i, c_i) = vertices[i]
                    let (r_j, c_j) = vertices[j]
                    let y_i = Double(r_i), y_j = Double(r_j)
                    let x_i = Double(c_i), x_j = Double(c_j)
                    let y = Double(scanRow)
                    if (y_i <= y && y < y_j) || (y_j <= y && y < y_i) {
                        let t = (y - y_i) / (y_j - y_i)
                        intersections.append(x_i + t * (x_j - x_i))
                    }
                }
                intersections.sort()
                var idx = 0
                while idx + 1 < intersections.count {
                    let cLeft = Int(intersections[idx].rounded(.up))
                    let cRight = Int(intersections[idx + 1].rounded(.down))
                    if cLeft <= cRight {
                        for c in cLeft...cRight {
                            points.append((scanRow, c))
                        }
                    }
                    idx += 2
                }
            }

            return points
        } else {
            var points: [(Int, Int)] = []
            for i in 0..<vertices.count {
                let j = (i + 1) % vertices.count
                points.append(contentsOf: line(r0: vertices[i].0, c0: vertices[i].1,
                                               r1: vertices[j].0, c1: vertices[j].1))
            }
            return points
        }
    }

    /// Dispatch to the appropriate shape function.
    static func rasterize(shape: ShapeKind, r0: Int, c0: Int, r1: Int, c1: Int, filled: Bool) -> [(Int, Int)] {
        switch shape {
        case .line:
            return line(r0: r0, c0: c0, r1: r1, c1: c1)
        case .rectangle:
            return rectangle(r0: r0, c0: c0, r1: r1, c1: c1, filled: filled)
        case .square:
            return square(r0: r0, c0: c0, r1: r1, c1: c1, filled: filled)
        case .circle:
            return circle(r0: r0, c0: c0, r1: r1, c1: c1, filled: filled)
        case .oval:
            return oval(r0: r0, c0: c0, r1: r1, c1: c1, filled: filled)
        case .star:
            return star(r0: r0, c0: c0, r1: r1, c1: c1, filled: filled)
        }
    }
}
