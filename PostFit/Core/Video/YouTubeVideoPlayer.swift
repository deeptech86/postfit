//
//  YouTubeVideoPlayer.swift
//  PostFit
//
//  YouTube player wrapper for SwiftUI
//  Uses youtube-ios-player-helper for YouTube video playback
//

import SwiftUI
import WebKit

// MARK: - YouTube Player View

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    let onReady: (() -> Void)?
    let onError: ((String) -> Void)?

    init(videoID: String, onReady: (() -> Void)? = nil, onError: ((String) -> Void)? = nil) {
        self.videoID = videoID
        self.onReady = onReady
        self.onError = onError
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false

        // Load YouTube embed player immediately in makeUIView (only once)
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body { margin: 0; padding: 0; background-color: #000; }
                .video-container {
                    position: relative;
                    padding-bottom: 56.25%; /* 16:9 aspect ratio */
                    height: 0;
                    overflow: hidden;
                }
                .video-container iframe {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    border: 0;
                }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe
                    src="https://www.youtube.com/embed/\(videoID)?playsinline=1&autoplay=1&rel=0&modestbranding=1"
                    frameborder="0"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowfullscreen>
                </iframe>
            </div>
            <script>
                // Notify when player is ready
                window.addEventListener('load', function() {
                    window.webkit.messageHandlers.playerReady.postMessage('ready');
                });
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(embedHTML, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Don't reload HTML on updates - it was loaded in makeUIView
        // This prevents the video from restarting on view updates
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onReady, onError: onError)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onReady: (() -> Void)?
        let onError: ((String) -> Void)?

        init(onReady: (() -> Void)?, onError: ((String) -> Void)?) {
            self.onReady = onReady
            self.onError = onError
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onReady?()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onError?(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onError?(error.localizedDescription)
        }
    }
}

// MARK: - SwiftUI YouTube Player Wrapper

struct YouTubeVideoPlayer: View {
    let videoID: String
    let onSlowLoad: (() -> Void)?
    let onError: ((String) -> Void)?

    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var loadStartTime = Date()

    init(videoID: String, onSlowLoad: (() -> Void)? = nil, onError: ((String) -> Void)? = nil) {
        self.videoID = videoID
        self.onSlowLoad = onSlowLoad
        self.onError = onError
    }

    var body: some View {
        ZStack {
            // YouTube player
            YouTubePlayerView(
                videoID: videoID,
                onReady: {
                    isLoading = false

                    // Check if loading took too long
                    let loadTime = Date().timeIntervalSince(loadStartTime)
                    if loadTime > 3.0 {
                        print("⚠️ [YouTube] Slow load detected: \(loadTime)s")
                        onSlowLoad?()
                    }
                },
                onError: { error in
                    isLoading = false
                    showError = true
                    errorMessage = error
                    onError?(error)
                }
            )
            .background(Color.black)

            // Loading overlay
            if isLoading {
                ZStack {
                    Color.black.opacity(0.8)

                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text("Loading from YouTube...")
                            .font(.momCareCaption)
                            .foregroundColor(.white)
                    }
                }
            }

            // Error overlay
            if showError {
                ZStack {
                    Color.black.opacity(0.9)

                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.momCareWarning)

                        Text("YouTube playback failed")
                            .font(.momCareBodyBold)
                            .foregroundColor(.white)

                        Text("Switching to offline video...")
                            .font(.momCareCaption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            // YouTube badge
            if !isLoading && !showError {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 12))
                            Text("YouTube")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.9))
                        )
                        .padding(12)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            loadStartTime = Date()
        }
    }
}

// MARK: - YouTube URL Parser

extension String {
    /// Extract YouTube video ID from URL
    var youtubeID: String? {
        // Handle various YouTube URL formats
        let patterns = [
            "(?:youtube\\.com/watch\\?v=|youtu\\.be/)([a-zA-Z0-9_-]{11})",
            "youtube\\.com/embed/([a-zA-Z0-9_-]{11})",
            "youtube\\.com/v/([a-zA-Z0-9_-]{11})"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)),
               let range = Range(match.range(at: 1), in: self) {
                return String(self[range])
            }
        }

        // If string is already just an ID (11 characters)
        if count == 11 && range(of: "^[a-zA-Z0-9_-]{11}$", options: .regularExpression) != nil {
            return self
        }

        return nil
    }
}

// MARK: - Preview

#Preview {
    VStack {
        YouTubeVideoPlayer(videoID: "dQw4w9WgXcQ")
            .frame(height: 240)
            .cornerRadius(20)

        Spacer()
    }
    .padding()
}
