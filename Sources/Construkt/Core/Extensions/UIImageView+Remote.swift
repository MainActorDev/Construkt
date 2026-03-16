import UIKit

// Simple Image Cache to avoid re-downloading
fileprivate let imageCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 200 // Limit to 200 images
    cache.totalCostLimit = 1024 * 1024 * 200 // 200 MB limit
    return cache
}()

public class ImageCache {
    public static func clear() {
        imageCache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
    }
}

// Associated object key for storing the current URL
private var currentTaskKey: UInt8 = 0

public extension UIImageView {
    
    /// Asynchronously fetches and assigns an image from a given URL, displaying a placeholder 
    /// while loading. Re-requests to a changed URL automatically cancel previous loads.
    func setImage(from url: URL?, placeholder: UIImage? = nil, animated: Bool = true) {
        // Cancel prior task
        if let existingTask = objc_getAssociatedObject(self, &currentTaskKey) as? Task<Void, Never> {
            existingTask.cancel()
        }
        
        self.image = placeholder
        
        guard let url = url else { return }
        
        let urlString = url.absoluteString as NSString
        
        // Check cache
        if let cachedImage = imageCache.object(forKey: urlString) {
            self.image = cachedImage
            return
        }
        
        // Target size for downsampling based on the view's current bounds.
        // If bounds are zero, fallback to a sensible max thumbnail dimension (e.g. 500pt).
        let screenScale = UIScreen.main.scale
        var targetSize = self.bounds.size
        if targetSize.width == 0 || targetSize.height == 0 {
            targetSize = CGSize(width: 300, height: 500) // Fallback for auto-layout cells not yet sized
        }
        let maxPixelDimension = max(targetSize.width, targetSize.height) * screenScale
        
        // Download
        let task = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Check for cancellation
                try Task.checkCancellation()
                
                if let image = Self.downsample(data: data, to: maxPixelDimension) {
                    
                    // Calculate memory cost: pixels Wide * pixels High * 4 bytes per pixel (RGBA)
                    let cost = Int(image.size.width * image.scale) * Int(image.size.height * image.scale) * 4
                    imageCache.setObject(image, forKey: urlString, cost: cost)
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        if animated {
                            UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve, animations: {
                                self.image = image
                            }, completion: nil)
                        } else {
                            self.image = image
                        }
                    }
                }
            } catch {
                // Cancellation or error
            }
        }
        
        objc_setAssociatedObject(self, &currentTaskKey, task, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    // MARK: - Memory Optimization
    
    /// Downsamples image data to a target pixel dimension, avoiding massive memory spikes 
    /// caused by decoding full-resolution remote images into RAM.
    private static func downsample(data: Data, to maxPixelDimension: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
        ] as CFDictionary
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            // Fallback: direct UIImage creation (works for WebP and other formats where thumbnail creation fails)
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}
