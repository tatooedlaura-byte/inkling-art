import UIKit
import Photos

enum PNGExporter {
    static func saveToPhotos(image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, "Photo library access denied")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error?.localizedDescription)
                }
            }
        }
    }

    static func copyToClipboard(image: UIImage) {
        UIPasteboard.general.image = image
    }
}
