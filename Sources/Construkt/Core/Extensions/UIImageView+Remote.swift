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
    
    /// Asynchronously fetches an image from a URL with caching support.
    /// Returns cached image immediately if available, otherwise downloads and caches.
    /// - Parameters:
    ///   - url: The URL to fetch the image from
    ///   - targetSize: Optional target size for downsampling. If nil, uses original size.
    /// - Returns: The fetched UIImage, or nil if the fetch failed
    @MainActor
    public static func image(from url: URL, targetSize: CGSize? = nil) async -> UIImage? {
        let urlString = url.absoluteString as NSString
        
        if let cachedImage = imageCache.object(forKey: urlString) {
            return cachedImage
        }
        
        let screenScale = UIScreen.main.scale
        let maxPixelDimension: CGFloat
        if let targetSize = targetSize {
            maxPixelDimension = max(targetSize.width, targetSize.height) * screenScale
        } else {
            maxPixelDimension = 1000 * screenScale
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let image = downsample(data: data, to: maxPixelDimension, scale: screenScale) {
                let cost = Int(image.size.width * image.scale) * Int(image.size.height * image.scale) * 4
                imageCache.setObject(image, forKey: urlString, cost: cost)
                return image
            }
        } catch {}
        
        return nil
    }
    
    private static func downsample(data: Data, to maxPixelDimension: CGFloat, scale: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return UIImage(data: data)
        }
        
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
        ] as CFDictionary
        
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        }
        
        if let fullImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return UIImage(cgImage: fullImage, scale: scale, orientation: .up)
        }
        
        return UIImage(data: data)
    }
}

// Associated object key for storing the current URL
private var currentTaskKey: UInt8 = 0

public extension UIImageView {
    
    /// Asynchronously fetches and assigns an image from a given URL, displaying a placeholder 
    /// while loading. Re-requests to a changed URL automatically cancel previous loads.
    func setImage(from url: URL?, placeholder: UIImage? = nil, animated: Bool = true) {
        if let existingTask = objc_getAssociatedObject(self, &currentTaskKey) as? Task<Void, Never> {
            existingTask.cancel()
        }
        
        self.image = placeholder
        
        guard let url = url else { return }
        
        let targetSize = self.bounds.size.width == 0 || self.bounds.size.height == 0
            ? CGSize(width: 300, height: 500)
            : self.bounds.size
        
        let task = Task { @MainActor [weak self] in
            if let image = await ImageCache.image(from: url, targetSize: targetSize) {
                guard let self = self else { return }
                if animated {
                    UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve) {
                        self.image = image
                    }
                } else {
                    self.image = image
                }
            }
        }
        
        objc_setAssociatedObject(self, &currentTaskKey, task, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
