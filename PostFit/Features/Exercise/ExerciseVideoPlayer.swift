//
//  ExerciseVideoPlayer.swift
//  PostFit (MomCare)
//
//  Smart video player that switches between YouTube, cached, and Firebase videos
//  Supports streaming and offline playback with intelligent caching
//

import SwiftUI
import AVKit

// MARK: - Exercise Video Player

struct ExerciseVideoPlayer: View {
    let exercise: Exercise?
    let videoURL: String?  // Legacy support

    @StateObject private var videoManager = VideoManager.shared
    @State private var videoSource: VideoSource = .unavailable
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var youtubeLoadFailed = false
    @State private var playerObserver: NSObjectProtocol?

    // Initializer that takes an Exercise (preferred)
    init(exercise: Exercise) {
        self.exercise = exercise
        self.videoURL = exercise.videoURL
    }

    // Legacy initializer for backward compatibility
    init(videoURL: String?) {
        self.exercise = nil
        self.videoURL = videoURL
    }

    var body: some View {
        ZStack {
            // Video player content
            videoPlayerContent

            // Loading overlay
            if isLoading && videoSource != .unavailable {
                loadingOverlay
            }

            // Error overlay
            if showError {
                errorOverlay
            }

            // Status badge
            if !isLoading && !showError {
                statusBadge
            }
        }
        .frame(height: 240)
        .cornerRadius(20)
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player?.pause()
            // Remove observer to prevent retain cycle / memory leak
            if let observer = playerObserver {
                NotificationCenter.default.removeObserver(observer)
                playerObserver = nil
            }
        }
    }

    // MARK: - Video Player Content

    @ViewBuilder
    private var videoPlayerContent: some View {
        switch videoSource {
        case .youtube(let youtubeID):
            // YouTube player
            YouTubeVideoPlayer(
                videoID: youtubeID,
                onSlowLoad: {
                    // YouTube is loading slowly, switch to Firebase if available
                    handleYouTubeSlowLoad()
                },
                onError: { error in
                    // YouTube failed, switch to Firebase fallback
                    handleYouTubeError(error)
                }
            )

        case .cached, .directURL:
            // AVPlayer for cached or streaming video
            // Always show VideoPlayer - it handles nil player gracefully
            // Player will be set up and view will re-render when ready
            if let currentPlayer = player {
                VideoPlayer(player: currentPlayer)
            } else {
                // Show loading state while player is being created
                ZStack {
                    Color.black
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }

        case .unavailable:
            // Placeholder when no video source
            placeholderView
        }
    }

    // MARK: - Overlays

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                Text("Loading video...")
                    .font(.momCareBody)
                    .foregroundColor(.white)
            }
        }
    }

    private var errorOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.momCareWarning)

                Text("Failed to load video")
                    .font(.momCareBodyBold)
                    .foregroundColor(.white)

                Text(errorMessage)
                    .font(.momCareCaption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let exercise = exercise {
                    Button("Download for Offline") {
                        downloadVideo()
                    }
                    .font(.momCareButtonSecondary)
                    .foregroundColor(.momCarePrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                }
            }
        }
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.momCarePrimary.opacity(0.1))
                .frame(height: 240)

            VStack(spacing: 16) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.momCarePrimary.opacity(0.5))

                Text("Video demonstration")
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)

                Text("Coming soon")
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        VStack {
            HStack {
                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 12))
                    Text(badgeText)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(badgeColor.opacity(0.9))
                )
                .padding(12)
            }
            Spacer()
        }
    }

    private var badgeIcon: String {
        switch videoSource {
        case .cached: return "arrow.down.circle.fill"
        case .youtube: return "play.rectangle.fill"
        case .directURL: return "network"
        case .unavailable: return ""
        }
    }

    private var badgeText: String {
        switch videoSource {
        case .cached: return "Cached"
        case .youtube: return "YouTube"
        case .directURL: return "Streaming"
        case .unavailable: return ""
        }
    }

    private var badgeColor: Color {
        switch videoSource {
        case .cached: return .momCareSuccess
        case .youtube: return .red
        case .directURL: return .momCarePrimary
        case .unavailable: return .clear
        }
    }

    // MARK: - Video Loading Logic

    private func loadVideo() {
        isLoading = true
        showError = false

        // Get smart video source from VideoManager
        if let exercise = exercise {
            let source = videoManager.smartVideoSource(for: exercise.videoInfo)

            switch source {
            case .unavailable:
                videoSource = source
                isLoading = false
                showError = true
                errorMessage = "No video source available. Please check your internet connection."

            case .cached(let localURL):
                // Set up AVPlayer BEFORE changing videoSource to ensure player is ready
                setupAVPlayerSync(url: localURL)
                videoSource = source

            case .directURL(let streamURL):
                // Set up AVPlayer BEFORE changing videoSource to ensure player is ready
                setupAVPlayerSync(url: streamURL)
                videoSource = source

            case .youtube:
                // YouTube player handles its own loading
                videoSource = source
                break
            }
        } else if let videoURL = videoURL, let url = URL(string: videoURL) {
            // Legacy path: direct URL
            setupAVPlayerSync(url: url)
            videoSource = .directURL(url)
        } else {
            videoSource = .unavailable
            isLoading = false
            showError = true
            errorMessage = "No video URL provided"
        }
    }

    /// Synchronously create player so it's ready before view renders
    private func setupAVPlayerSync(url: URL) {
        // Create player immediately
        let newPlayer = AVPlayer(url: url)
        player = newPlayer

        // Start observing player status for loading state
        observePlayerStatus(newPlayer)

        // Set up auto-replay
        setupAutoReplay(for: newPlayer)
    }

    private func setupAVPlayer(url: URL) {
        isLoading = true
        setupAVPlayerSync(url: url)
    }

    private func observePlayerStatus(_ player: AVPlayer) {
        // Observe player status to update loading state and auto-play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak player] in
            guard let player = player else { return }

            if let status = player.currentItem?.status {
                if status == .readyToPlay {
                    self.isLoading = false
                    player.play()
                } else if status == .failed {
                    self.isLoading = false
                    self.showError = true
                    self.errorMessage = player.currentItem?.error?.localizedDescription ?? "Network error"
                } else {
                    // Still loading, check again
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak player] in
                        guard let player = player else { return }
                        self.isLoading = false
                        if player.currentItem?.status == .readyToPlay {
                            player.play()
                        } else {
                            // Try to play anyway for cached videos
                            player.play()
                        }
                    }
                }
            } else {
                self.isLoading = false
                player.play()
            }
        }
    }

    private func setupAutoReplay(for newPlayer: AVPlayer) {
        // Auto-replay when video ends - store observer to remove later (prevent retain cycle)
        // Remove any existing observer first
        if let existingObserver = playerObserver {
            NotificationCenter.default.removeObserver(existingObserver)
        }

        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
    }

    // MARK: - YouTube Error Handling

    private func handleYouTubeSlowLoad() {
        guard let exercise = exercise else { return }

        print("⚠️ [Player] YouTube slow, switching to Firebase fallback")

        // Try Firebase URL as fallback
        if let firebaseURL = exercise.firebaseURL,
           let url = URL(string: firebaseURL) {
            videoSource = .directURL(url)
            setupAVPlayer(url: url)
        } else {
            showError = true
            errorMessage = "YouTube is loading slowly. Please download for offline use."
        }
    }

    private func handleYouTubeError(_ error: String) {
        guard let exercise = exercise else { return }

        print("❌ [Player] YouTube failed: \(error)")

        youtubeLoadFailed = true

        // Try Firebase URL as fallback
        if let firebaseURL = exercise.firebaseURL,
           let url = URL(string: firebaseURL) {
            print("🔄 [Player] Switching to Firebase fallback")
            videoSource = .directURL(url)
            setupAVPlayer(url: url)
        } else {
            isLoading = false
            showError = true
            errorMessage = "Video playback failed. Download for offline use."
        }
    }

    // MARK: - Download

    private func downloadVideo() {
        guard let exercise = exercise else { return }

        Task { @MainActor in
            do {
                try await videoManager.downloadVideo(videoInfo: exercise.videoInfo)
                // Reload video to use cached version
                loadVideo()
            } catch {
                print("❌ Failed to download: \(error)")
            }
        }
    }
}

// MARK: - Compact Video Preview

/// Compact video player for exercise list items
struct CompactExerciseVideoPreview: View {
    let videoURL: String?
    let category: ExerciseCategory
    @State private var showFullVideo = false

    var body: some View {
        Button(action: { showFullVideo = true }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: category.color).opacity(0.15))
                    .frame(width: 80, height: 80)

                VStack(spacing: 6) {
                    Image(systemName: videoURL != nil ? "play.rectangle.fill" : category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: category.color))

                    if videoURL != nil {
                        Text("Demo")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: category.color))
                    }
                }
            }
        }
        .sheet(isPresented: $showFullVideo) {
            if let videoURL = videoURL {
                FullScreenVideoPlayer(videoURL: videoURL)
            }
        }
    }
}

// MARK: - Full Screen Video Player

struct FullScreenVideoPlayer: View {
    @Environment(\.dismiss) private var dismiss
    let videoURL: String

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if let url = URL(string: videoURL) {
                    ExerciseVideoPlayer(videoURL: videoURL)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ExerciseVideoPlayer(videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4")
            .padding()

        CompactExerciseVideoPreview(videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4", category: .pelvicFloor)
    }
}
