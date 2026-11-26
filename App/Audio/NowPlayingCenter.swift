import MediaPlayer
import os
import RadioCore
import UIKit

/// The lock screen's and Control Center's view of the radio (`MPNowPlayingInfoCenter`) and their
/// buttons (`MPRemoteCommandCenter`). It holds no rules: `RadioModel` says what to show
/// (`Radio.nowPlaying`) and what each button does.
@MainActor final class NowPlayingCenter {
    private let log = Logger(subsystem: "HingeRadio", category: "nowplaying")
    /// What was last written; nil while nothing is shown (the radio off).
    private var written: NowPlaying?
    /// When it was written (`ProcessInfo.systemUptime`); nil before the first write.
    private var lastWrite: TimeInterval?
    /// The newest value asked for, which a held artist-only change writes when it is due.
    private var latest: NowPlaying?
    /// Waits to write a held artist-only change (`nowPlayingWriteIsDue`); one at a time.
    private var trailing: Task<Void, Never>?
    private var play: () -> Void = {}
    private var pause: () -> Void = {}
    private var toggle: () -> Void = {}
    private var next: () -> Bool = { false }
    private var previous: () -> Bool = { false }
    private var targets: [(MPRemoteCommand, Any)] = []
    /// The app icon (or the badge), made once, the first time something is shown.
    private lazy var artwork: MPMediaItemArtwork? = Self.makeArtwork()

    /// Shows `nowPlaying` as a live stream, with no progress bar, or clears it when nil. Nothing
    /// is written when it is what is already shown. A change of the title, album, playing state or
    /// power is written at once; a change of the artist (the needle's frequency) alone at most
    /// every `nowPlayingArtistInterval`, with one write after the last, so the resting value lands.
    func update(_ nowPlaying: NowPlaying?) {
        latest = nowPlaying
        guard nowPlaying != written else {
            trailing?.cancel()
            trailing = nil
            return
        }
        let now = Self.uptime
        if nowPlayingWriteIsDue(last: written, next: nowPlaying, lastWrite: lastWrite, now: now) {
            write(nowPlaying, at: now)
        } else if trailing == nil {
            let wait = (lastWrite ?? now) + nowPlayingArtistInterval - now
            trailing = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, wait)))
                guard let self, !Task.isCancelled else { return }
                self.trailing = nil
                if self.latest != self.written { self.write(self.latest, at: Self.uptime) }
            }
        }
    }

    private static var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Writes `nowPlaying` (nil clears); logs `NOW PLAYING` when the title changes.
    private func write(_ nowPlaying: NowPlaying?, at now: TimeInterval) {
        trailing?.cancel()
        trailing = nil
        let oldTitle = written?.title
        written = nowPlaying
        lastWrite = now
        if nowPlaying?.title != oldTitle {
            log.notice("NOW PLAYING \(nowPlaying?.title ?? "cleared", privacy: .public)")
        }
        guard let nowPlaying else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlaying.title,
            MPMediaItemPropertyArtist: nowPlaying.artist,
            MPMediaItemPropertyAlbumTitle: nowPlaying.album,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: nowPlaying.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Wires the buttons, once: play, pause, play/pause, next and previous (false: no station to
    /// step to). Seeking and skipping by an interval are off: the radio is live.
    func handlers(play: @escaping () -> Void, pause: @escaping () -> Void, toggle: @escaping () -> Void,
                  next: @escaping () -> Bool, previous: @escaping () -> Bool) {
        self.play = play
        self.pause = pause
        self.toggle = toggle
        self.next = next
        self.previous = previous
        guard targets.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        wire(center.playCommand, "play")
        wire(center.pauseCommand, "pause")
        wire(center.togglePlayPauseCommand, "togglePlayPause")
        wire(center.nextTrackCommand, "next")
        wire(center.previousTrackCommand, "previous")
        for command in [center.changePlaybackPositionCommand, center.seekForwardCommand,
                        center.seekBackwardCommand, center.skipForwardCommand, center.skipBackwardCommand] as [MPRemoteCommand] {
            command.isEnabled = false
        }
    }

    /// The handler is called on the main thread but is not typed for it. On main it runs at once
    /// (`assumeIsolated`, as the session observers do); should it ever come on another thread, it
    /// waits for the main thread rather than trap.
    private func wire(_ command: MPRemoteCommand, _ name: String) {
        command.isEnabled = true
        let target = command.addTarget { @Sendable [weak self] _ in
            let center = self
            let run: @Sendable () -> MPRemoteCommandHandlerStatus = {
                MainActor.assumeIsolated { center?.handle(name) ?? .commandFailed }
            }
            return Thread.isMainThread ? run() : DispatchQueue.main.sync(execute: run)
        }
        targets.append((command, target))
    }

    private func handle(_ name: String) -> MPRemoteCommandHandlerStatus {
        log.notice("REMOTE \(name, privacy: .public)")
        switch name {
        case "play": play()
        case "pause": pause()
        case "togglePlayPause": toggle()
        case "next": return next() ? .success : .noActionableNowPlayingItem
        case "previous": return previous() ? .success : .noActionableNowPlayingItem
        default: return .commandFailed
        }
        return .success
    }

    /// The app icon, else the badge drawn on a square; built off the main actor so the request
    /// handler, which the system may call on any thread, is not tied to it.
    private nonisolated static func makeArtwork() -> MPMediaItemArtwork? {
        guard let image = appIcon() ?? badgeSquare() else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
    }

    private nonisolated static func appIcon() -> UIImage? {
        if let icon = UIImage(named: "AppIcon") { return icon }
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let files = primary?["CFBundleIconFiles"] as? [String] ?? []
        return files.reversed().lazy.compactMap { UIImage(named: $0) }.first
    }

    private nonisolated static func badgeSquare() -> UIImage? {
        guard let badge = UIImage(named: "Badge") else { return nil }
        let side: CGFloat = 512
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let width = side * 0.8
            let height = width * badge.size.height / max(1, badge.size.width)
            badge.draw(in: CGRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height))
        }
    }
}
