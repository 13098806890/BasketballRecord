import ImageIO
import UIKit

enum PhotoImageProcessor {
    static func process(_ data: Data) async throws -> Data {
        let processingTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return data }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 720,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                return data
            }
            try Task.checkCancellation()
            let processedImage = UIImage(cgImage: thumbnail)
            let compressedData = processedImage.jpegData(compressionQuality: 0.8) ?? data
            try Task.checkCancellation()
            return compressedData
        }

        return try await withTaskCancellationHandler {
            try await processingTask.value
        } onCancel: {
            processingTask.cancel()
        }
    }
}
