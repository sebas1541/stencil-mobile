import Foundation
import Photos
import UIKit

/// Thin wrapper around PhotoKit that handles permission + saving a PNG.
/// Reports back through an enum the UI can render as a toast.
enum PhotoSaveResult {
    case success
    case denied
    case failed(String)
}

enum PhotoSaver {
    /// Save `data` (PNG bytes) to the user's Photos library. Requests
    /// add-only permission on first use.
    static func save(_ data: Data) async -> PhotoSaveResult {
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else {
            return .denied
        }

        guard let image = UIImage(data: data) else {
            return .failed("Could not decode the PNG data.")
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: .success)
                } else if let error {
                    continuation.resume(returning: .failed(error.localizedDescription))
                } else {
                    continuation.resume(returning: .failed("Unknown PhotoKit error"))
                }
            }
        }
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if current != .notDetermined { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
