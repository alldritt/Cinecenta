import Foundation

/// Helper to extract video ID from a YouTube URL
enum YouTubeHelper {
    /// Extracts the video ID from various YouTube URL formats
    static func extractVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString

        // Format: https://www.youtube.com/watch?v=VIDEO_ID
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let videoID = queryItems.first(where: { $0.name == "v" })?.value {
            return videoID
        }

        // Format: https://youtu.be/VIDEO_ID
        if url.host == "youtu.be" {
            let videoID = url.lastPathComponent
            if !videoID.isEmpty {
                return videoID
            }
        }

        // Format: https://www.youtube.com/embed/VIDEO_ID
        if urlString.contains("/embed/") {
            let components = urlString.components(separatedBy: "/embed/")
            if components.count > 1 {
                // Remove any query parameters
                return components[1].components(separatedBy: "?").first
            }
        }

        return nil
    }
}
