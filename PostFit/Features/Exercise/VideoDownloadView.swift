//
//  VideoDownloadView.swift
//  PostFit
//
//  UI for managing exercise video downloads
//

import SwiftUI

// MARK: - Video Download Settings View
struct VideoDownloadSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var videoManager = VideoManager.shared
    @State private var showClearConfirmation = false
    @State private var isDownloadingAll = false

    let exercises: [Exercise]

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.momCarePrimary)
                            Text("Storage Used")
                                .font(.momCareBody)

                            Spacer()

                            Text(videoManager.cacheSizeFormatted)
                                .font(.momCareBodyBold)
                                .foregroundColor(.momCareTextSecondary)
                        }

                        Text("Downloaded videos are available offline")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Exercise Videos") {
                    ForEach(exercises) { exercise in
                        VideoDownloadRow(exercise: exercise)
                    }
                }

                Section {
                    Button(action: downloadAll) {
                        HStack {
                            if isDownloadingAll {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }

                            Text("Download All Videos")
                                .font(.momCareBodyBold)

                            Spacer()

                            Text(totalEstimatedSize)
                                .font(.momCareCaption)
                                .foregroundColor(.momCareTextTertiary)
                        }
                    }
                    .disabled(isDownloadingAll || allVideosDownloaded)
                    .foregroundColor(allVideosDownloaded ? .momCareTextTertiary : .momCarePrimary)

                    Button(role: .destructive, action: { showClearConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Downloads")
                        }
                    }
                    .disabled(videoManager.totalCacheSize == 0)
                }

                Section {
                    Text("Videos are streamed by default. Download them for offline access and instant playback without buffering.")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                }
            }
            .navigationTitle("Video Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
            .alert("Clear All Downloads?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearAllDownloads()
                }
            } message: {
                Text("This will delete all downloaded videos (\(videoManager.cacheSizeFormatted)). You can download them again anytime.")
            }
        }
    }

    private var allVideosDownloaded: Bool {
        exercises.allSatisfy { videoManager.isCached(videoID: $0.id.uuidString) }
    }

    private var totalEstimatedSize: String {
        let sizes: [Int64] = exercises.compactMap { exercise -> Int64? in
            return exercise.estimatedFileSize
        }
        let total: Int64 = sizes.reduce(0) { $0 + $1 }
        let mb = Double(total) / 1_048_576
        return String(format: "~%.0f MB", mb)
    }

    private func downloadAll() {
        let exercises = self.exercises
        let manager = self.videoManager

        Task { @MainActor in
            let videoInfos = exercises.map { $0.videoInfo }
            await manager.downloadAllVideos(videos: videoInfos)
        }

        isDownloadingAll = true
    }

    private func clearAllDownloads() {
        do {
            try videoManager.clearAllCache()
        } catch {
            print("❌ Error clearing cache: \(error)")
        }
    }
}

// MARK: - Video Download Row
struct VideoDownloadRow: View {
    @StateObject private var videoManager = VideoManager.shared
    let exercise: Exercise

    @State private var isDownloading = false

    var body: some View {
        HStack(spacing: 12) {
            // Exercise icon
            Image(systemName: exercise.category.icon)
                .font(.system(size: 18))
                .foregroundColor(.momCareExercise)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("\(exercise.duration) min")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)

                    if let fileSize: Int64 = exercise.estimatedFileSize {
                        Group {
                            Text("•")
                                .foregroundColor(.momCareTextTertiary)

                            Text(fileSizeText(fileSize))
                                .font(.momCareCaption)
                                .foregroundColor(.momCareTextTertiary)
                        }
                    }
                }
            }

            Spacer()

            // Download button
            downloadButton
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        if videoManager.isCached(videoID: exercise.id.uuidString) {
            // Downloaded
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.momCareSuccess)
                Text("Downloaded")
                    .font(.momCareCaptionBold)
                    .foregroundColor(.momCareSuccess)
            }
        } else if isDownloading {
            // Downloading
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Downloading...")
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }
        } else {
            // Not downloaded
            Button(action: downloadVideo) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("Download")
                        .font(.momCareCaptionBold)
                }
                .foregroundColor(.momCarePrimary)
            }
        }
    }

    private func fileSizeText(_ size: Int64) -> String {
        let mb = Double(size) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    private func downloadVideo() {
        let videoInfo = exercise.videoInfo
        let manager = self.videoManager

        isDownloading = true

        Task { @MainActor in
            do {
                try await manager.downloadVideo(videoInfo: videoInfo)
                print("✅ Video downloaded successfully")
            } catch {
                print("❌ Error downloading video: \(error)")
            }
        }
    }
}

// MARK: - Compact Download Banner
/// Show this at the top of ExerciseView to encourage downloads
struct VideoDownloadBanner: View {
    @StateObject private var videoManager = VideoManager.shared
    @State private var showDownloadSettings = false

    let exercises: [Exercise]

    var body: some View {
        if !allVideosDownloaded {
            Button(action: { showDownloadSettings = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.momCarePrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download Videos for Offline Access")
                            .font(.momCareCaptionBold)
                            .foregroundColor(.momCareTextPrimary)

                        Text("\(downloadedCount) of \(exercises.count) downloaded")
                            .font(.system(size: 11))
                            .foregroundColor(.momCareTextTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.momCareTextTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.momCarePrimary.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showDownloadSettings) {
                VideoDownloadSettingsView(exercises: exercises)
            }
        }
    }

    private var allVideosDownloaded: Bool {
        exercises.allSatisfy { videoManager.isCached(videoID: $0.id.uuidString) }
    }

    private var downloadedCount: Int {
        exercises.filter { videoManager.isCached(videoID: $0.id.uuidString) }.count
    }
}
