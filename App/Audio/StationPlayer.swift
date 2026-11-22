import AVFoundation
import Foundation
import os
import RadioCore

/// Plays one station at a time through an `AVPlayer`, doing what its `Connection` says.
/// Holds no timing or retry rules of its own: it ticks the connection every 0.1 s and reports
/// the player's state and errors to it.
@MainActor final class StationPlayer {
    var onPlayback: ((Playback) -> Void)?
    var onFailed: ((Station) -> Void)?
    var volume: Float = 0 { didSet { player.volume = volume } }

    /// The station the player is connected to, playing or not.
    var connected: Station? { connection.connected }

    private var player = StationPlayer.makePlayer()
    private var connection = Connection()
    private var reportedPlaying = false
    private let log = Logger(subsystem: "HingeRadio", category: "sound")

    init() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                self.tick()
            }
        }
    }

    func want(_ station: Station?) {
        connection.want(station, at: Self.now)
    }

    /// Silences at once and forgets anything pending.
    func stop() {
        perform(connection.reset())
    }

    // MARK: - Private

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private func tick() {
        observePlayer()
        perform(connection.tick(at: Self.now))
    }

    /// Passes the player's state and errors to the connection.
    private func observePlayer() {
        if player.status == .failed {
            // A failed `AVPlayer` never recovers: replace it so it cannot count against later
            // stations, and report the error for the station it was playing, if any.
            let reason = player.error?.localizedDescription ?? "unknown error"
            player = Self.makePlayer()
            player.volume = volume
            if let station = connection.connected {
                log.notice("PLAYER FAILED \(station.callSign, privacy: .public): \(reason, privacy: .public)")
                errored(station)
            } else {
                log.notice("PLAYER FAILED: \(reason, privacy: .public)")
            }
            return
        }
        guard let station = connection.connected else { return }
        if player.currentItem?.status == .failed {
            let reason = player.currentItem?.error?.localizedDescription ?? "unknown error"
            log.notice("ITEM FAILED \(station.callSign, privacy: .public): \(reason, privacy: .public)")
            errored(station)
            return
        }
        let playing = player.timeControlStatus == .playing
        guard playing != reportedPlaying else { return }
        reportedPlaying = playing
        connection.playerReported(station, playing: playing, at: Self.now)
        if playing { log.notice("PLAYING \(station.callSign, privacy: .public)") }
        onPlayback?(playing ? .playing : .connecting)
    }

    /// Asks the connection what a player error means and does it.
    private func errored(_ station: Station) {
        let action = connection.playerErrored(station, at: Self.now)
        if case .connect = action { log.notice("RETRY \(station.callSign, privacy: .public)") }
        perform(action)
    }

    private func perform(_ action: Connection.Action) {
        switch action {
        case .none:
            return
        case .connect(let station):
            log.notice("CONNECT \(station.callSign, privacy: .public)")
            reportedPlaying = false
            player.replaceCurrentItem(with: AVPlayerItem(url: station.streamURL))
            player.play()
            onPlayback?(.connecting)
        case .disconnect:
            silence()
            log.notice("STOP")
            onPlayback?(.idle)
        case .fail(let station):
            silence()
            log.notice("FAILED \(station.callSign, privacy: .public)")
            onFailed?(station)       // first, so the station is dead before anything re-wants it
            onPlayback?(.idle)
        }
    }

    private static func makePlayer() -> AVPlayer {
        let player = AVPlayer()
        player.volume = 0
        player.automaticallyWaitsToMinimizeStalling = true
        return player
    }

    private func silence() {
        reportedPlaying = false
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
