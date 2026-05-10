//
//  AudioPlayer.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import AVFoundation
import Observation

#if canImport(UIKit)
import UIKit
#endif

/// App-wide audio player. Streaming-only (URLs come from hisnmuslim.com).
/// Tap the same dhikr's play button while playing to pause; tap a different
/// dhikr's button to switch tracks immediately.
@Observable
final class AudioPlayer {
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var sessionConfigured = false

    private(set) var currentItemId: String?
    private(set) var isPlaying: Bool = false
    private(set) var isLoading: Bool = false

    func toggle(itemId: String, url: URL) {
        if currentItemId == itemId, isPlaying {
            pause()
            return
        }
        play(itemId: itemId, url: url)
    }

    func play(itemId: String, url: URL) {
        configureAudioSessionIfNeeded()
        let safeURL = upgradedToHTTPS(url)
        if currentItemId != itemId {
            replacePlayer(url: safeURL, itemId: itemId)
        }
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Hard stop — discards the player so the next `play()` for any item
    /// starts from the beginning (no resume from the previous position).
    /// Use this on screen dismiss or when switching to a different dhikr.
    func stop() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        currentItemId = nil
        isPlaying = false
        isLoading = false
    }

    func isPlaying(itemId: String) -> Bool {
        currentItemId == itemId && isPlaying
    }

    private func replacePlayer(url: URL, itemId: String) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        player = p
        currentItemId = itemId
        isLoading = true
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.player?.seek(to: .zero)
        }
    }

    /// iOS App Transport Security blocks plain HTTP by default. Our audio
    /// URLs from hisnmuslim.com support HTTPS — upgrade transparently so
    /// we don't need an ATS exception in Info.plist.
    private func upgradedToHTTPS(_ url: URL) -> URL {
        guard url.scheme == "http" else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? url
    }

    /// Set the audio session to `.playback` so audio plays even when the
    /// device is on silent mode. iOS only — no-op on macOS / visionOS.
    private func configureAudioSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        #if canImport(UIKit) && os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true, options: [])
        #endif
    }
}
