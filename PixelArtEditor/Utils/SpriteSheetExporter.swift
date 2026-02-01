import UIKit

enum SpriteSheetExporter {
    static func renderSpriteSheet(frames: [PixelGrid], scale: Int = 4) -> UIImage? {
        guard let first = frames.first else { return nil }

        let frameW = first.width * scale
        let frameH = first.height * scale
        let totalW = frameW * frames.count
        let totalH = frameH

        UIGraphicsBeginImageContextWithOptions(CGSize(width: totalW, height: totalH), false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.clear(CGRect(x: 0, y: 0, width: totalW, height: totalH))

        for (i, grid) in frames.enumerated() {
            guard let image = PNGExporter.renderImage(grid: grid, scale: scale),
                  let cgImage = image.cgImage else { continue }
            ctx.draw(cgImage, in: CGRect(x: i * frameW, y: 0, width: frameW, height: frameH))
        }

        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    static func saveToPhotos(frames: [PixelGrid], scale: Int = 4, completion: @escaping (Bool, String?) -> Void) {
        guard let image = renderSpriteSheet(frames: frames, scale: scale) else {
            completion(false, "Could not render sprite sheet")
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, _SpriteSheetSaver.shared, #selector(_SpriteSheetSaver.image(_:didFinishSavingWithError:contextInfo:)), nil)
        _SpriteSheetSaver.shared.completion = completion
    }
}

private class _SpriteSheetSaver: NSObject {
    static let shared = _SpriteSheetSaver()
    var completion: ((Bool, String?) -> Void)?

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async {
            self.completion?(error == nil, error?.localizedDescription)
            self.completion = nil
        }
    }
}
