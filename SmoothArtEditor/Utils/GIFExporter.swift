import UIKit
import ImageIO
import MobileCoreServices
import Photos

enum GIFExporter {
    static func createGIF(images: [UIImage], fps: Int) -> Data? {
        let frameDelay = 1.0 / Double(fps)

        guard let destData = CFDataCreateMutable(nil, 0),
              let dest = CGImageDestinationCreateWithData(destData, kUTTypeGIF, images.count, nil) else {
            return nil
        }

        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]
        CGImageDestinationSetProperties(dest, gifProperties as CFDictionary)

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]

        for image in images {
            if let cgImage = image.cgImage {
                CGImageDestinationAddImage(dest, cgImage, frameProperties as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(dest) else { return nil }
        return destData as Data
    }

    static func saveToPhotos(images: [UIImage], fps: Int, completion: @escaping (Bool, String?) -> Void) {
        guard let gifData = createGIF(images: images, fps: fps) else {
            completion(false, "Failed to create GIF")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("export.gif")
        do {
            try gifData.write(to: tempURL)
        } catch {
            completion(false, error.localizedDescription)
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
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: tempURL, options: nil)
            }) { success, error in
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async {
                    completion(success, error?.localizedDescription)
                }
            }
        }
    }
}
