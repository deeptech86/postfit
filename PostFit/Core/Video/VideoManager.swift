//
//  VideoManager.swift
//  PostFit
//
//  Video streaming and caching manager
//  Supports YouTube streaming + local caching from CDN
//

import Foundation
import AVFoundation

// MARK: - Video Source
enum VideoSource: Equatable {
    case youtube(id: String)
    case directURL(URL)
    case cached(URL)
    case unavailable
}

// MARK: - Video Cache Status
enum VideoCacheStatus {
    case notCached
    case downloading(progress: Double)
    case cached(url: URL)
    case failed(error: Error)
}

// MARK: - Video Info
struct VideoInfo: Codable {
    let id: String
    let youtubeID: String?        // Optional YouTube ID for streaming
    let downloadURL: String?       // Direct download URL (your CDN)
    let title: String
    let duration: Int              // seconds
    let fileSize: Int64?           // bytes

    var estimatedSizeMB: String {
        guard let size = fileSize else { return "Unknown" }
        let mb = Double(size) / 1_048_576
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Video Manager
@MainActor
class VideoManager: ObservableObject {
    static let shared = VideoManager()

    @Published var cacheStatus: [String: VideoCacheStatus] = [:]
    @Published var totalCacheSize: Int64 = 0

    private let fileManager = FileManager.default
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]

    // Shared URLSession for video downloads (performance optimization - reuse instead of creating per download)
    private lazy var downloadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 300  // 5 minutes for large videos
        configuration.httpMaximumConnectionsPerHost = 3
        return URLSession(configuration: configuration)
    }()

    // MARK: - Cache Directory
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("ExerciseVideos", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    private init() {
        calculateCacheSize()
    }

    // MARK: - Get Video Source (Legacy)
    func videoSource(for videoInfo: VideoInfo, preferCached: Bool = true) -> VideoSource {
        // Check if cached version exists
        if let cachedURL = getCachedVideoURL(for: videoInfo.id) {
            return .cached(cachedURL)
        }

        // If user prefers streaming and YouTube ID exists, use YouTube
        if !preferCached, let youtubeID = videoInfo.youtubeID {
            return .youtube(id: youtubeID)
        }

        // Otherwise, use direct URL for streaming
        if let downloadURLString = videoInfo.downloadURL,
           let downloadURL = URL(string: downloadURLString) {
            return .directURL(downloadURL)
        }

        // Fallback to YouTube if available
        if let youtubeID = videoInfo.youtubeID {
            return .youtube(id: youtubeID)
        }

        // No valid source available
        return .unavailable
    }

    // MARK: - Smart Video Source Selection (Recommended)
    /// Smart source selection with cache-first, YouTube fallback, Firebase reliability
    /// Priority: Cached → YouTube (with timeout) → Firebase → Unavailable
    func smartVideoSource(for videoInfo: VideoInfo) -> VideoSource {
        // 1. HIGHEST PRIORITY: Check if cached (instant playback!)
        if let cachedURL = getCachedVideoURL(for: videoInfo.id) {
            print("✅ [VideoManager] Using cached video: \(videoInfo.title)")
            return .cached(cachedURL)
        }

        // 2. MEDIUM PRIORITY: Try YouTube (free bandwidth, good CDN)
        if let youtubeID = videoInfo.youtubeID {
            print("🌐 [VideoManager] Using YouTube: \(videoInfo.title)")

            // Schedule background download from Firebase for next time
            scheduleBackgroundDownload(for: videoInfo)

            return .youtube(id: youtubeID)
        }

        // 3. FALLBACK: Use Firebase Storage (reliable, your bandwidth)
        if let downloadURLString = videoInfo.downloadURL,
           let downloadURL = URL(string: downloadURLString) {
            print("📦 [VideoManager] Using Firebase Storage: \(videoInfo.title)")

            // Also schedule download for caching
            scheduleBackgroundDownload(for: videoInfo)

            return .directURL(downloadURL)
        }

        // 4. NO SOURCE AVAILABLE
        print("❌ [VideoManager] No video source available for: \(videoInfo.title)")
        return .unavailable
    }

    // MARK: - Schedule Background Download
    /// Schedules a background download after video starts playing
    /// This ensures the video is cached for next time (silent, automatic)
    private func scheduleBackgroundDownload(for videoInfo: VideoInfo) {
        // Don't download if already cached
        guard !isCached(videoID: videoInfo.id) else { return }

        // Don't download if already downloading
        if case .downloading = cacheStatus[videoInfo.id] {
            return
        }

        print("⏳ [VideoManager] Scheduling background download: \(videoInfo.title)")

        // Schedule download after 2 seconds (give video time to start playing)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Download in background
            try? await downloadVideo(videoInfo: videoInfo)

            print("✅ [VideoManager] Background download complete: \(videoInfo.title)")
        }
    }

    // MARK: - Check if Cached
    func isCached(videoID: String) -> Bool {
        return getCachedVideoURL(for: videoID) != nil
    }

    func getCachedVideoURL(for videoID: String) -> URL? {
        let cachedURL = cacheDirectory.appendingPathComponent("\(videoID).mp4")

        guard fileManager.fileExists(atPath: cachedURL.path) else {
            return nil
        }

        return cachedURL
    }

    // MARK: - Download Video
    func downloadVideo(videoInfo: VideoInfo) async throws {
        guard let downloadURLString = videoInfo.downloadURL,
              let downloadURL = URL(string: downloadURLString) else {
            throw VideoError.invalidURL
        }

        let videoID = videoInfo.id

        // Check if already cached
        if isCached(videoID: videoID) {
            print("✅ [VideoManager] Video already cached: \(videoID)")
            cacheStatus[videoID] = .cached(url: getCachedVideoURL(for: videoID)!)
            return
        }

        // Check if already downloading
        if case .downloading = cacheStatus[videoID] {
            print("⏳ [VideoManager] Video already downloading: \(videoID)")
            return
        }

        print("⬇️ [VideoManager] Starting download: \(videoInfo.title)")
        cacheStatus[videoID] = .downloading(progress: 0.0)

        // Use shared download session (performance optimization - reuses connections)
        let (tempURL, response) = try await downloadSession.download(from: downloadURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VideoError.downloadFailed
        }

        // Move to cache directory
        let destinationURL = cacheDirectory.appendingPathComponent("\(videoID).mp4")

        // Remove existing file if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: tempURL, to: destinationURL)

        print("✅ [VideoManager] Downloaded successfully: \(videoInfo.title)")
        cacheStatus[videoID] = .cached(url: destinationURL)

        calculateCacheSize()
    }

    // MARK: - Download All Videos
    func downloadAllVideos(videos: [VideoInfo]) async {
        for video in videos {
            do {
                try await downloadVideo(videoInfo: video)
            } catch {
                print("❌ [VideoManager] Failed to download \(video.title): \(error)")
                cacheStatus[video.id] = .failed(error: error)
            }
        }
    }

    // MARK: - Delete Cached Video
    func deleteCachedVideo(videoID: String) throws {
        guard let cachedURL = getCachedVideoURL(for: videoID) else {
            return
        }

        try fileManager.removeItem(at: cachedURL)
        cacheStatus[videoID] = .notCached

        print("🗑️ [VideoManager] Deleted cached video: \(videoID)")
        calculateCacheSize()
    }

    // MARK: - Clear All Cache
    func clearAllCache() throws {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)

        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }

        cacheStatus.removeAll()
        totalCacheSize = 0

        print("🗑️ [VideoManager] Cleared all video cache")
    }

    // MARK: - Calculate Cache Size
    func calculateCacheSize() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])

            var totalSize: Int64 = 0
            for fileURL in contents {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }

            totalCacheSize = totalSize
        } catch {
            print("❌ [VideoManager] Error calculating cache size: \(error)")
        }
    }

    var cacheSizeFormatted: String {
        let mb = Double(totalCacheSize) / 1_048_576
        if mb < 1 {
            let kb = Double(totalCacheSize) / 1024
            return String(format: "%.0f KB", kb)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Video Error
enum VideoError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case cachingNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid video URL"
        case .downloadFailed:
            return "Failed to download video"
        case .cachingNotSupported:
            return "Video caching is not supported for this source"
        }
    }
}
