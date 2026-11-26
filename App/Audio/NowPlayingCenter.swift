import MediaPlayer
import os
import RadioCore
import UIKit

/// The lock screen's and Control Center's view of the radio (`MPNowPlayingInfoCenter`) and their
/// buttons (`MPRemoteCommandCenter`). It holds no rules: `RadioModel` says what to show
/// (`Radio.nowPlaying`) and what each button does.
@MainActor final class NowPlayingCenter {
    private let log = Logger(subsystem: "HingeRadio", category: "nowplaying")
    /// What was last shown; nil while nothing is (the radio off).
    private var shown: NowPlaying?
    private var play: () -> Void = {}
    private var pause: () -> Void = {}
    private var next: () -> Bool = { false }
    private var previous: () -> Bool = { false }
    private var targets: [(MPRemoteCommand, Any)] = []
    /// The app icon (or the badge), made once, the first time something is shown.
    private lazy var artwork: MPMediaItemArtwork? = Self.makeArtwork()

    /// Shows `nowPlaying` as a live stream, with no progress bar, or clears it when nil. Does
    /// nothing when it is what is already shown; logs `NOW PLAYING` when the title changes.
    func update(_ nowPlaying: NowPlaying?) {
        guard nowPlaying != shown else { return }
        let oldTitle = shown?.title
        shown = nowPlaying
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

    /// Wires the buttons, once: play, pause, play/pause (pause while something is shown, that is
    /// while the radio is on, else play), next and previous (false: no station to step to). Seeking
    /// and skipping by an interval are off: the radio is live.
    func handlers(play: @escaping () -> Void, pause: @escaping () -> Void,
                  next: @escaping () -> Bool, previous: @escaping () -> Bool) {
        self.play = play
        self.pause = pause
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

    /// The handler runs on the main thread but is not typed for it: it hops with `assumeIsolated`,
    /// as the session observers do.
    private func wire(_ command: MPRemoteCommand, _ name: String) {
        command.isEnabled = true
        let target = command.addTarget { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.handle(name) ?? .commandFailed }
        }
        targets.append((command, target))
    }

    private func handle(_ name: String) -> MPRemoteCommandHandlerStatus {
        log.notice("REMOTE \(name, privacy: .public)")
        switch name {
        case "play": play()
        case "pause": pause()
        case "togglePlayPause": shown == nil ? play() : pause()
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
