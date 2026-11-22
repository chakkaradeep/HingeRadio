/// What the owner can hear: `.playing` only while the station that is making sound is the one
/// under the needle. The screen and the sound mix both use this, so they never disagree.
public func audiblePlayback(reported: Playback, connected: Station?, wanted: Station?) -> Playback {
    guard wanted != nil else { return .idle }
    return reported == .playing && connected == wanted ? .playing : .connecting
}
