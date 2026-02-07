import UIKit

enum CharacterTemplate {

    /// Generates a template image matching littlelibrarysim ReaderNode proportions
    /// Character is ~52pt tall, ~24pt wide
    static func readerTemplate(canvasSize: CGFloat = 1024, scale: CGFloat = 8) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize, height: canvasSize))

        return renderer.image { context in
            let ctx = context.cgContext

            // Template line style - bold and visible
            let templateColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.9)
            ctx.setStrokeColor(templateColor.cgColor)
            ctx.setLineWidth(8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // Center the character on canvas
            let centerX = canvasSize / 2
            let baseY = canvasSize * 0.75  // Character feet at 75% down

            // Scale factor to make character visible on canvas
            let s = scale

            // All Y coordinates are from feet (0) going up (positive)
            // In UIKit, Y goes down, so we flip: screenY = baseY - (charY * scale)

            func screenY(_ charY: CGFloat) -> CGFloat {
                return baseY - (charY * s)
            }

            func screenX(_ charX: CGFloat) -> CGFloat {
                return centerX + (charX * s)
            }

            // === SHADOW (ellipse at feet) ===
            let shadowRect = CGRect(
                x: screenX(-8),
                y: screenY(3) - 3 * s,  // Ellipse is 6 tall, centered at y=0
                width: 16 * s,
                height: 6 * s
            )
            ctx.strokeEllipse(in: shadowRect)

            // === LEGS (two rectangles) ===
            // Left leg: x=-5 to -1, y=2 to 10
            let leftLegRect = CGRect(
                x: screenX(-5),
                y: screenY(10),
                width: 4 * s,
                height: 8 * s
            )
            ctx.stroke(leftLegRect)

            // Right leg: x=1 to 5, y=2 to 10
            let rightLegRect = CGRect(
                x: screenX(1),
                y: screenY(10),
                width: 4 * s,
                height: 8 * s
            )
            ctx.stroke(rightLegRect)

            // === BODY (rectangle 14×20) ===
            // Body: x=-7 to 7, y=8 to 28
            let bodyRect = CGRect(
                x: screenX(-7),
                y: screenY(28),
                width: 14 * s,
                height: 20 * s
            )
            ctx.stroke(bodyRect)

            // === NECK (4×4 square) ===
            // Neck: x=-2 to 2, y=26 to 30
            let neckRect = CGRect(
                x: screenX(-2),
                y: screenY(30),
                width: 4 * s,
                height: 4 * s
            )
            ctx.stroke(neckRect)

            // === HEAD (circle radius 9) ===
            // Head center at y=37, radius 9
            let headRect = CGRect(
                x: screenX(-9),
                y: screenY(46),
                width: 18 * s,
                height: 18 * s
            )
            ctx.strokeEllipse(in: headRect)

            // === ARMS (lines from shoulders) ===
            // Shoulders at y=24 (body top - 4), x=±7
            // Arms extend down and out to x=±10, y=16
            ctx.setLineWidth(8)

            // Left arm
            ctx.move(to: CGPoint(x: screenX(-7), y: screenY(24)))
            ctx.addLine(to: CGPoint(x: screenX(-10), y: screenY(16)))
            ctx.strokePath()

            // Right arm
            ctx.move(to: CGPoint(x: screenX(7), y: screenY(24)))
            ctx.addLine(to: CGPoint(x: screenX(10), y: screenY(16)))
            ctx.strokePath()

            // === EYES (two small squares) ===
            ctx.setLineWidth(1)
            let eyeSize: CGFloat = 2 * s

            // Left eye at x=-3, y=35
            let leftEyeRect = CGRect(
                x: screenX(-4),
                y: screenY(36),
                width: eyeSize,
                height: eyeSize
            )
            ctx.stroke(leftEyeRect)

            // Right eye at x=2, y=35
            let rightEyeRect = CGRect(
                x: screenX(2),
                y: screenY(36),
                width: eyeSize,
                height: eyeSize
            )
            ctx.stroke(rightEyeRect)

            // === HAIR GUIDE (dashed arc above head) ===
            ctx.setLineDash(phase: 0, lengths: [12, 8])
            ctx.setLineWidth(6)

            // Hair zone: rectangle above head
            let hairRect = CGRect(
                x: screenX(-10),
                y: screenY(54),
                width: 20 * s,
                height: 8 * s
            )
            ctx.stroke(hairRect)

            // === CENTER LINE (guide) ===
            ctx.setLineDash(phase: 0, lengths: [10, 15])
            ctx.setStrokeColor(UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.7).cgColor)
            ctx.setLineWidth(4)
            ctx.move(to: CGPoint(x: centerX, y: screenY(-5)))
            ctx.addLine(to: CGPoint(x: centerX, y: screenY(55)))
            ctx.strokePath()
        }
    }

    /// Kid version - slightly smaller proportions
    static func kidTemplate(canvasSize: CGFloat = 1024, scale: CGFloat = 6) -> UIImage? {
        return readerTemplate(canvasSize: canvasSize, scale: scale)
    }
}
