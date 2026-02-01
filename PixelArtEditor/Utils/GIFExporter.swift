import UIKit
import ImageIO
import UniformTypeIdentifiers
import Photos

enum GIFExporter {
    static func createGIF(frames: [PixelGrid], fps: Int, scale: Int = 4) -> Data? {
        guard !frames.isEmpty else { return nil }

        let delay = 1.0 / Double(fps)
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else { return nil }

        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: delay
            ]
        ]

        for grid in frames {
            guard let image = PNGExporter.renderImage(grid: grid, scale: scale),
                  let cgImage = image.cgImage else { continue }
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static func saveToPhotos(frames: [PixelGrid], fps: Int, scale: Int = 4, completion: @escaping (Bool, String?) -> Void) {
        guard let data = createGIF(frames: frames, fps: fps, scale: scale) else {
            completion(false, "Could not create GIF")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("animation_\(UUID().uuidString).gif")
        do {
            try data.write(to: tempURL)
        } catch {
            completion(false, error.localizedDescription)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
        }) { success, error in
            DispatchQueue.main.async {
                try? FileManager.default.removeItem(at: tempURL)
                completion(success, error?.localizedDescription)
            }
        }
    }
}
