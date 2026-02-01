import UIKit

enum PNGExporter {
    static func renderImage(grid: PixelGrid, scale: Int = 1) -> UIImage? {
        let w = grid.width * scale
        let h = grid.height * scale

        UIGraphicsBeginImageContextWithOptions(CGSize(width: w, height: h), false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // Transparent background
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))

        for row in 0..<grid.height {
            for col in 0..<grid.width {
                if let color = grid[row, col] {
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(CGRect(x: col * scale, y: row * scale, width: scale, height: scale))
                }
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    static func pngData(grid: PixelGrid, scale: Int = 1) -> Data? {
        return renderImage(grid: grid, scale: scale)?.pngData()
    }

    static func saveToPhotos(grid: PixelGrid, scale: Int = 1, completion: @escaping (Bool) -> Void) {
        guard let image = renderImage(grid: grid, scale: scale) else {
            completion(false)
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        completion(true)
    }

    static func copyToClipboard(grid: PixelGrid, scale: Int = 1) {
        guard let image = renderImage(grid: grid, scale: scale) else { return }
        UIPasteboard.general.image = image
    }
}
