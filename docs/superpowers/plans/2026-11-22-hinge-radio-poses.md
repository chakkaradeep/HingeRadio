# Hinge Radio Poses and Touch Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The radio is tuned by a finger on a strip in flex pose, shows a standby face in book and tent poses, a card when flat or shut, and the hinge no longer tunes.

**Architecture:** A new pure rule in `RadioCore` turns what the hinge and the window report into one of five poses. `Radio` stops taking hinge readings and takes two separate inputs: a dial position (0 to 1) from the finger, and a pose. Sound depends only on "not shut"; the display depends on the pose. The app gains a tuning strip, a standby view and landscape support, and loses the debug slider.

**Tech Stack:** Swift 6.4, SwiftUI (`onHingeChange`, `onGeometryChange`), Swift Testing, XcodeGen. No new libraries.

**Spec:** `docs/2026-11-22-hinge-radio-poses-design.md`. It amends `docs/2026-11-22-hinge-radio-us-local-design.md`; where they disagree the poses design wins. Earlier measurements are in `docs/hinge-measurements.md`.

## Global Constraints

- All paths are relative to the repository root. Work on the branch the owner confirms when execution starts.
- No outside Swift libraries. System fonts. Colours unchanged (`App/Views/Face.swift`), identical in light and dark mode. Bundle identifier `com.example.HingeRadio`. No personal names or addresses anywhere. Do not set `UIRequiresFullScreen`.
- **Poses:** shut, tent, flex, book, flat, by the table in the spec. Shut is a hinge angle below 20 degrees on either screen. Flat is the inner screen at 175 degrees or more, or status fully open. Task 1 may change these two numbers and the window-size rule; nothing else.
- **Sound:** the radio plays in every pose but shut, when it is switched on and the app is in front. A pose change never stops or reconnects the station.
- **Dial numbers are unchanged:** 87.5 to 108.5 MHz across dial units 70 to 150, stations at least 4.5 apart, lock zone 3, release margin 0.5, fade 0.75. The names `minAngle`, `maxAngle` and `Mark.angle` stay; they now mean dial units, not hinge degrees. Do not rename them.
- **The hinge never moves the needle.** Only the tuning strip does. The dial on the top half does not respond to touch.
- **Tuning strip:** full width of the lower half inside the plate's padding, at least 60 pt tall, same scale and station marks as the dial, at the same place across.
- **Standby face:** station name, the line under it, frequency, lamp, power button. No tuning strip, no city keys. The station name and the frequency are the two biggest things on it.
- **Exact copy.** Flat: title `Fold me`, line `Sit the phone half open to use the radio.` Shut: `Closed` and `Open the phone to listen again.` All other display copy is unchanged.
- **The fold:** nothing important within `Face.foldClearance` (14 pt) of it. It runs across the middle of the inner screen in portrait and down the middle in landscape.
- The radio starts off, mid-dial. Changing city keeps the needle's place.
- **Simulator:** the iPhone Duo with UDID `6FBE2E12-829F-4E36-AACD-4F03F4E0638E` (iOS 27.1), called `$DUO` below. Another session uses the iOS 27.2 Duo; do not touch it. Set postures, turn the device, tap, drag and take screenshots with the iOS Simulator tool (`set_posture`, `rotate`, `tap`, `touch_path`, `screenshot`). Take a screenshot after every posture change; coordinates follow the lit screen.
- **Reaching a screen** (from `docs/hinge-measurements.md`): for the inner screen partly folded, set `open` first, then the angle. For the outer screen partly folded, set `closed` first, then jump to 84 or less.
- **Every simulator run is muted:** launch with `-HingeRadioMuted YES`.
- Build: `xcodegen generate && xcodebuild -project HingeRadio.xcodeproj -scheme HingeRadio -destination "platform=iOS Simulator,id=$DUO" -derivedDataPath build/DerivedData build`. Expected: `** BUILD SUCCEEDED **`.
- Launch: `xcrun simctl install $DUO build/DerivedData/Build/Products/Debug-iphonesimulator/HingeRadio.app && xcrun simctl launch --terminate-running-process $DUO com.example.HingeRadio -HingeRadioMuted YES`.
- Log: `xcrun simctl spawn $DUO log show --last 3m --style compact --predicate 'subsystem == "HingeRadio"'`.
- Package tests: `swift test --package-path Packages/RadioCore`. Python tests: `python3 -m unittest tools/test_build_stations.py`.
- Commit locally after each task, ending the message with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. Never push; the repository now has a remote and pushing is the owner's call.

## Review Focus

1. **The app's scene phase blips while the lit screen changes or the device turns.** Expected: the sound carries on; only really leaving the app silences it. Measured in Task 1 (Decision 5), handled in Task 3 Step 6, checked in Task 6 Step 2.
2. **A finger dragged off either end of the strip, or a touch before the strip has a width.** Expected: the needle clamps to the end; no crash, no not-a-number. Pinned in Task 3 (`tuneClampsAndIgnoresNaN`) and Task 4 Step 3.
3. **Odd hinge readings:** not-a-number, negative, above 180, or the hinge disappearing. Expected: the pose holds or lands on a safe pose; no crash. Pinned in Task 2 (`oddAnglesAreSafe`, `noHingeIsFlexOrBook`) and Task 3 (`nanHingeAngleKeepsPose`).
4. **The pose changes while a station is connecting or a finger is on the strip.** Expected: the lock, the needle and the connection carry over. Pinned in Task 3 (`poseChangeKeepsNeedleAndLock`).
5. **Window sizes that are zero, negative or not finite, as can arrive mid-rotation.** Expected: ignored; the last good screen and way up stand. Pinned in Task 2 (`badWindowSizesAreIgnored`).

---

### Task 1: Measure the poses on the simulator

This is the gate from the spec's Risk 1. It produces a document only; the probe is thrown away.

**Files:**
- Create: `docs/pose-measurements.md`
- Temporary, never committed: `App/PoseProbeView.swift`, and edits to `App/HingeRadioApp.swift` and `project.yml`

**Interfaces:**
- Produces: `docs/pose-measurements.md` with the six decisions in Step 4. Tasks 2, 3, 5 and 6 read them.

- [ ] **Step 1: Write the probe.** In `project.yml` allow `UIInterfaceOrientationPortrait`, `UIInterfaceOrientationLandscapeLeft` and `UIInterfaceOrientationLandscapeRight`. `PoseProbeView` shows in large text, and logs as one `PROBE` line per change (subsystem `HingeRadio`, category `probe`, public): the hinge angle to two decimals or `no hinge`; the hinge status; the size of a `GeometryReader` that ignores the safe area, in points; and a counter held in `@State` that goes up on every change (a reset means the view was rebuilt). `HingeRadioApp` shows the probe and logs a `PHASE` line on every `scenePhase` change.

- [ ] **Step 2: Build and launch** with the commands in Global Constraints (the mute argument is harmless here).

- [ ] **Step 3: Run six sequences.** For each posture record: the lit screen from the tool's result, the probe's size, angle and status, and every `PHASE` line since the last posture.
  - **Inner, partly folded:** `open`, then 110. Then `rotate left`, `rotate right`, `rotate right`, `rotate left`, recording after each.
  - **Outer, partly folded:** `closed`, then 60. Then the same four turns. Note whether the size ever becomes wider than tall.
  - **Shut line:** from `closed` each time, jump to 10, 15, 20, 25, 30.
  - **Flat line:** `open`, then 170, 172, 174, 175, 176, 178, 179, then `open`.
  - **Screen switch:** `open`, 110, `closed`, 60, `open`. Note every `PHASE` line and whether the counter reset.
  - **Blip length:** if any `PHASE` line left `active` above, repeat that step three times and note the longest gap between leaving `active` and returning.

- [ ] **Step 4: Write `docs/pose-measurements.md`.** A table per sequence, then these decisions, each with the readings that support it:
  1. **Which screen.** Default rule: outer when the window's short side is under 560 pt. Keep it if every outer reading is under 560 and every inner reading is over; otherwise state the rule that separates them.
  2. **Which way up.** Default rule: landscape when the window is wider than tall. Keep it if turning the device changes the size that way on both screens; otherwise state what the app is told instead.
  3. **Shut line.** 20 stays if `closed` reads below 20 and a commanded 25 reads 20 or more. Otherwise use the number halfway between those two readings.
  4. **Flat line.** 175 stays if `open` reads 175 or more and a commanded 170 reads below 175. Otherwise use the number halfway between those two readings.
  5. **Scene phase.** Either "stays active through screen switches and turns", or "leaves active for up to N seconds" with N.
  6. **Tent verdict.** "Tent can be told from shut on the simulator" or "cannot", with the reason. It can if the outer screen reports a hinge angle of 20 or more while partly folded.

- [ ] **Step 5: Throw the probe away and commit the document.**

```bash
rm App/PoseProbeView.swift
git checkout -- App/HingeRadioApp.swift project.yml App/Info.plist
git status --short        # expected: only docs/pose-measurements.md
git add docs/pose-measurements.md
git commit -m "docs: measure poses, window sizes and scene phase on the Duo simulator"
```

---

### Task 2: The pose rule

**Files:**
- Create: `Packages/RadioCore/Sources/RadioCore/Pose.swift`
- Test: `Packages/RadioCore/Tests/RadioCoreTests/PoseTests.swift`

**Interfaces:**
- Consumes: Decisions 1 to 4 of `docs/pose-measurements.md`.
- Produces:

```swift
public enum Screen: Sendable, Equatable { case inner, outer }
public enum HingeStatus: Sendable, Equatable { case closed, partiallyOpen, fullyOpen }
public enum Pose: String, Sendable, Equatable { case shut, tent, flex, book, flat }

public struct PoseConfig: Sendable, Equatable {
    public var shutBelow = 20.0, flatFrom = 175.0, outerShortSideBelow = 560.0
    public init() {}
}

public struct PoseInput: Sendable, Equatable {
    public var screen: Screen
    public var landscape: Bool
    public var angle: Double?          // nil when the phone has no hinge
    public var status: HingeStatus?    // nil when the phone has no hinge
    public init(screen: Screen, landscape: Bool, angle: Double?, status: HingeStatus?)
}

public struct WindowReading: Sendable, Equatable {
    public var screen: Screen
    public var landscape: Bool
    public init(screen: Screen, landscape: Bool)
}

public func pose(_ input: PoseInput, config: PoseConfig = PoseConfig()) -> Pose
public func windowReading(width: Double, height: Double, config: PoseConfig = PoseConfig()) -> WindowReading?
```

- [ ] **Step 1: Write the failing tests** in `PoseTests.swift`.

```swift
import Testing
@testable import RadioCore

private func p(_ screen: Screen, _ angle: Double?, landscape: Bool = false,
               status: HingeStatus = .partiallyOpen) -> Pose {
    pose(PoseInput(screen: screen, landscape: landscape, angle: angle, status: angle == nil ? nil : status))
}

@Test func shutBelow20OnEitherScreen() {
    #expect(p(.outer, 0, status: .closed) == .shut)
    #expect(p(.outer, 19.9, status: .closed) == .shut)
    #expect(p(.inner, 19.9) == .shut)
    #expect(p(.inner, 19.9, landscape: true) == .shut)
}

@Test func outerScreenPartlyOpenIsTent() {
    #expect(p(.outer, 20, landscape: true, status: .closed) == .tent)     // status reads closed on the outer screen
    #expect(p(.outer, 71.39, landscape: true, status: .closed) == .tent)
    #expect(p(.outer, 60, landscape: true, status: .partiallyOpen) == .tent)
    #expect(p(.outer, 60, landscape: false, status: .closed) == .tent)    // upright: the same face
}

@Test func innerPortraitIsFlex() {
    #expect(p(.inner, 20) == .flex)
    #expect(p(.inner, 110) == .flex)
    #expect(p(.inner, 174.9) == .flex)
}

@Test func innerLandscapeIsBook() {
    #expect(p(.inner, 110, landscape: true) == .book)
}

@Test func flatFrom175OrFullyOpen() {
    #expect(p(.inner, 175) == .flat)
    #expect(p(.inner, 180, landscape: true, status: .fullyOpen) == .flat)
    #expect(p(.inner, 170, status: .fullyOpen) == .flat)
}

@Test func noHingeIsFlexOrBook() {
    #expect(p(.inner, nil) == .flex)
    #expect(p(.inner, nil, landscape: true) == .book)
}

@Test func oddAnglesAreSafe() {
    #expect(p(.inner, -5) == .shut)
    #expect(p(.inner, 400) == .flat)
    #expect(p(.outer, 400, status: .closed) == .tent)
}

@Test func windowSizesMapToScreens() {
    #expect(windowReading(width: 669, height: 951) == WindowReading(screen: .inner, landscape: false))
    #expect(windowReading(width: 951, height: 669) == WindowReading(screen: .inner, landscape: true))
    #expect(windowReading(width: 466, height: 678) == WindowReading(screen: .outer, landscape: false))
    #expect(windowReading(width: 678, height: 466) == WindowReading(screen: .outer, landscape: true))
    #expect(windowReading(width: 600, height: 600)?.landscape == false)   // square counts as upright
}

@Test func badWindowSizesAreIgnored() {
    #expect(windowReading(width: 0, height: 0) == nil)
    #expect(windowReading(width: -1, height: 500) == nil)
    #expect(windowReading(width: .nan, height: 500) == nil)
    #expect(windowReading(width: .infinity, height: 500) == nil)
}
```

If Task 1 changed a number or a rule (Decisions 1 to 4), put the decided number in `PoseConfig` and in the tests that name it, and say so in the report. Change nothing else.

- [ ] **Step 2: Run the tests to see them fail.** Run `swift test --package-path Packages/RadioCore --filter PoseTests`. Expected: a build failure naming a missing symbol such as `pose` or `Screen`.

- [ ] **Step 3: Implement `Pose.swift`.** `pose` checks in this order: no angle gives flex or book by `landscape`; an angle below `shutBelow` gives shut; the outer screen gives tent; `status == .fullyOpen` or an angle of `flatFrom` or more gives flat; otherwise flex or book by `landscape`. The `closed` status is never used to decide shut. `pose` is not called with a not-a-number angle (Task 3 filters it). `windowReading` returns nil unless both sides are finite and above zero.

- [ ] **Step 4: Run the whole package.** Run `swift test --package-path Packages/RadioCore`. Expected: all tests pass, the 56 old ones included.

- [ ] **Step 5: Commit.**

```bash
git add Packages/RadioCore/Sources/RadioCore/Pose.swift Packages/RadioCore/Tests/RadioCoreTests/PoseTests.swift
git commit -m "feat: pose rule for shut, tent, flex, book and flat"
```

---

### Task 3: A radio driven by a dial position and a pose

After this task the hinge no longer tunes, the debug slider is gone, and the app still builds and runs in portrait. Dragging on the dial glass is the stand-in tuner until Task 4 replaces it.

**Files:**
- Modify: `Packages/RadioCore/Sources/RadioCore/Radio.swift`, `Tuner.swift`, `DialConfig.swift`
- Test: `Packages/RadioCore/Tests/RadioCoreTests/RadioTests.swift`, `TunerTests.swift`
- Modify: `App/RadioModel.swift`, `App/HingeSource.swift`, `App/RootView.swift`, `App/Views/DialView.swift`
- Delete: `App/Views/DebugHingeSlider.swift`

**Interfaces:**
- Consumes: `Pose`, `PoseInput`, `PoseConfig`, `HingeStatus`, `Screen`, `windowReading` from Task 2; Decision 5 of `docs/pose-measurements.md`.
- Produces, in `RadioCore`:

```swift
// Tuner: takes dial units (config.minAngle ... config.maxAngle). HingeReading is deleted.
@discardableResult public mutating func update(_ dial: Double) -> TuningState

// DialConfig: closedBelow is deleted. Everything else stays.

// Radio
public init(file: StationFile, config: DialConfig = DialConfig(), poseConfig: PoseConfig = PoseConfig())
public private(set) var pose: Pose                         // .flex at start
public var isLive: Bool                                    // powerOn && pose != .shut && !isSuspended
public mutating func tune(toPosition position: Double)     // 0...1, clamped; not-a-number ignored
public mutating func setPose(_ input: PoseInput)           // a not-a-number angle is ignored
// removed: isClosed, hinge(_:)
```

- Produces, in `RadioModel`:

```swift
func tune(toPosition position: Double)
func hinge(angle: Double?, status: HingeStatus?)     // nil, nil when the phone has no hinge
func window(width: Double, height: Double)
private(set) var screen: Screen                      // .inner until the first window size arrives
private(set) var landscape: Bool                     // false until then
// removed: dialConfig, config, hasHinge, angle, hingeClosed, debugAngle, closedOnInnerScreen, hinge(_: HingeReading)
```

- [ ] **Step 1: Rewrite `RadioTests.swift`.** Keep the `station` helper and `file`. Replace the `r` helper with these inputs, and replace every `radio.hinge(r(x))` with `radio.tune(toPosition: (x - 70) / 80)` (110 is 0.5, 120 is 0.625, 111.875 is 0.5234375, 112.175 is 0.5271875). `powerOnPlaysLockedStation`, `cityKeepsNeedle`, `deadStationIsSilentButShown`, `emptyFileIsStaticOnly`, `suspendingSilencesAndResumingRestores` and `partialBars` keep their assertions. Delete `startsOff`, `closingSilencesAndReopeningResumes`, `sliderAngleBelow45CountsAsClosed` and `nanReadingIsIgnored`; the tests below replace them. Add:

```swift
private let flex = PoseInput(screen: .inner, landscape: false, angle: 110, status: .partiallyOpen)
private let book = PoseInput(screen: .inner, landscape: true, angle: 110, status: .partiallyOpen)
private let tent = PoseInput(screen: .outer, landscape: true, angle: 60, status: .closed)
private let flat = PoseInput(screen: .inner, landscape: false, angle: 180, status: .fullyOpen)
private let shut = PoseInput(screen: .outer, landscape: false, angle: 0, status: .closed)

@Test func startsOffMidDialInFlex() {
    let radio = Radio(file: file)
    #expect(radio.pose == .flex)
    #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    #expect(radio.station == nil)
    #expect(radio.display(playback: .idle).title == "Off")
}

@Test func shuttingSilencesAndReopeningResumes() {
    var radio = Radio(file: file)
    radio.togglePower()
    radio.setPose(shut)
    #expect(radio.station == nil)
    #expect(!radio.isLive)
    radio.setPose(flex)
    #expect(radio.station?.frequency == 98.0)
    #expect(radio.powerOn)
}

@Test func everyPoseButShutPlays() {
    var radio = Radio(file: file)
    radio.togglePower()
    for input in [flex, book, tent, flat] {
        radio.setPose(input)
        #expect(radio.isLive)
        #expect(radio.station?.frequency == 98.0)
    }
}

@Test func poseChangeKeepsNeedleAndLock() {
    var radio = Radio(file: file)
    radio.togglePower()
    radio.tune(toPosition: 0.5175)                      // inside the zone, off the mark
    for input in [book, tent, flat, flex] {
        radio.setPose(input)
        #expect(radio.tuning.locked?.frequency == 98.0)
        #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    }
}

@Test func tuneMovesNeedleAndSnaps() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.5175)
    #expect(radio.tuning.locked?.frequency == 98.0)
    #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    radio.tune(toPosition: 0.625)
    #expect(radio.tuning.locked == nil)
    #expect(abs(radio.tuning.needle - 0.625) < 1e-9)
}

@Test func tuneClampsAndIgnoresNaN() {
    var radio = Radio(file: file)
    radio.tune(toPosition: -1)
    #expect(radio.tuning.needle == 0)
    #expect(abs(radio.tuning.frequency - 87.5) < 1e-9)
    radio.tune(toPosition: 2)
    #expect(radio.tuning.needle == 1)
    radio.tune(toPosition: .nan)
    #expect(radio.tuning.needle == 1)
    radio.selectCity("chicago")                         // the not-a-number was never stored
    #expect(radio.tuning.needle == 1)
}

@Test func nanHingeAngleKeepsPose() {
    var radio = Radio(file: file)
    radio.setPose(shut)
    radio.setPose(PoseInput(screen: .inner, landscape: false, angle: .nan, status: .partiallyOpen))
    #expect(radio.pose == .shut)
}
```

In `displayCopy`, the last two expectations become:

```swift
    radio.setPose(flat)
    #expect(radio.display(playback: .playing)
            == Display(title: "Fold me", subtitle: "Sit the phone half open to use the radio.", lamp: .off, bars: 0))
    radio.setPose(shut)
    #expect(radio.display(playback: .playing)
            == Display(title: "Closed", subtitle: "Open the phone to listen again.", lamp: .off, bars: 0))
    radio.setPose(book)
    #expect(radio.display(playback: .playing).subtitle == "No signal")   // book shows the station, as flex does
```

- [ ] **Step 2: Update `TunerTests.swift`.** Replace the helper with `private func r(_ dial: Double) -> Double { dial }`. No assertion changes.

- [ ] **Step 3: Run the tests to see them fail.** Run `swift test --package-path Packages/RadioCore`. Expected: a build failure naming `setPose` or `tune`.

- [ ] **Step 4: Change `RadioCore`** to the interfaces above. `Radio` keeps the position it was last tuned to (0.5 at start) and re-applies it after a city change. `display` returns the flat copy for flat and the closed copy for shut before looking at power; every other pose is unchanged. Add a comment on `DialConfig` saying `minAngle` and `maxAngle` are dial units.

- [ ] **Step 5: Run the package.** Expected: all tests pass.

- [ ] **Step 6: Update the app.**
  - `HingeSource.swift`: `hingeReadings(into:)` calls `model.hinge(angle:status:)` with the hinge's angle in degrees and its status, or `nil, nil` when the context has no hinge. `DragTuning` is always enabled and calls `model.tune(toPosition:)` with `x / width` clamped by the model.
  - `RadioModel.swift`: holds the last angle, status, screen and way up, and calls `radio.setPose` whenever one of them changes. `window(width:height:)` ignores a size for which `windowReading` returns nil. Logs `POSE <name>` (category `dial`, public) on each pose change. `LOCK` and `STATIC` lines print the dial position to three decimals where they printed the angle.
  - `RootView.swift`: reports its full size to `model.window(width:height:)` with `onGeometryChange`. Shows `ClosedCard` for shut and flat (centred when `model.screen == .outer`, in the half above the fold otherwise), and the dial and plate halves for every other pose. No debug slider.
  - `DialView.swift`: no `onTitleLongPress`; the needle is not animated.
  - Delete `DebugHingeSlider.swift`.
  - **Scene phase.** If Decision 5 says the phase leaves active during a screen switch or a turn, `appIsActive(false)` suspends the radio only after the phase has stayed away from active for the measured gap plus one second (at least 1.5 seconds), in a cancellable `Task` in `RadioModel`; `appIsActive(true)` cancels it. If Decision 5 says it stays active, leave `appIsActive` alone.

- [ ] **Step 7: Check on the simulator.** Build and launch. Set `open`, then 110, and turn the device so the app is upright. Tap the power button, then `touch_path` slowly across the dial glass from left to right. Expected in the log: one `LOCK` line per station in frequency order with `STATIC` between. Then set the hinge to 90, 130, 150. Expected: no `LOCK` or `STATIC` line from the hinge, and the screenshot's needle has not moved. Then `closed`: expected `POSE shut` and `STOP`. Then `open`, 110: expected `POSE flex`, `CONNECT`, `PLAYING`.

- [ ] **Step 8: Commit.**

```bash
git add -A Packages/RadioCore App
git commit -m "feat: tune by dial position, decide sound and display by pose"
```

---

### Task 4: The tuning strip

**Files:**
- Create: `App/Views/ScaleFace.swift`, `App/Views/TuningStrip.swift`
- Modify: `App/Views/DialView.swift`, `App/Views/PlateView.swift`, `App/HingeSource.swift`

**Interfaces:**
- Consumes: `RadioModel.tune(toPosition:)` from Task 3.
- Produces:

```swift
/// Ticks, numbers, station dots and the needle, filling its frame with a 0.7 em inset each side.
/// The one drawing of the scale: the dial glass and the tuning strip both use it.
struct ScaleFace: View { let model: RadioModel; let em: CGFloat }

/// The scale on the lower half. Touching or dragging puts the needle under the finger.
struct TuningStrip: View { let model: RadioModel; let em: CGFloat }
```

- [ ] **Step 1: Move the scale drawing.** `ScaleFace` takes over `scale(width:height:inset:)`, `marks(width:height:)` and the needle from `DialView`, unchanged in look. `DialView`'s glass becomes `ScaleFace` on its shaded, rounded background. Remove `.dragTuning` from the glass and delete `DragTuning` and `dragTuning(into:)` from `HingeSource.swift`.

- [ ] **Step 2: Build `TuningStrip`.** `ScaleFace` on the same shaded, rounded background as the glass, at least 60 pt tall (`max(60, 2.6 * em)`), with a thumb on the needle big enough to see under a finger. A `DragGesture(minimumDistance: 0)` calls `model.tune(toPosition: (x - inset) / (width - 2 * inset))` on touch down and on every move. Lifting the finger does nothing: the needle stays where it was left. Accessibility label `Tuning`, value the frequency readout.

- [ ] **Step 3: Guard the edges.** The strip does nothing while its width minus the insets is zero or less. A drag past either end keeps sending the clamped end position.

- [ ] **Step 4: Rebuild `PlateView`.** Remove the grille. A top row holds the four city keys, the frequency readout and the power button; the strip sits below it across the full width inside the plate's padding (1.1 em each side, the same as the dial's, so the two scales line up). Nothing else on the plate changes look.

- [ ] **Step 5: Check on the simulator.** Build and launch in flex (`open`, 110, upright), power on. `touch_path` slowly along the strip from its left end to its right end: expected one `LOCK` line per station in frequency order. Tap the strip under one station's dot: expected `LOCK` for that station. `touch_path` from the middle of the strip to 6 pt inside the screen's right edge, which is past the end of the scale: expected no crash, and a screenshot with the needle at the right end of both scales and the readout at 108.5 MHz (or at the last station's frequency if its zone reaches the end). `touch_path` across the dial on the top half: expected no `LOCK` or `STATIC` line. Save a screenshot with a station locked as `docs/check/20-flex-strip.png`; in it the orange dot on the strip is directly under the orange dot on the dial, within 2 pt.

- [ ] **Step 6: Commit.**

```bash
git add -A App docs/check/20-flex-strip.png
git commit -m "feat: tuning strip on the lower half replaces the speaker grille"
```

---

### Task 5: Standby faces, cards and landscape

**Files:**
- Create: `App/Views/StandbyView.swift`
- Rename: `App/Views/ClosedCard.swift` to `App/Views/PoseCard.swift` (the type becomes `PoseCard`)
- Modify: `App/RootView.swift`, `project.yml` (which regenerates `App/Info.plist`)

**Interfaces:**
- Consumes: `model.radio.pose`, `model.screen`, `model.landscape`, `model.display`, `model.togglePower()`; Decision 6 of `docs/pose-measurements.md`.
- Produces:

```swift
/// Book and tent: the station name, the line under it, the frequency, the lamp and the power button.
/// `twoPanels` splits them left and right of a vertical fold.
struct StandbyView: View { let model: RadioModel; let twoPanels: Bool }
```

- [ ] **Step 1: Allow landscape.** In `project.yml`, `UISupportedInterfaceOrientations` lists `UIInterfaceOrientationPortrait`, `UIInterfaceOrientationLandscapeLeft` and `UIInterfaceOrientationLandscapeRight`. Run `xcodegen generate`, then `python3 -m unittest tools/test_build_stations.py`. Expected: 19 tests pass (the allowed-host check reads the regenerated `App/Info.plist`).

- [ ] **Step 2: Build `StandbyView`.** Sizes come from the screen's short side `s`: station name bold at `0.13 * s`, up to two lines, shrinking to 60 percent; the line under it at `0.05 * s` in the muted colour; the frequency in medium weight with monospaced digits at `0.22 * s` with a small `MHz`; the lamp as on the dial at `0.05 * s`; the power button as on the plate, at least 60 pt across. With `twoPanels`, the left panel holds the name, the line under it and the lamp, the right panel holds the frequency and the power button, and each panel keeps `Face.foldClearance` clear of the centre line. Without it, one panel holds all five. Text comes from `model.display`, so "Off", "Static", "Tuning in" and "No signal" read as they do in flex. These sizes are starting values; adjust them only to stop clipping.

- [ ] **Step 3: Map poses to views in `RootView`.**

| Pose | View |
|---|---|
| flex | the dial on the half above the fold, the plate on the half below (as now) |
| book | `StandbyView(twoPanels: true)` |
| tent | `StandbyView(twoPanels: false)` |
| flat, shut | `PoseCard`: centred on the outer screen; on the inner screen inside the upper half in portrait and inside the left panel in landscape |

  `Face.em` is taken from the width of the panel or half a view sits in.

- [ ] **Step 4: Check each pose on the simulator.** Build and launch, power on in flex with a station locked. Save each screenshot under `docs/check/`:
  - `open`, 110, upright: `21-flex.png`.
  - Turn a quarter turn to landscape: expected `POSE book`, no `STOP` and no `CONNECT` after it; `22-book.png` shows the same station, with nothing drawn within 14 pt of the vertical centre line.
  - `open`: expected `POSE flat` and no `STOP`; `23-flat.png` shows `Fold me` on one side of the fold.
  - `closed`: expected `POSE shut` and `STOP`; `24-shut.png` shows `Closed`.
  - `closed`, then 60, then a quarter turn: if Decision 6 says tent can be told from shut, expected `POSE tent`, `CONNECT`, `PLAYING`, and `25-tent.png` shows the standby face on the outer screen. If Decision 6 says it cannot, skip this line and report tent as unverified.

- [ ] **Step 5: Commit.**

```bash
git add -A App project.yml docs/check
git commit -m "feat: standby face for book and tent, fold-me card when flat, landscape allowed"
```

---

### Task 7: The tape (runs before Task 6)

Added on 2026-11-22 after the owner asked for the lower-half control not to duplicate the dial and picked the tape (spec, "Amendment: the tape"). It replaces the tuning strip from Task 4. Where Global Constraints say "tuning strip", read "tape": same width and minimum height, but it is not a copy of the dial's scale.

**Files:**
- Create: `App/Views/TapeView.swift`, `Packages/RadioCore/Sources/RadioCore/Flick.swift`
- Test: `Packages/RadioCore/Tests/RadioCoreTests/FlickTests.swift`, `RadioTests.swift`
- Modify: `Packages/RadioCore/Sources/RadioCore/Radio.swift`, `App/RadioModel.swift`, `App/Views/PlateView.swift`
- Delete: `App/Views/TuningStrip.swift`

**Interfaces:**
- Consumes: `Radio.tune(toPosition:)`, `DialScale.marks` (each with `position` 0...1), `ScaleFace` (now used by the dial only).
- Produces:

```swift
// Radio: the position last tuned to, before any snap. Replaces RadioModel's own copy.
public private(set) var position: Double

// Flick.swift
/// Where the tape should come to rest after a release.
/// Returns `position` when the release is slower than `minFlick`; otherwise the mark nearest
/// `predicted`, or `predicted` clamped to 0...1 when there are no marks.
public func flickTarget(from position: Double, predicted: Double, marks: [Double], minFlick: Double = 0.03) -> Double

// RadioModel
var position: Double { get }                 // radio.position
func glide(toPosition target: Double)        // steps tune(toPosition:) along an ease-out over 0.35 s; a new touch cancels it

// TapeView
struct TapeView: View { let model: RadioModel; let em: CGFloat }
```

- [ ] **Step 1: Write the failing tests.** `FlickTests.swift`:

```swift
import Testing
@testable import RadioCore

@Test func slowReleaseStaysPut() {
    #expect(flickTarget(from: 0.40, predicted: 0.42, marks: [0.2, 0.5, 0.8]) == 0.40)
}

@Test func flickSettlesOnNearestMarkToPredictedEnd() {
    #expect(flickTarget(from: 0.20, predicted: 0.55, marks: [0.2, 0.5, 0.8]) == 0.5)
    #expect(flickTarget(from: 0.80, predicted: 0.30, marks: [0.2, 0.5, 0.8]) == 0.2)
}

@Test func flickPastTheEndsSettlesOnTheEndStation() {
    #expect(flickTarget(from: 0.5, predicted: 3.0, marks: [0.2, 0.5, 0.8]) == 0.8)
    #expect(flickTarget(from: 0.5, predicted: -3.0, marks: [0.2, 0.5, 0.8]) == 0.2)
}

@Test func flickWithNoMarksClamps() {
    #expect(flickTarget(from: 0.5, predicted: 3.0, marks: []) == 1)
    #expect(flickTarget(from: 0.5, predicted: -3.0, marks: []) == 0)
}

@Test func notANumberStaysPut() {
    #expect(flickTarget(from: 0.5, predicted: .nan, marks: [0.2]) == 0.5)
}
```

In `RadioTests.swift` add:

```swift
@Test func positionIsTheRawTunedValue() {
    var radio = Radio(file: file)
    #expect(radio.position == 0.5)
    radio.tune(toPosition: 0.5175)                 // snaps the needle, not the position
    #expect(radio.position == 0.5175)
    #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    radio.tune(toPosition: 2)
    #expect(radio.position == 1)
    radio.tune(toPosition: .nan)
    #expect(radio.position == 1)
}
```

- [ ] **Step 2: Run them to see them fail.** `swift test --package-path Packages/RadioCore`. Expected: a build failure naming `flickTarget` or `position`.

- [ ] **Step 3: Implement** `Flick.swift` and expose `Radio.position`. `RadioModel` drops its own stored position and clamp and reads `radio.position`. Run the package: all tests pass.

- [ ] **Step 4: Build `TapeView`.**
  - The tape is `3 x` the width of the view's scale area. A point at dial position `q` is drawn at `centre + (q - needle) * tapeWidth`, where `needle` is `model.radio.tuning.needle`, so the tape rests on a station's mark while locked.
  - On the tape: for each station, its call sign in bold (about `0.8 * em`) with its frequency to one decimal under it in the muted colour, centred on its mark; a short tick at each whole MHz; diagonal hatching in the gaps between station zones; a struck-through, faded label for a dead station; the station under the pointer in the needle colour while the radio is on. Positions come from `model.radio.scale` (`marks` and `position(forFrequency:)`).
  - A fixed pointer in the needle colour at the centre, drawn over the tape. The shaded, rounded background matches the dial glass. The tape fades out toward both edges of the view.
  - Drag: on touch down cancel any glide and remember `model.position`; on each move call `model.tune(toPosition: start - translation.width / tapeWidth)`. On release call `model.glide(toPosition: flickTarget(from: model.position, predicted: start - predictedEndTranslation.width / tapeWidth, marks: ...))` when that target differs from `model.position`.
  - A touch that moves less than 6 pt is a tap: glide to the mark nearest the dial position under the finger.
  - Nothing happens while the view has no width. Accessibility label `Tuning`, value the frequency readout.
  - The tape dims with the power off as the dial does.

- [ ] **Step 5: Put it on the plate.** `PlateView` shows `TapeView` where `TuningStrip` was. Delete `TuningStrip.swift`. `ScaleFace` stays, used by the dial alone.

- [ ] **Step 6: Check on the simulator.** Build and launch in flex (`open`, 110, upright), power on.
  - `touch_path` slowly on the tape from right to left in steps, lifting slowly: expected `LOCK` lines for stations in rising frequency order, and the needle on the top dial moving right.
  - The same from left to right: falling order.
  - A slow drag that ends between two stations with a pause before lifting: expected a final `STATIC` line and the readout between the two.
  - A fast `touch_path` (the whole path in under 0.15 s) to the left: expected several `LOCK` lines and a final `LOCK`, with the screenshot showing a station under the pointer.
  - A tap on a station label that is not under the pointer: expected `LOCK` for that station.
  - A long drag to the right past the low end: no crash; the readout shows 87.5 MHz or the first station.
  - `touch_path` across the dial on the top half: no `LOCK` or `STATIC` line.
  - Save `docs/check/30-flex-tape.png` with a station locked, replace `docs/check/21-flex.png` with the same view, and delete `docs/check/20-flex-strip.png`. In the screenshot no label is clipped by another, and the call sign under the pointer matches the name shown on the top half.

- [ ] **Step 7: Commit.**

```bash
git add -A Packages/RadioCore App docs/check
git commit -m "feat: sliding tape on the lower half replaces the tuning strip"
```

---

### Task 6: Acceptance pass and README

**Files:**
- Modify: `README.md`
- Create or replace: screenshots in `docs/check/` if any changed since Task 5

**Interfaces:**
- Consumes: the finished app; `docs/pose-measurements.md`.

- [ ] **Step 1: Run every test.** `swift test --package-path Packages/RadioCore` and `python3 -m unittest tools/test_build_stations.py`. Expected: all pass. Note both counts.

- [ ] **Step 2: Run the spec's checks on the final build**, muted, reading the log after each. Record what was seen, not what was expected.
  - **Flex:** in each of the four cities, drag the tape onto one station: `LOCK`, `CONNECT`, `PLAYING`.
  - **Flex to book and back:** `POSE book`, then `POSE flex`, with no `STOP` and no `CONNECT` between.
  - **Flat and back:** `POSE flat`, then `POSE flex`, with no `STOP` and no `CONNECT` between.
  - **Shut and reopen:** `STOP`, then `CONNECT` and `PLAYING`.
  - **Tent:** as Task 5 Step 4. On the simulator the outer screen is only reached through `closed`, so "flex to tent without a break" cannot be checked there; say so.
  - **Leaving the app:** press `HOME`: `STOP` within three seconds. Open the app again: `CONNECT`, `PLAYING`.
  - **No hinge:** on the iPhone 17 simulator used in the first acceptance pass, the app shows the full radio upright and the standby face on its side, and the strip tunes.

- [ ] **Step 3: Update `README.md`.** Rewrite the opening and "how to use it" for the five poses and the tape, including how to reach each pose on the simulator. Remove the debug slider section. Add a section "Poses pass (date, commit)" with what Step 2 saw. Head the two older acceptance sections with one line saying they describe the earlier build, where the hinge tuned. Update the not-verified list: how the tape feels under a finger, how it sounds, a real phone, moving from flex to tent without a break, and tent itself if Decision 6 said it could not be checked.

- [ ] **Step 4: Commit.**

```bash
git add -A README.md docs/check
git commit -m "docs: poses acceptance pass and README for touch tuning and standby"
```
