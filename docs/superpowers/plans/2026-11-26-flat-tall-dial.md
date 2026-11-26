# Flat Tall Dial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the approved spike into the real face for the fully open (flat) pose: the Tall dial, upright and on its side, with the sliding tape.

**Architecture:** The tape's arithmetic becomes a value type in RadioCore (`DialTape`) with tests. The app's `FlatView` and `TallDial` (already on the branch from the spike) consume it, measure names once, and draw. `Radio.display` stops replacing the station in flat; `PoseCard` goes.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing (`#expect`) in the RadioCore package, XcodeGen.

**Spec:** `docs/2026-11-26-flat-tall-dial-design.md`

## Global Constraints

- Work on branch `flat-tall-dial` (rename of `spike/flat-tall-dial`, which holds the spike's uncommitted files). Never push or merge without the owner's say-so.
- XcodeGen writes the project and Info.plist: after adding or removing a source file run `xcodegen generate`; never hand-edit `App/Info.plist`.
- Device builds pass `DEVELOPMENT_TEAM=<TEAM_ID>` (xcodegen drops the team). Device: CDuo `<device-udid>`. Simulator, if its access is granted: `D73C36C4-031D-4161-A5C0-FE09DA26ACF1` only, launched with `-HingeRadioMuted YES`.
- Package tests: `cd Packages/RadioCore && swift test` (343 passing before this work).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never commit `.superpowers/`.
- Keep the approved look: sizes and gaps as in the spike's `App/Views/FlatView.swift`.

## Review Focus

1. A band with no stations (HERE before its search ends): the dial shows ticks and the needle only, no crash; the tape is the glass's length. Pinned in Task 1 (`emptyBandFitsTheGlass`).
2. Two stations almost on the same frequency: their dots never swap order or overlap; coordinates rise with position. Pinned in Task 1 (`crowdedNeighboursGetTheirRoom`, `coordinatesNeverGoBackwards`).
3. The needle at 88 or 108 with a slid tape: the tape stops and the needle reaches the glass's end. Pinned in Task 1 (`offsetStopsAtEitherEnd`).
4. A first station close to 88 with a wide name: its name never starts before the tape does. Pinned in Task 1 (`firstNameStartsOnTheTape`).
5. Changing band while the tape is slid: the new band's tape is laid out afresh, with no stale offset. The offset is a pure function of the tape and the needle, so checked by eye on CDuo in Task 3.

---

### Task 1: DialTape in RadioCore

**Files:**
- Create: `Packages/RadioCore/Sources/RadioCore/DialTape.swift`
- Test: `Packages/RadioCore/Tests/RadioCoreTests/DialTapeTests.swift`

**Interfaces:**
- Produces: `public struct DialTape: Sendable, Equatable` with
  - `public init(positions: [Double], rooms: [Double], view: Double)`: `positions` are the marks' positions (0...1) in dial order, `rooms` the room each mark's name needs along the dial (points), `view` the glass's usable length (points).
  - `public let length: Double`
  - `public func coordinate(_ position: Double) -> Double`: where a band position falls along the tape, in points from 88's end; clamped to `0...length`.
  - `public func offset(needle: Double) -> Double`: how far the tape has slid: 0 when `length <= view`; else `coordinate(needle) - view / 2` clamped to `0...(length - view)`.

- [ ] **Step 0: Rename the branch**

Run: `git branch -m spike/flat-tall-dial flat-tall-dial`

- [ ] **Step 1: Write the failing tests** (`@Test` functions, Swift Testing)

```swift
@Test func fittingBandKeepsItsOwnSpacing() {
    let tape = DialTape(positions: [0.25, 0.5, 0.75], rooms: [10, 10, 10], view: 100)
    #expect(tape.length == 100)
    #expect(tape.coordinate(0.5) == 50)
    #expect(tape.offset(needle: 0.5) == 0)
}

@Test func crowdedNeighboursGetTheirRoom() {
    let tape = DialTape(positions: [0.5, 0.51], rooms: [40, 40], view: 100)
    #expect(tape.coordinate(0.5) == 50)
    #expect(abs(tape.coordinate(0.51) - 90) < 1e-9)      // 50 + max(1, 40)
    #expect(abs(tape.length - 139) < 1e-9)               // 90 + max(49, 20)
}

@Test func offsetHoldsTheNeedleInTheMiddle() {
    let tape = DialTape(positions: [0.5, 0.51], rooms: [40, 40], view: 100)
    #expect(abs(tape.offset(needle: 0.51) - 40) < 1e-9)  // 90 - 50
}

@Test func offsetStopsAtEitherEnd() {
    let tape = DialTape(positions: [0.5, 0.51], rooms: [40, 40], view: 100)
    #expect(tape.offset(needle: 0) == 0)
    #expect(abs(tape.offset(needle: 1) - 39) < 1e-9)     // length - view
}

@Test func emptyBandFitsTheGlass() {
    let tape = DialTape(positions: [], rooms: [], view: 100)
    #expect(tape.length == 100)
    #expect(abs(tape.coordinate(0.3) - 30) < 1e-9)
    #expect(tape.offset(needle: 0.9) == 0)
}

@Test func firstNameStartsOnTheTape() {
    let tape = DialTape(positions: [0.02], rooms: [60], view: 100)
    #expect(tape.coordinate(0.02) == 30)                 // max(2, 60 / 2)
    #expect(tape.coordinate(0) == 0)
}

@Test func coordinatesNeverGoBackwards() {
    let positions = [0.1, 0.1001, 0.11, 0.5, 0.5002, 0.9]
    let tape = DialTape(positions: positions, rooms: Array(repeating: 70, count: positions.count), view: 300)
    let samples = stride(from: -0.1, through: 1.1, by: 0.001).map(tape.coordinate)
    #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
    #expect(tape.coordinate(-1) == 0)
    #expect(abs(tape.coordinate(2) - tape.length) < 1e-9)
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `cd Packages/RadioCore && swift test --filter DialTape`
Expected: build failure, `cannot find 'DialTape' in scope`.

- [ ] **Step 3: Implement `DialTape`**

Piecewise-linear anchors, as in the spike's `TallDial.Tape` (`App/Views/FlatView.swift`), in `Double`: start at `(0, 0)`; for each mark add `max((position - lastPosition) * view, (lastRoom + room) / 2)`; end at `(1, at + max((1 - lastPosition) * view, lastRoom / 2))`. `coordinate` interpolates between the two anchors around the clamped position. `view` is stored for `offset`.

- [ ] **Step 4: Run the tests**

Run: `cd Packages/RadioCore && swift test`
Expected: all pass (343 + 7).

- [ ] **Step 5: Commit**

```bash
git add Packages/RadioCore/Sources/RadioCore/DialTape.swift Packages/RadioCore/Tests/RadioCoreTests/DialTapeTests.swift
git commit -m "Add DialTape: the flat dial's room per station and how far it slides"
```

### Task 2: Flat shows the station; PoseCard goes

**Files:**
- Modify: `Packages/RadioCore/Sources/RadioCore/Radio.swift` (the spike already removed the "Fold me" branch in `display(playback:)`; keep that)
- Modify: `Packages/RadioCore/Tests/RadioCoreTests/RadioTests.swift:177-179`
- Modify: `App/RootView.swift` (the `.flat` case and the type's doc comment)
- Delete: `App/Views/PoseCard.swift`
- Add (as the spike left it; Task 3 refines it): `App/Views/FlatView.swift`. `HingeRadio.xcodeproj` is git-ignored; XcodeGen makes it.

**Interfaces:**
- Consumes: nothing new.
- Produces: `RootView` shows `FlatView(model:about:)` for `.flat` on any screen (Task 3 adds `about`).

- [ ] **Step 1: Change the test** at `RadioTests.swift:177-179` to:

```swift
radio.setPose(flat)
#expect(radio.display(playback: .playing).title == "KSEA Name")   // flat shows the station, as flex does
```

- [ ] **Step 2: Run it**

Run: `cd Packages/RadioCore && swift test --filter RadioTests`
Expected: PASS (the spike's change to `Radio.swift` already makes it pass; this step pins it).

- [ ] **Step 3: Remove `PoseCard`**

In `RootView`, the `.flat` case becomes the single line showing `FlatView` (no outer-screen branch: `pose(_:)` returns `.tent` for the outer screen before it can return `.flat`). Update `RootView`'s doc comment: flat shows the tall dial. Delete `App/Views/PoseCard.swift`, then run `xcodegen generate`.

- [ ] **Step 4: Build for the simulator**

Run: `xcodebuild -project HingeRadio.xcodeproj -scheme HingeRadio -destination 'id=D73C36C4-031D-4161-A5C0-FE09DA26ACF1' -derivedDataPath build/DerivedData build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Packages/RadioCore App/RootView.swift App/Views/PoseCard.swift App/Views/FlatView.swift
git commit -m "Flat shows the tall dial in place of the Fold me card"
```

### Task 3: FlatView on DialTape, names measured once, About in flat

**Files:**
- Modify: `App/Views/FlatView.swift` (from the spike)
- Modify: `App/RootView.swift` (About sheet in flat; pass `about`)

**Interfaces:**
- Consumes: `DialTape(positions:rooms:view:)`, `.length`, `.coordinate(_:)`, `.offset(needle:)` from Task 1.
- Produces: `FlatView(model: RadioModel, about: @escaping () -> Void)`.

- [ ] **Step 1: Use `DialTape`**

Delete `TallDial.Tape`; build a `DialTape` from `marks.map(\.position)`, the rooms (upright `1.3 * labelSize`, on its side `width + 0.8 * em`) and `Double(geometry.length)`, converting to `CGFloat` where drawing.

- [ ] **Step 2: Measure names once**

Replace the per-body `NSString.size` calls with a lookup in a `@MainActor` static cache keyed by call sign and label size (`[String: CGFloat]`), filled on first use. Every frame of a turn reads the needle; none measures text.

- [ ] **Step 3: About in flat**

`FlatView` takes `about`; its badge gets `.accessibilityAction(named: "About the dial", about)` and `.onLongPressGesture(perform: about)`, as `DialView`'s does. In `RootView`, pass `{ aboutShown = true }` and keep the sheet open while the pose is `.flex` or `.flat` (the `onChange` closes it for any other pose).

- [ ] **Step 4: Remove the spike's labels**

Doc comments lose "SPIKE"; the comment in `RootView`'s `.flat` case goes. Keep `FlatSnapshots` for now (Task 4 uses it, then deletes it).

- [ ] **Step 5: Build, install and check on CDuo**

Run the device build with `DEVELOPMENT_TEAM=<TEAM_ID>`, install with `xcrun devicectl device install app`, launch with `-- -HingeRadioMuted YES -HingeRadioFlatSnapshots YES`, and copy `Documents/flat` off with `xcrun devicectl device copy from` into `.superpowers/sdd/2026-11-26-flat-tall-dial/flat-shots/` (Task 4 takes its pictures from there). If the launch reports `Locked`, the phone is locked: stop and report it.
Expected: `notes.txt` ends in `done` and shows band `seattle` after "choosing seattle". The ten pictures match the approved look; one-line names keep their city right under them; 107.x stays on one line; the Seattle side view's tape is slid with a soft left edge.

- [ ] **Step 6: Commit**

```bash
git add App/Views/FlatView.swift App/RootView.swift
git commit -m "Flat: the tall dial on DialTape, names measured once, About in flat"
```

### Task 4: Screenshots, README, remove the checking aid

**Files:**
- Create: `docs/check/70-flat-up.png`, `docs/check/71-flat-side.png`, `docs/check/72-flat-side-seattle.png` (from Task 3's run: `2-on-up`, `2-on-side`, `3-city-on-side`)
- Modify: `README.md` (line 10 summary, the poses table row at 61, the Flat section at 129-131, the check step at 139, the paragraph at 285 that says flat still shows "Fold me")
- Modify: `App/Views/FlatView.swift`, `App/RootView.swift` (delete `FlatSnapshots` and its `onAppear`)

- [ ] **Step 1: Copy the three pictures** into `docs/check/` under the names above.

- [ ] **Step 2: Update the README**

Table row: `| Flat | Fully open | The tall dial | Plays |`. The Flat section describes the face and the tape in three or four sentences, pointing at the three pictures. Line 285's "Flat still shows "Fold me" with no wheels." becomes a sentence saying flat now has the same wheels.

- [ ] **Step 3: Delete the checking aid** (`FlatSnapshots` and the `#if DEBUG` `onAppear` in `RootView`).

- [ ] **Step 4: Verify**

Run: `cd Packages/RadioCore && swift test` and the device build.
Expected: all tests pass; `** BUILD SUCCEEDED **`; `grep -rn "FlatSnapshots\|SPIKE\|Fold me" App Packages` prints nothing. In `README.md`, only the dated check logs (past runs, which record what the app did then) may still mention "Fold me"; the summary, the poses table, the Flat section and the wheels paragraph must not.

- [ ] **Step 5: Install on CDuo** (normal launch, sound on) and commit

```bash
git add README.md docs/check/70-flat-up.png docs/check/71-flat-side.png docs/check/72-flat-side-seattle.png App/Views/FlatView.swift App/RootView.swift docs/2026-11-26-flat-tall-dial-design.md docs/superpowers/plans/2026-11-26-flat-tall-dial.md
git commit -m "Document the flat tall dial; remove the checking aid"
```
