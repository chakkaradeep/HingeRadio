# Quick fixes and background audio: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The engine rests while the radio is off, the radio plays on with the screen locked and shows on the lock screen, Control Center no longer stops it, HERE says what is happening, "No signal" heals, and HERE stops re-searching short dials.

**Architecture:** Every decision is a pure rule in `Packages/RadioCore` with Swift Testing tests; the app (`App/`) only wires the system (scene phase, AVAudioSession, MediaPlayer, NWPathMonitor, HERE's search) to those rules. One task at a time; each ends with the RadioCore tests and both app builds green.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, AVFoundation, MediaPlayer, Network, Swift Testing, XcodeGen (`project.yml`).

**Spec:** `docs/2026-11-25-quick-fixes-background-audio-design.md` (read it first; it is short). Background: `docs/2026-11-25-performance-ux-review.md`. Behaviour of the whole app: `README.md`.

## Global Constraints

- Swift 6 strict concurrency; no new warnings. `RadioModel` and the app's audio classes are `@MainActor`.
- Rules go in `Packages/RadioCore/Sources/RadioCore` with tests in `Packages/RadioCore/Tests/RadioCoreTests` (Swift Testing, `@Test`, `#expect`). Run: `swift test --package-path Packages/RadioCore`.
- The app builds both ways, on the Duo simulator id `6FBE2E12-829F-4E36-AACD-4F03F4E0638E` (build only; do not install, launch, tap or screenshot it — the simulator is shared):
  - `xcodegen generate && xcodebuild -project HingeRadio.xcodeproj -scheme HingeRadio -configuration Debug -destination 'platform=iOS Simulator,id=6FBE2E12-829F-4E36-AACD-4F03F4E0638E' -derivedDataPath build/DerivedData build`
  - the same with `-derivedDataPath build/DerivedData-plain HERE_CONDITION= build` (HERE compiled out; `#if HERE` guards every HERE path).
- Do not touch other simulators or any physical device. Stop processes only by pid.
- `Info.plist` is generated from `project.yml`: change `project.yml`, never `App/Info.plist` by hand, then `xcodegen generate`.
- Words shown to people, exactly: "Finding stations…", "No stations found here", "Location is off", "Can't find where you are", "No connection", "HERE covers the US only", "Between stations", "No signal". Frequency format on Now Playing: `"%.1f MHz · %@"` (frequency, licence city), e.g. "90.3 MHz · Seattle".
- Numbers: engine rest after 2 s; dead station retried after 60 s; thin dial is under 8 stations; first refresh of a thin dial after 10 minutes, doubling per unchanged refresh, capped at 24 hours; an empty search is not repeated on return within 10 minutes.
- Log lines follow the existing style: `Logger(subsystem: "HingeRadio", category: …)`, upper-case verb first (`ENGINE REST`, `ENGINE WAKE`, `NOW PLAYING`, `REMOTE next`, `ROUTE gone`, `NETWORK back`, `RETRY DEAD <call>`); `.notice` for state changes only, never per frame or per tick; positions and towns are never logged.
- Commits: one per task, message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never `git add -A`; never add `.superpowers/`. Do not push.
- No subagents of your own.

## Review Focus

1. **Engine rest vs the first tick:** a touch on a wheel after a rest must wake the engine before the first tick is due; a tick requested while the engine is stopped must not crash or throw. Power-on after a rest must still give the on click.
2. **Background with the radio off:** suspends exactly as before (no sound, HERE cancelled); with the radio on: keeps playing, no `STOP`, and returning to the app does not reconnect.
3. **`.inactive` no longer suspends:** the location prompt makes the app inactive; HERE's search must still start and run (H1 from the earlier build: cancel on background only).
4. **Now Playing never shows stale info** after power off, band change, or a station going "No signal".
5. **HERE's words while off** must not hide the empty face for the bundled cities: only HERE shows status while off.

---

### Task 1: The engine rests, and the player is checked only while it has work

**Files:**
- Create: `Packages/RadioCore/Sources/RadioCore/EngineRest.swift`, `Packages/RadioCore/Tests/RadioCoreTests/EngineRestTests.swift`
- Modify: `App/RadioModel.swift` (`appIsActive`, `startAudio`, `returnToAmbient`, `play(_:)`, touch-down paths), `App/Audio/NoiseEngine.swift` (doc comment; start/stop are already safe to repeat), `App/Audio/StationPlayer.swift` (the 0.1 s loop), `Packages/RadioCore/Sources/RadioCore/Connection.swift` (an `isIdle` property), `App/Views/SideWheels.swift` and `App/Views/BandSwitch.swift` only if a touch-down hook is missing.

**Interfaces:**
- Produces: `public func engineMayRest(isLive: Bool, lastSound: TimeInterval?, now: TimeInterval) -> Bool` — true when not live and (no sound yet, or `now - lastSound >= 2`). `public let engineRestDelay: TimeInterval = 2`.
- Produces: `Connection.isIdle: Bool` — nothing wanted, connecting or connected, and no timer pending.
- Produces in the app: `RadioModel.wake()` — called on touch-down of either wheel and of the band switch, and by VoiceOver adjust actions; starts session + engine if resting.

- [ ] Step 1: Tests for `engineMayRest` (live never rests; off with no sound rests; off 1.9 s after a sound does not; at 2.0 s does) and for `Connection.isIdle` (fresh: idle; after `want(station)`: not; after `reset()`: idle).
- [ ] Step 2: Run them; they fail.
- [ ] Step 3: Implement both in RadioCore.
- [ ] Step 4: App: record the time of every feel (tick/click/stop) and every touch-down; while off, a single timer (a `Task` sleeping until `lastSound + 2`, rescheduled by each sound) stops the engine and deactivates the session with `.notifyOthersOnDeactivation` when `engineMayRest` says so, logging `ENGINE REST`. `wake()` (and `appIsActive(true)` only when not resting-eligible, i.e. let it rest from the start) starts the `.ambient` session + engine, logging `ENGINE WAKE`. Going live keeps the current path (`startAudio(live: true)`). A feel requested while the engine is stopped wakes it first (the tick may be lost; never crash).
- [ ] Step 5: `StationPlayer`: the 0.1 s loop runs only while `!connection.isIdle`; `want` starts it when needed; it ends itself when idle.
- [ ] Step 6: Tests pass; both builds pass. Commit `perf: the sound engine rests while the radio is off`.

### Task 2: Control Center keeps the station, and the radio plays in the background

**Files:**
- Create: `Packages/RadioCore/Sources/RadioCore/Lifecycle.swift`, `Packages/RadioCore/Tests/RadioCoreTests/LifecycleTests.swift`
- Modify: `App/HingeRadioApp.swift`, `App/RadioModel.swift` (`appIsActive`, `enteredBackground`, session observers), `project.yml` (`UIBackgroundModes: [audio]` under the Info properties), `Packages/RadioCore/Sources/RadioCore/Radio.swift` only if `setSuspended` needs a new caller rule.

**Interfaces:**
- Produces: `public enum AppPhase { case active, inactive, background }` and `public func shouldSuspend(phase: AppPhase, powerOn: Bool) -> Bool` — true only for `.background` with power off.
- Produces in the app: an observer of `AVAudioSession.routeChangeNotification`; on reason `.oldDeviceUnavailable` while live, the radio switches off (`togglePower()`), logging `ROUTE gone`.

- [ ] Step 1: Tests: active/inactive never suspend (power on or off); background suspends only with power off.
- [ ] Step 2: Fail, implement, pass.
- [ ] Step 3: App: map `scenePhase` to `AppPhase`; call `radio.setSuspended(shouldSuspend(...))`. Keep `enteredBackground()` (HERE cancelled, dial remembered) for every background. Returning to active while it kept playing must not reconnect (the station is still wanted). Switching off while in the background (route gone, remote pause) suspends as an off background would.
- [ ] Step 4: `project.yml`: add `UIBackgroundModes` with `audio`; `xcodegen generate`; confirm the generated `App/Info.plist` has it.
- [ ] Step 5: Route change observer as above.
- [ ] Step 6: Tests and both builds pass. Commit `feat: the radio plays on in the background and through Control Center`.

### Task 3: Lock screen and Control Center show the station and control it

**Files:**
- Create: `Packages/RadioCore/Sources/RadioCore/NowPlaying.swift`, `Packages/RadioCore/Tests/RadioCoreTests/NowPlayingTests.swift`, `App/Audio/NowPlayingCenter.swift`
- Modify: `App/RadioModel.swift` (publish on change; commands), `App/Assets.xcassets` only if an artwork image is needed beyond the app icon (prefer rendering `Image("Badge")` or the icon at runtime; no new files if avoidable).

**Interfaces:**
- Produces: `public struct NowPlaying: Equatable, Sendable { public let title: String; public let artist: String; public let album: String; public let isPlaying: Bool }` and `public extension Radio { func nowPlaying(playback: Playback) -> NowPlaying? }` — nil when power is off; title = locked station's `shownName`, "No signal" when the candidate is dead, "Between stations" when nothing is locked; artist = `String(format: "%.1f MHz · %@", frequency, licenceCity)` for a station, and just `"%.1f MHz"` of the needle between stations; album = the band's `name`; `isPlaying` = playback is `.playing`.
- Produces in the app: `NowPlayingCenter` (`@MainActor`) with `update(_ nowPlaying: NowPlaying?)` (sets `MPNowPlayingInfoCenter.default().nowPlayingInfo` with title, artist, album, `MPNowPlayingInfoPropertyIsLiveStream = true`, playback rate 1 or 0, artwork; nil clears) and `handlers(play:pause:next:previous:)` wiring `MPRemoteCommandCenter` (play, pause, togglePlayPause, nextTrack, previousTrack enabled; seek and skip-interval disabled).

- [ ] Step 1: Tests for `nowPlaying`: off → nil; locked KEXP playing → "KEXP", "90.3 MHz · Seattle", album "Seattle", isPlaying; between stations → "Between stations" and the needle's frequency; dead candidate → "No signal"; connecting → isPlaying false; HERE with town "Fargo" → album "Fargo".
- [ ] Step 2: Fail, implement, pass.
- [ ] Step 3: App: update Now Playing only when the value changes (compare with the last one; log `NOW PLAYING` at notice only on change of title). Commands: play → power on if off (`togglePower`); pause → off if on; togglePlayPause → `togglePower`; next/previous → `stepStation(up:animated: false)`; log `REMOTE <command>`. Return `.success`, or `.noActionableNowPlayingItem` for next/previous with no station to step to.
- [ ] Step 4: Tests and both builds pass. Commit `feat: Now Playing and lock-screen controls`.

### Task 4: HERE says what is happening, even switched off

**Files:**
- Modify: `Packages/RadioCore/Sources/RadioCore/Here.swift` (`HereStatus` gains `noPosition`, `noConnection`, `outsideUS`), `Packages/RadioCore/Sources/RadioCore/Radio.swift` (`display`, the subtitle for each status), `Packages/RadioCore/Sources/RadioCore/HerePlan.swift` (`noPlace`, and how a hunt's outcome maps to a status), `App/Here/HereSearch.swift`, `App/Here/StationFinder.swift` (tell a connection failure and an FCC answer with no licences apart from "found none with a stream"), tests in `HerePlanTests.swift`, `HereTests.swift` and wherever `display` is tested.

**Interfaces:**
- Produces: `HereStatus` cases `.noPosition` ("Can't find where you are"), `.noConnection` ("No connection"), `.outsideUS` ("HERE covers the US only"), alongside `.finding` ("Finding stations…"), `.empty` ("No stations found here"), `.locationOff` ("Location is off").
- `Radio.display`: with power off and HERE the band and its status one of the words above, title "" and that subtitle, lamp off; for every bundled city, off is unchanged (empty).
- `HerePlan.noPlace`: `.unavailable` (or a timeout) with no usable kept dial → `.noPosition`; refused → `.locationOff`.
- A hunt that could not reach the FCC → `.noConnection`; the FCC answered but no licence row was usable at all (after the 0 km skip) → `.outsideUS`; licences but no stations with streams → `.empty`.

- [ ] Step 1: Tests for each status's words, for off + HERE showing the status, for off + Seattle showing nothing, and for each mapping above (a pure function from the hunt's outcome to a status; design its input type).
- [ ] Step 2: Fail, implement, pass.
- [ ] Step 3: App wiring in `HereSearch`/`StationFinder`. A cancelled search stays as today (no status change).
- [ ] Step 4: Tests and both builds pass. Commit `feat: HERE tells no position, no connection and outside the US apart, even when off`.

### Task 5: "No signal" heals

**Files:**
- Modify: `Packages/RadioCore/Sources/RadioCore/Radio.swift` (dead stations remember when they died), tests in `RadioTests`/new `DeadTests.swift`, `App/RadioModel.swift` (`markDead`, passing the time; a network-path monitor), `App/Audio/StationPlayer.swift` only if needed.

**Interfaces:**
- `Radio.markDead(_ callSign: String, at: TimeInterval)`; `Radio.dead` stays a `Set<String>` for readers (keep the property; add a private map of times).
- `public mutating func tune(toPosition:at:)` or a separate `public mutating func retryDeadUnderNeedle(at now: TimeInterval) -> String?` — when the candidate is dead and was marked at least 60 s before `now`, it is live again; returns its call sign (the app logs `RETRY DEAD <call>`). Choose whichever keeps existing call sites simple; existing tests must not change meaning.
- `public mutating func reviveAllDead()` — the network came back.
- App: `NWPathMonitor` on a background queue, hopping to the main actor; on a change from unsatisfied to satisfied, `reviveAllDead()` and log `NETWORK back`.

- [ ] Step 1: Tests: dead at t=0, needle onto it at t=59 → still dead; at t=60 → live; `reviveAllDead` clears all; selecting HERE still revives HERE's (existing behaviour).
- [ ] Step 2: Fail, implement, pass.
- [ ] Step 3: App wiring. Time source: `ProcessInfo.processInfo.systemUptime`.
- [ ] Step 4: Tests and both builds pass. Commit `feat: a station with no signal is tried again later`.

### Task 6: HERE stops re-searching short dials

**Files:**
- Modify: `Packages/RadioCore/Sources/RadioCore/Here.swift` (`HereDial` gains the back-off), `Packages/RadioCore/Sources/RadioCore/HerePlan.swift` (an empty search not repeated on return within 10 min), `App/Here/HereSearch.swift`, `App/Here/HereCache.swift` (the dial file keeps the new field; old files without it still load), tests in `HereTests.swift`/`HerePlanTests.swift`.

**Interfaces:**
- `HereDial` gains `public let unchangedRefreshes: Int` (Codable, default 0 when absent). `needsRefresh(at:)`: for a thin dial (under 8), due after `10 min × 2^unchangedRefreshes`, at most 24 h; a full dial unchanged (24 h). A refresh that found the same stations (same call signs) saves the dial with `unchangedRefreshes + 1` and a new `savedAt`; a changed one resets it to 0.
- An empty search: remember its time (in `HerePlan`, in memory is enough); `searches(on: .returned, …)` is false within 10 min of an empty search; `.chosen` always searches.

- [ ] Step 1: Tests: thin dial due at 10 min with 0, 20 min with 1, 40 with 2, capped at 24 h; decode of an old dial file without the field gives 0; empty result then return at 9 min → no search, at 10 min → search; chosen → search.
- [ ] Step 2: Fail, implement, pass.
- [ ] Step 3: App wiring.
- [ ] Step 4: Tests and both builds pass. Commit `perf: HERE backs off from re-searching short dials`.

### Task 7: README, ignore list, and the About screenshot

**Files:**
- Modify: `README.md` (every behaviour changed above: sound and the engine rest, background, lock screen, HERE's words and when it re-searches, "No signal" healing, the test count), `.gitignore` (add `.superpowers/`).

- [ ] Step 1: Update the README sections that describe these behaviours; keep its plain style; update the Swift test count from the actual `swift test` output.
- [ ] Step 2: Add `.superpowers/` to `.gitignore`; confirm `git status` no longer lists it.
- [ ] Step 3: Commit `docs: quick fixes and background audio`.
