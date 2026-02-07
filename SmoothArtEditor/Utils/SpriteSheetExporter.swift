import UIKit
import Photos

enum SpriteSheetExporter {
    static func renderSpriteSheet(images: [UIImage]) -> UIImage? {
        guard !images.isEmpty, let first = images.first else { return nil }

        let frameWidth = Int(first.size.width)
        let frameHeight = Int(first.size.height)
        let columns = min(images.count, 8)
        let rows = (images.count + columns - 1) / columns

        let totalWidth = frameWidth * columns
        let totalHeight = frameHeight * rows

        UIGraphicsBeginImageContextWithOptions(CGSize(width: totalWidth, height: totalHeight), false, 1.0)
        defer { UIGraphicsEndImageContext() }

        for (index, image) in images.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = col * frameWidth
            let y = row * frameHeight
            image.draw(in: CGRect(x: x, y: y, width: frameWidth, height: frameHeight))
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    static func saveToPhotos(images: [UIImage], completion: @escaping (Bool, String?) -> Void) {
        guard let spriteSheet = renderSpriteSheet(images: images) else {
            completion(false, "Failed to render sprite sheet")
            return
        }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, "Photo library access denied")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAsset(from: spriteSheet)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error?.localizedDescription)
                }
            }
        }
    }
}
