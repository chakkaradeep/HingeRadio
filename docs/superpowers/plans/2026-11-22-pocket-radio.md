# Pocket Radio Face Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The flex face becomes a pocket radio with a side tuning wheel and a side volume wheel that clicks on, and a closed phone keeps playing and shows standby.

**Architecture:** Rules stay in `Packages/RadioCore`: power and loudness come from one wheel value, and no pose silences the radio. The app replaces the tape, keys and power button with a grille, a band switch and two wheels.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Testing. No new libraries.

**Spec:** `docs/2026-11-22-pocket-radio-design.md`, which amends `docs/2026-11-22-hinge-radio-poses-design.md`.

## Global Constraints

- No outside libraries. System fonts. Colours from `App/Views/Face.swift` only. No personal names or addresses.
- Dial numbers and snap rules unchanged. The hinge never tunes.
- Sound follows power alone: no pose silences the radio. Leaving the app still does (`appIsActive` unchanged).
- Volume wheel: travel 0 to 1; off below 0.15; on from 0.15; starts at 0.
- Roll up on the tuning wheel = up the band. One wheel height = 0.25 of the band.
- Every control has a tap path and a VoiceOver path; touch targets at least 44 pt; no label under 13 pt; wheels at least 44 pt apart and inside the plate's padding.
- Nothing important within `Face.foldClearance` (14 pt) of the fold.
- Simulator: the iPhone Duo with UDID `6FBE2E12-829F-4E36-AACD-4F03F4E0638E` only, muted (`-HingeRadioMuted YES`). Build, launch and log commands as in `docs/superpowers/plans/2026-11-22-hinge-radio-poses.md`.
- Commit locally after each task with the Co-Authored-By trailer. Never push.

## Review Focus

1. **Volume wheel dragged past either end, or given not-a-number.** Expected: clamps to 0 or 1; no crash. Pinned in Task 1 (`wheelClampsAndIgnoresNaN`).
2. **Rolling the volume wheel to off while a station is connecting.** Expected: silent at once, nothing starts late. Pinned in Task 1 (`wheelOffSilences`).
3. **Closing the phone while playing.** Expected: no stop, no reconnect. Pinned in Task 1 (`shutKeepsPlaying`) and Task 2 Step 5.
4. **A city with no stations, or all dead.** Expected: the wheel rolls on static; no crash. Existing `emptyFileIsStaticOnly`; Task 2 guards zero marks.
5. **A touch that starts on one wheel and drifts onto the other.** Expected: it keeps driving the wheel it started on. Task 2 Step 3.

---

### Task 1: Power and loudness from one wheel; closed keeps playing

**Files:**
- Modify: `Packages/RadioCore/Sources/RadioCore/Radio.swift`, `Mix.swift`
- Test: `Packages/RadioCore/Tests/RadioCoreTests/RadioTests.swift`, `MixTests.swift`
- Modify: `App/RadioModel.swift`

**Interfaces — produces:**

```swift
// Radio
public static let wheelOnFrom = 0.15
public private(set) var wheel: Double              // 0...1, starts at 0
public var powerOn: Bool { wheel >= Self.wheelOnFrom }
public var loudness: Double                        // 0 when off; 0.2 at wheelOnFrom rising linearly to 1 at wheel 1
public mutating func setWheel(_ value: Double)     // clamps 0...1; not-a-number ignored
public mutating func togglePower()                 // off -> the last on value (0.6 if never on); on -> 0
public var isLive: Bool { powerOn && !isSuspended } // pose no longer matters
// display(playback:) no longer returns the "Closed" copy for shut; shut shows what tent shows. The flat copy stays.

// RadioModel
func setWheel(_ value: Double)
var wheel: Double { get }
// updateSound multiplies the station and static levels by radio.loudness.
```

- [ ] **Step 1: Write the failing tests** in `RadioTests.swift` (using the existing `file`, `shut`, `flex` helpers):

```swift
@Test func wheelSwitchesOnAtTheClick() {
    var radio = Radio(file: file)
    #expect(!radio.powerOn)
    radio.setWheel(0.14)
    #expect(!radio.powerOn)
    #expect(radio.loudness == 0)
    radio.setWheel(0.15)
    #expect(radio.powerOn)
    #expect(abs(radio.loudness - 0.2) < 1e-9)
    radio.setWheel(1)
    #expect(abs(radio.loudness - 1) < 1e-9)
}

@Test func wheelClampsAndIgnoresNaN() {
    var radio = Radio(file: file)
    radio.setWheel(7)
    #expect(radio.wheel == 1)
    radio.setWheel(-3)
    #expect(radio.wheel == 0)
    radio.setWheel(0.5)
    radio.setWheel(.nan)
    #expect(radio.wheel == 0.5)
}

@Test func wheelOffSilences() {
    var radio = Radio(file: file)
    radio.setWheel(0.8)
    #expect(radio.station?.frequency == 98.0)
    radio.setWheel(0.1)
    #expect(radio.station == nil)
    #expect(!radio.isLive)
}

@Test func toggleReturnsToTheLastLoudness() {
    var radio = Radio(file: file)
    radio.togglePower()
    #expect(abs(radio.wheel - 0.6) < 1e-9)
    radio.setWheel(0.9)
    radio.togglePower()
    #expect(radio.wheel == 0)
    radio.togglePower()
    #expect(abs(radio.wheel - 0.9) < 1e-9)
}

@Test func shutKeepsPlaying() {
    var radio = Radio(file: file)
    radio.setWheel(0.8)
    radio.setPose(shut)
    #expect(radio.isLive)
    #expect(radio.station?.frequency == 98.0)
    #expect(radio.display(playback: .playing).title == "KSEA Name")
}
```

  Update the tests this changes: `shuttingSilencesAndReopeningResumes` is deleted; `everyPoseButShutPlays` becomes `everyPosePlays` and includes `shut`; in `displayCopy` the shut expectation becomes the station's own copy. Every other test that calls `togglePower()` keeps passing unchanged.

- [ ] **Step 2: Run to see them fail**, then implement, then run the whole package: all pass.
- [ ] **Step 3: `RadioModel`** exposes `wheel` and `setWheel`, multiplies both levels by `radio.loudness`, and gives the click and haptic when `powerOn` changes.
- [ ] **Step 4: Build the app** (the old power button still calls `togglePower()` until Task 2). Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 5: Commit** `feat: power and loudness from one wheel; closed keeps playing`.

---

### Task 2: The pocket radio face

**Files:**
- Create: `App/Views/WheelView.swift`, `App/Views/GrilleView.swift`, `App/Views/BandSwitch.swift`
- Modify: `App/Views/PlateView.swift`, `App/Views/DialView.swift`, `App/Views/StandbyView.swift`, `App/Views/LampLight.swift`, `App/RootView.swift`
- Delete: `App/Views/TapeView.swift`, `App/Views/PowerButton.swift`

**Interfaces — consumes:** `model.tune(toPosition:)`, `model.position`, `model.glide(toPosition:)`, `model.settleOnLockedStation()`, `flickTarget`, `nextMark(above:/below:)`, `liveMarkPositions`, `model.setWheel`, `model.wheel`, `model.togglePower()`.

- [ ] **Step 1: `WheelView`**, one view used twice: a tall rounded bar with horizontal ridges that scroll with its value, half-hidden behind the plate's right edge. Parameters: the current value (0...1), a closure for a new value, a closure for release (with the predicted end value), and how much of the range one wheel height covers. Dragging up raises the value.
- [ ] **Step 2: Tuning wheel.** Height at least 180 pt, width at least 44 pt. One height = 0.25 of the band. On release: a flick glides to `flickTarget`; a slow release calls `settleOnLockedStation()`. Label `TUNING` printed beside it. VoiceOver: label "Tuning", value station name and frequency, adjustable to the next or previous station.
- [ ] **Step 3: Volume wheel.** Height at least 88 pt, above the tuning wheel with at least 44 pt between them. One height = the full 0 to 1. `OFF` and `ON` printed beside it with a dot showing the value. A tap toggles power. VoiceOver: label "Volume", value "Off" or a percentage, adjustable in steps of 0.1, and an activate action that toggles power. Each wheel owns its own gesture, so a touch keeps driving the wheel it started on.
- [ ] **Step 4: The plate and the dial.** `GrilleView`: round holes on a regular grid, filling the left of the plate. `BandSwitch`: a four-position slider labelled `BAND` with the city keys printed under it; tapping a position selects that city; VoiceOver reads it as a picker of four. `PlateView` holds the grille, the band switch and the two wheels; the keys, readout and power button are gone. `DialView`: the signal bars and the old lamp are replaced by one "tuned" lamp labelled `TUNED` (off, orange while tuning in, steady orange-red... use `Face.needle` for both lit states, dimmer while tuning in); the frequency is shown beside the station name. Delete `TapeView.swift` and `PowerButton.swift`.
- [ ] **Step 5: Standby and closed.** `StandbyView` replaces its power button with a tappable switch drawn as `OFF . ON`, at least 60 pt across, calling `togglePower()`. `RootView`: shut on the outer screen shows `StandbyView(twoPanels: false)`; shut on the inner screen (hinge under 20 degrees with the inner screen still lit) shows the standby face in the half or panel clear of the fold; `PoseCard` is used for flat only.
- [ ] **Step 6: Check on the simulator**, muted, in flex (`open`, 110, upright):
  - Roll the volume wheel up: a `CONNECT` and `PLAYING` follow; roll it down past the click: `STOP`.
  - Tap the volume wheel: on, then off.
  - Roll the tuning wheel slowly up: `LOCK` lines in rising order; down: falling order; a fast roll settles on a station.
  - Tap each band position: the city name changes.
  - With a station playing, `closed`: no `STOP`, no `CONNECT`; the outer screen shows the standby face with the station. Tap its switch: `STOP`.
  - Save `docs/check/40-pocket-flex.png`, `41-pocket-closed.png`, `42-pocket-book.png`; delete `30-flex-tape.png`; replace `21-flex.png`, `22-book.png`, `24-shut.png`, `25-tent.png`.
  - Look at each screenshot: nothing clipped or overlapping, nothing within 14 pt of the fold, labels legible.
- [ ] **Step 7: README.** Update the "how to use it" section for the wheels, band switch and closed standby; add a short dated section with what Step 6 saw; add to the not-verified list: how the wheels feel under a thumb, whether the right edge fights the system's edge gestures on a real phone.
- [ ] **Step 8: Commit** `feat: pocket radio face with side tuning and volume wheels; closed shows standby`.
