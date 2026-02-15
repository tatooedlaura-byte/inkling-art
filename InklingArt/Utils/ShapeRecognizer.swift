import Foundation
import CoreGraphics

enum RecognizedShapeKind {
    case line, circle, rectangle, arc, triangle
}

struct RecognizedShape {
    let kind: RecognizedShapeKind
    var boundingRect: CGRect
    var lineStart: CGPoint?
    var lineEnd: CGPoint?
    // Arc properties
    var arcCenter: CGPoint?
    var arcRadius: CGFloat?
    var arcStartAngle: CGFloat?
    var arcEndAngle: CGFloat?
    var arcClockwise: Bool?
    // Triangle vertices
    var triangleVertices: [CGPoint]?
}

struct ShapeRecognizer {
    static func recognize(points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 4 else {
            print("❌ ShapeRecognizer: Not enough points (\(points.count))")
            return nil
        }

        print("🔍 ShapeRecognizer: Analyzing \(points.count) points...")

        // Check line first (most specific, open shape)
        if let line = detectLine(points: points) {
            print("✅ ShapeRecognizer: Detected LINE")
            return line
        }

        // Check closed shapes before arcs (prevents boxes from being detected as arcs)
        if let rect = detectRectangle(points: points) {
            print("✅ ShapeRecognizer: Detected RECTANGLE")
            return rect
        }
        if let circle = detectCircle(points: points) {
            print("✅ ShapeRecognizer: Detected CIRCLE")
            return circle
        }
        if let triangle = detectTriangle(points: points) {
            print("✅ ShapeRecognizer: Detected TRIANGLE")
            return triangle
        }

        // Check arc last (most permissive, open shape)
        if let arc = detectArc(points: points) {
            print("✅ ShapeRecognizer: Detected ARC (⚠️ This should NOT happen for squares!)")
            return arc
        }

        print("❌ ShapeRecognizer: No shape detected")
        return nil
    }

    // MARK: - Line Detection

    private static func detectLine(points: [CGPoint]) -> RecognizedShape? {
        let start = points.first!
        let end = points.last!
        let directDistance = hypot(end.x - start.x, end.y - start.y)

        guard directDistance >= 20 else { return nil }

        // Compute path length
        var pathLength: CGFloat = 0
        for i in 1..<points.count {
            pathLength += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
        }

        guard pathLength > 0 else { return nil }

        // Start-to-end distance must be > 70% of path length
        guard directDistance / pathLength > 0.70 else { return nil }

        // Max perpendicular deviation < 5% of direct distance
        let dx = end.x - start.x
        let dy = end.y - start.y
        var maxDev: CGFloat = 0
        for point in points {
            let dev = abs((point.x - start.x) * dy - (point.y - start.y) * dx) / directDistance
            maxDev = max(maxDev, dev)
        }

        guard maxDev / directDistance < 0.05 else { return nil }

        // Snap to horizontal/vertical if close (within 8 degrees)
        var snappedStart = start
        var snappedEnd = end
        let angle = atan2(abs(dy), abs(dx))
        let snapThreshold: CGFloat = 8 * .pi / 180  // 8 degrees

        if angle < snapThreshold {
            // Nearly horizontal — snap to same Y
            let avgY = (start.y + end.y) / 2
            snappedStart = CGPoint(x: start.x, y: avgY)
            snappedEnd = CGPoint(x: end.x, y: avgY)
        } else if angle > (.pi / 2 - snapThreshold) {
            // Nearly vertical — snap to same X
            let avgX = (start.x + end.x) / 2
            snappedStart = CGPoint(x: avgX, y: start.y)
            snappedEnd = CGPoint(x: avgX, y: end.y)
        }

        let minX = min(snappedStart.x, snappedEnd.x)
        let minY = min(snappedStart.y, snappedEnd.y)
        let maxX = max(snappedStart.x, snappedEnd.x)
        let maxY = max(snappedStart.y, snappedEnd.y)
        let rect = CGRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))

        return RecognizedShape(kind: .line, boundingRect: rect,
                               lineStart: snappedStart, lineEnd: snappedEnd,
                               arcCenter: nil, arcRadius: nil, arcStartAngle: nil, arcEndAngle: nil, arcClockwise: nil,
                               triangleVertices: nil)
    }

    // MARK: - Arc Detection

    private static func detectArc(points: [CGPoint]) -> RecognizedShape? {
        let start = points.first!
        let end = points.last!

        // Arc must be open (not closed)
        var pathLength: CGFloat = 0
        for i in 1..<points.count {
            pathLength += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
        }
        guard pathLength > 20 else { return nil }

        let directDistance = hypot(end.x - start.x, end.y - start.y)

        // Must not be too closed (that's a circle/rectangle) and not too straight (that's a line)
        // Increased minimum closeness from 0.15 to 0.35 to prevent squares from being detected as arcs
        let closeness = directDistance / pathLength
        guard closeness > 0.35, closeness < 0.70 else { return nil }

        // CRITICAL: Reject anything with sharp corners (like rectangles/squares)
        // Sample points and check for sudden direction changes
        let sampleInterval = max(1, points.count / 20)
        for i in stride(from: sampleInterval, to: points.count - sampleInterval, by: sampleInterval) {
            let v1x = points[i].x - points[i - sampleInterval].x
            let v1y = points[i].y - points[i - sampleInterval].y
            let v2x = points[i + sampleInterval].x - points[i].x
            let v2y = points[i + sampleInterval].y - points[i].y

            let len1 = hypot(v1x, v1y)
            let len2 = hypot(v2x, v2y)
            guard len1 > 0.01, len2 > 0.01 else { continue }

            let dot = v1x * v2x + v1y * v2y
            let cosAngle = max(-1, min(1, dot / (len1 * len2)))
            let angle = acos(cosAngle)

            // If we find a sharp corner (> 45 degrees change), it's not an arc
            if angle > CGFloat.pi / 4 {
                return nil  // Has sharp corners, not an arc
            }
        }

        // Fit a circle through the points using least-squares
        // Use three reference points: start, middle, end
        let mid = points[points.count / 2]

        guard let (cx, cy, r) = fitCircleThreePoints(start, mid, end) else { return nil }
        guard r > 10, r < 2000 else { return nil }

        // Check how well points fit the circle
        var totalDeviation: CGFloat = 0
        for p in points {
            let dist = hypot(p.x - cx, p.y - cy)
            totalDeviation += abs(dist - r)
        }
        let meanDeviation = totalDeviation / CGFloat(points.count)
        guard meanDeviation / r < 0.12 else { return nil }

        // Compute start and end angles
        let startAngle = atan2(start.y - cy, start.x - cx)
        let endAngle = atan2(end.y - cy, end.x - cx)

        // Determine clockwise vs counterclockwise by checking the cross product
        // of the direction at the midpoint
        let midIdx = points.count / 2
        let beforeMid = points[max(midIdx - 1, 0)]
        let afterMid = points[min(midIdx + 1, points.count - 1)]
        let toMidX = mid.x - cx
        let toMidY = mid.y - cy
        let tangentX = afterMid.x - beforeMid.x
        let tangentY = afterMid.y - beforeMid.y
        let cross = toMidX * tangentY - toMidY * tangentX
        let clockwise = cross < 0  // In UIKit coords (Y-down), negative cross = clockwise

        // Bounding rect
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        // Sample points along the arc for bounding
        let segments = 40
        let sweepAngle = angleSweep(from: startAngle, to: endAngle, clockwise: clockwise)
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let a = clockwise ? startAngle - t * sweepAngle : startAngle + t * sweepAngle
            let px = cx + r * cos(a)
            let py = cy + r * sin(a)
            minX = min(minX, px)
            minY = min(minY, py)
            maxX = max(maxX, px)
            maxY = max(maxY, py)
        }

        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        return RecognizedShape(kind: .arc, boundingRect: rect,
                               lineStart: nil, lineEnd: nil,
                               arcCenter: CGPoint(x: cx, y: cy), arcRadius: r,
                               arcStartAngle: startAngle, arcEndAngle: endAngle,
                               arcClockwise: clockwise,
                               triangleVertices: nil)
    }

    private static func fitCircleThreePoints(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> (CGFloat, CGFloat, CGFloat)? {
        let ax = p1.x, ay = p1.y
        let bx = p2.x, by = p2.y
        let cx = p3.x, cy = p3.y

        let d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
        guard abs(d) > 0.001 else { return nil }

        let ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
        let uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
        let r = hypot(ax - ux, ay - uy)

        return (ux, uy, r)
    }

    private static func angleSweep(from startAngle: CGFloat, to endAngle: CGFloat, clockwise: Bool) -> CGFloat {
        var sweep: CGFloat
        if clockwise {
            sweep = startAngle - endAngle
            if sweep < 0 { sweep += 2 * .pi }
        } else {
            sweep = endAngle - startAngle
            if sweep < 0 { sweep += 2 * .pi }
        }
        return sweep
    }

    // MARK: - Triangle Detection

    private static func detectTriangle(points: [CGPoint]) -> RecognizedShape? {
        let start = points.first!
        let end = points.last!

        // Compute bounding box
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for p in points {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let diagonal = hypot(width, height)

        guard diagonal > 10 else { return nil }

        // Must be closed
        let closeDist = hypot(end.x - start.x, end.y - start.y)
        guard closeDist / diagonal < 0.15 else { return nil }

        // Resample to 64 equidistant points
        let resampled = resample(points: points, count: 64)

        // Find corners (direction change > 35 degrees)
        var cornerIndices: [Int] = []
        let threshold = CGFloat.pi * 35 / 180

        for i in 2..<resampled.count {
            let v1x = resampled[i-1].x - resampled[i-2].x
            let v1y = resampled[i-1].y - resampled[i-2].y
            let v2x = resampled[i].x - resampled[i-1].x
            let v2y = resampled[i].y - resampled[i-1].y

            let len1 = hypot(v1x, v1y)
            let len2 = hypot(v2x, v2y)
            guard len1 > 0.01, len2 > 0.01 else { continue }

            let dot = v1x * v2x + v1y * v2y
            let cosAngle = max(-1, min(1, dot / (len1 * len2)))
            let angle = acos(cosAngle)

            if angle > threshold {
                if let last = cornerIndices.last, i - last < 6 {
                    continue
                }
                cornerIndices.append(i - 1)
            }
        }

        // Need exactly 2-3 corners for a triangle (3 vertices; closing corner may merge with start)
        guard cornerIndices.count >= 2, cornerIndices.count <= 3 else { return nil }

        // Extract corner points
        var vertices = cornerIndices.map { resampled[$0] }
        // Add closing vertex (start/end point) if we only have 2 corners
        if vertices.count == 2 {
            vertices.insert(resampled[0], at: 0)
        }

        guard vertices.count == 3 else { return nil }

        // Check that each edge segment is roughly straight (< 10% deviation)
        let allCorners = [0] + cornerIndices + [resampled.count - 1]
        for i in 0..<(allCorners.count - 1) {
            let segStart = resampled[allCorners[i]]
            let segEnd = resampled[allCorners[i + 1]]
            let segDist = hypot(segEnd.x - segStart.x, segEnd.y - segStart.y)
            guard segDist > 0.01 else { continue }

            let sdx = segEnd.x - segStart.x
            let sdy = segEnd.y - segStart.y

            var maxSegDev: CGFloat = 0
            for j in allCorners[i]...allCorners[i + 1] {
                let dev = abs((resampled[j].x - segStart.x) * sdy - (resampled[j].y - segStart.y) * sdx) / segDist
                maxSegDev = max(maxSegDev, dev)
            }

            if maxSegDev / segDist > 0.10 {
                return nil
            }
        }

        let rect = CGRect(x: minX, y: minY, width: width, height: height)
        return RecognizedShape(kind: .triangle, boundingRect: rect,
                               lineStart: nil, lineEnd: nil,
                               arcCenter: nil, arcRadius: nil, arcStartAngle: nil, arcEndAngle: nil, arcClockwise: nil,
                               triangleVertices: vertices)
    }

    // MARK: - Circle / Oval Detection

    private static func detectCircle(points: [CGPoint]) -> RecognizedShape? {
        let start = points.first!
        let end = points.last!

        // Compute bounding box
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for p in points {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let diagonal = hypot(width, height)

        guard diagonal > 10 else { return nil }

        // Must be closed: start near end
        let closeDist = hypot(end.x - start.x, end.y - start.y)
        guard closeDist / diagonal < 0.15 else { return nil }

        // Center and radii of the expected ellipse
        let cx = (minX + maxX) / 2
        let cy = (minY + maxY) / 2
        let rx = width / 2
        let ry = height / 2

        guard rx > 1, ry > 1 else { return nil }

        // Measure each point's normalized distance from ellipse
        var normalizedDistances: [CGFloat] = []
        for p in points {
            let dx = p.x - cx
            let dy = p.y - cy
            let angle = atan2(dy, dx)
            let expectedR = (rx * ry) / hypot(ry * cos(angle), rx * sin(angle))
            let actualR = hypot(dx, dy)
            guard expectedR > 0 else { continue }
            normalizedDistances.append(actualR / expectedR)
        }

        guard normalizedDistances.count >= 4 else { return nil }

        let mean = normalizedDistances.reduce(0, +) / CGFloat(normalizedDistances.count)
        let variance = normalizedDistances.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / CGFloat(normalizedDistances.count)
        let stddev = sqrt(variance)

        guard mean >= 0.75, mean <= 1.30, stddev < 0.20 else { return nil }

        // Check path length vs expected ellipse perimeter (Ramanujan approximation)
        var pathLength: CGFloat = 0
        for i in 1..<points.count {
            pathLength += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
        }

        let h = pow(rx - ry, 2) / pow(rx + ry, 2)
        let perimeterApprox = CGFloat.pi * (rx + ry) * (1 + 3 * h / (10 + sqrt(4 - 3 * h)))
        guard perimeterApprox > 0 else { return nil }
        let ratio = pathLength / perimeterApprox
        guard ratio >= 0.7, ratio <= 1.5 else { return nil }

        // Snap to perfect circle when aspect ratio is close to 1:1
        var finalRect: CGRect
        let aspect = min(width, height) / max(width, height)
        if aspect > 0.7 {
            let diameter = (width + height) / 2
            let fcx = (minX + maxX) / 2
            let fcy = (minY + maxY) / 2
            finalRect = CGRect(x: fcx - diameter / 2, y: fcy - diameter / 2, width: diameter, height: diameter)
        } else {
            finalRect = CGRect(x: minX, y: minY, width: width, height: height)
        }
        return RecognizedShape(kind: .circle, boundingRect: finalRect,
                               lineStart: nil, lineEnd: nil,
                               arcCenter: nil, arcRadius: nil, arcStartAngle: nil, arcEndAngle: nil, arcClockwise: nil,
                               triangleVertices: nil)
    }

    // MARK: - Rectangle Detection

    private static func detectRectangle(points: [CGPoint]) -> RecognizedShape? {
        let start = points.first!
        let end = points.last!

        // Compute bounding box
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for p in points {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let diagonal = hypot(width, height)

        guard diagonal > 10 else { return nil }

        // Must be closed (allow 30% gap for hand-drawn shapes)
        // Increased from 20% to 30% to catch more hand-drawn rectangles
        let closeDist = hypot(end.x - start.x, end.y - start.y)
        guard closeDist / diagonal < 0.30 else { return nil }

        // Resample to 64 equidistant points
        let resampled = resample(points: points, count: 64)

        // Find corners using a wider window for smoother detection
        var cornerIndices: [Int] = []
        let threshold = CGFloat.pi * 25 / 180  // 25 degrees (was 30, more sensitive now)
        let windowSize = 4

        for i in windowSize..<(resampled.count - windowSize) {
            let v1x = resampled[i].x - resampled[i - windowSize].x
            let v1y = resampled[i].y - resampled[i - windowSize].y
            let v2x = resampled[i + windowSize].x - resampled[i].x
            let v2y = resampled[i + windowSize].y - resampled[i].y

            let len1 = hypot(v1x, v1y)
            let len2 = hypot(v2x, v2y)
            guard len1 > 0.01, len2 > 0.01 else { continue }

            let dot = v1x * v2x + v1y * v2y
            let cosAngle = max(-1, min(1, dot / (len1 * len2)))
            let angle = acos(cosAngle)

            if angle > threshold {
                // Avoid duplicate corners too close together
                if let last = cornerIndices.last, i - last < 8 {
                    // Keep the sharper corner
                    let prevI = cornerIndices.last!
                    let prevV1x = resampled[prevI].x - resampled[max(prevI - windowSize, 0)].x
                    let prevV1y = resampled[prevI].y - resampled[max(prevI - windowSize, 0)].y
                    let prevV2x = resampled[min(prevI + windowSize, resampled.count - 1)].x - resampled[prevI].x
                    let prevV2y = resampled[min(prevI + windowSize, resampled.count - 1)].y - resampled[prevI].y
                    let prevLen1 = hypot(prevV1x, prevV1y)
                    let prevLen2 = hypot(prevV2x, prevV2y)
                    if prevLen1 > 0.01, prevLen2 > 0.01 {
                        let prevDot = prevV1x * prevV2x + prevV1y * prevV2y
                        let prevAngle = acos(max(-1, min(1, prevDot / (prevLen1 * prevLen2))))
                        if angle > prevAngle {
                            cornerIndices[cornerIndices.count - 1] = i
                        }
                    }
                    continue
                }
                cornerIndices.append(i)
            }
        }

        // Need 3–6 corners for a rectangle (was 3-5, now more lenient)
        guard cornerIndices.count >= 3, cornerIndices.count <= 6 else { return nil }

        // Check that each edge segment between corners is roughly straight (< 12% deviation)
        let allCorners = [0] + cornerIndices + [resampled.count - 1]
        for i in 0..<(allCorners.count - 1) {
            let segStart = resampled[allCorners[i]]
            let segEnd = resampled[allCorners[i + 1]]
            let segDist = hypot(segEnd.x - segStart.x, segEnd.y - segStart.y)
            guard segDist > 0.01 else { continue }

            let sdx = segEnd.x - segStart.x
            let sdy = segEnd.y - segStart.y

            var maxSegDev: CGFloat = 0
            for j in allCorners[i]...allCorners[i + 1] {
                let dev = abs((resampled[j].x - segStart.x) * sdy - (resampled[j].y - segStart.y) * sdx) / segDist
                maxSegDev = max(maxSegDev, dev)
            }

            if maxSegDev / segDist > 0.12 {
                return nil
            }
        }

        // Snap to square when aspect ratio is close to 1:1
        var finalRect: CGRect
        let aspect = min(width, height) / max(width, height)
        if aspect > 0.75 {
            let side = (width + height) / 2
            let cx = (minX + maxX) / 2
            let cy = (minY + maxY) / 2
            finalRect = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
        } else {
            finalRect = CGRect(x: minX, y: minY, width: width, height: height)
        }

        return RecognizedShape(kind: .rectangle, boundingRect: finalRect,
                               lineStart: nil, lineEnd: nil,
                               arcCenter: nil, arcRadius: nil, arcStartAngle: nil, arcEndAngle: nil, arcClockwise: nil,
                               triangleVertices: nil)
    }

    // MARK: - Helpers

    private static func resample(points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= 2, count >= 2 else { return points }

        // Compute total path length
        var totalLength: CGFloat = 0
        for i in 1..<points.count {
            totalLength += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
        }

        guard totalLength > 0 else { return points }

        let interval = totalLength / CGFloat(count - 1)
        var resampled = [points[0]]
        var dist: CGFloat = 0
        var srcIndex = 1

        while resampled.count < count, srcIndex < points.count {
            let segLen = hypot(points[srcIndex].x - points[srcIndex-1].x,
                               points[srcIndex].y - points[srcIndex-1].y)
            if dist + segLen >= interval {
                let t = (interval - dist) / segLen
                let nx = points[srcIndex-1].x + t * (points[srcIndex].x - points[srcIndex-1].x)
                let ny = points[srcIndex-1].y + t * (points[srcIndex].y - points[srcIndex-1].y)
                let newPoint = CGPoint(x: nx, y: ny)
                resampled.append(newPoint)
                dist = 0
                var mutablePoints = points
                mutablePoints.insert(newPoint, at: srcIndex)
                return resampleFromArray(mutablePoints, count: count)
            } else {
                dist += segLen
                srcIndex += 1
            }
        }

        while resampled.count < count {
            resampled.append(points.last!)
        }

        return resampled
    }

    private static func resampleFromArray(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= 2, count >= 2 else { return points }

        var totalLength: CGFloat = 0
        for i in 1..<points.count {
            totalLength += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
        }
        guard totalLength > 0 else { return Array(points.prefix(count)) }

        let interval = totalLength / CGFloat(count - 1)
        var resampled = [points[0]]
        var accumulated: CGFloat = 0
        var j = 1

        while resampled.count < count, j < points.count {
            let segLen = hypot(points[j].x - points[j-1].x, points[j].y - points[j-1].y)
            if accumulated + segLen >= interval {
                let remaining = interval - accumulated
                let t = segLen > 0 ? remaining / segLen : 0
                let nx = points[j-1].x + t * (points[j].x - points[j-1].x)
                let ny = points[j-1].y + t * (points[j].y - points[j-1].y)
                resampled.append(CGPoint(x: nx, y: ny))
                accumulated = segLen - remaining
                j += 1
            } else {
                accumulated += segLen
                j += 1
            }
        }

        while resampled.count < count {
            resampled.append(points.last!)
        }

        return Array(resampled.prefix(count))
    }
}
