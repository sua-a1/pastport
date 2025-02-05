import Foundation
import AVFoundation

final class VideoCacheManager {
    static let shared = VideoCacheManager()
    private let cache = NSCache<NSString, AVPlayerItem>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Create cache directory in documents folder
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("VideoCache")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Configure cache limits
        cache.countLimit = 50 // Maximum number of videos to cache
        cache.totalCostLimit = 500 * 1024 * 1024 // 500MB limit
        
        print("DEBUG: Video cache initialized at: \(cacheDirectory.path)")
    }
    
    func playerItem(for url: URL) -> AVPlayerItem {
        let key = url.absoluteString as NSString
        
        // Check memory cache first
        if let cachedItem = cache.object(forKey: key) {
            print("DEBUG: Found video in memory cache: \(key)")
            return cachedItem
        }
        
        // Check disk cache
        let localURL = cacheDirectory.appendingPathComponent(key.lastPathComponent)
        if fileManager.fileExists(atPath: localURL.path) {
            print("DEBUG: Found video in disk cache: \(key)")
            let asset = AVAsset(url: localURL)
            let item = AVPlayerItem(asset: asset)
            cache.setObject(item, forKey: key)
            return item
        }
        
        // Create new item and cache it
        print("DEBUG: Creating new player item for: \(key)")
        let item = AVPlayerItem(url: url)
        cache.setObject(item, forKey: key)
        
        // Download for next time
        downloadVideo(from: url, key: key)
        
        return item
    }
    
    private func downloadVideo(from url: URL, key: NSString) {
        let localURL = cacheDirectory.appendingPathComponent(key.lastPathComponent)
        
        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self,
                  let tempURL = tempURL,
                  error == nil else {
                print("DEBUG: Failed to download video: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                // Move downloaded file to cache directory
                if fileManager.fileExists(atPath: localURL.path) {
                    try fileManager.removeItem(at: localURL)
                }
                try fileManager.moveItem(at: tempURL, to: localURL)
                print("DEBUG: Video cached successfully: \(key)")
            } catch {
                print("DEBUG: Failed to cache video: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("DEBUG: Cache cleared")
    }
} 