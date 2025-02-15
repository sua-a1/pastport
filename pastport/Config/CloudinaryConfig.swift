import Foundation

/// Configuration for Cloudinary service
enum CloudinaryConfig {
    /// Get Cloudinary credentials from environment variables
    static func getCredentials() -> (cloudName: String, apiKey: String, apiSecret: String)? {
        guard let cloudName = ProcessInfo.processInfo.environment["CLOUDINARY_CLOUD_NAME"],
              let apiKey = ProcessInfo.processInfo.environment["CLOUDINARY_API_KEY"],
              let apiSecret = ProcessInfo.processInfo.environment["CLOUDINARY_API_SECRET"] else {
            print("ERROR: Missing Cloudinary credentials in environment variables")
            return nil
        }
        return (cloudName: cloudName, apiKey: apiKey, apiSecret: apiSecret)
    }
} 