# Hinge Radio (US local, native) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A SwiftUI app on the iPhone Duo simulator where the hinge tunes a real FM dial for Seattle, New York, Chicago or Los Angeles, playing live streams with static in between.

**Architecture:** All rules live in a pure Swift package, `RadioCore` (station file, stretched dial scale, tuner, radio state, connection timing, sound mix), tested on the Mac with `swift test`. The app target is a thin shell: a hinge source, three views, an `AVPlayer` wrapper and a noise engine. A Python script builds the bundled station file from FCC and Radio Browser data.

**Tech Stack:** Swift 6.4, SwiftUI (`onHingeChange`), AVFoundation, Swift Testing, XcodeGen 2.45, Python 3.12 standard library.

**Spec:** `docs/2026-11-22-hinge-radio-us-local-design.md`. The web mock is `reference/hinge-radio.html`.

## Global Constraints

- **Precondition:** the owner has chosen the project folder and the session has moved there. All paths below are relative to it. `docs/` and `reference/` are already in it.
- iOS deployment target 27.1. Build with Xcode 27.2 for the simulator named `iPhone Duo` on iOS 27.2.
- No outside Swift libraries. Python uses the standard library only.
- Bundle identifier `com.example.HingeRadio`. HTTP User-Agent `HingeRadioPrototype/0.1`. No personal names or addresses anywhere.
- Do not set `UIRequiresFullScreen`. Set `NSAppTransportSecurity` → `NSAllowsArbitraryLoadsForMedia` = true.
- Cities and keys: Seattle `SEA`, New York `NYC`, Chicago `CHI`, Los Angeles `LA`. Ids `seattle`, `new-york`, `chicago`, `los-angeles`.
- At most 16 stations per city, unique frequencies, sorted by frequency, every one passing the stream check.
- Dial defaults: 70° = left end (87.5 MHz), 150° = right end (108.5 MHz), minimum spacing 4.5°, lock zone 3°, release margin 0.5°, fade 0.75°, closed below 45°. Task 1 may change the two end angles; nothing else.
- Timings: connect 0.24 s after the needle settles, hold 6 s after leaving, "No signal" after 12 s without sound.
- The radio starts off. Closing silences it. Reopening resumes if it was on.
- On a Duo the hinge is the only tuner. The debug slider exists in simulator builds only.
- Nothing important is drawn across the fold.
- System fonts. Colours: face `#F3F1EA`, face shade `#E4E1D8`, ink `#161616`, muted `#6A675F`, needle `#FF5B1F`, lamp `#2FBF6B`; identical in light and dark mode.
- Hinge postures are set with the iOS Simulator tool (`set_posture`, `posture`, `screenshot`). No command-line equivalent is known.
- Commit locally after each task. Never push.

## Review Focus

1. **A stream starts, then stalls.** Expected: "No signal" after 12 s and static returns, not silence forever. Pinned in Task 6 (`stallAfterPlayingFails`).
2. **Power off or city change while a station is still connecting.** Expected: it goes silent at once, never starts late, and is not marked "No signal". Pinned in Task 6 (`resetForgetsPending`).
3. **Odd hinge readings:** not-a-number, negative, above 180°, or a jump from 0° to 180°. Expected: the needle clamps or holds; no crash. Pinned in Task 3 (`badAnglesAreSafe`).
4. **The station file is empty or missing.** Expected: the dial shows static only; no crash. Pinned in Task 3 (`emptyFileIsStaticOnly`).
5. **A directory entry that is a playlist file (`.pls`, `.m3u`) or two picks on one frequency.** Expected: the build drops the playlist and stops with a clear message on the clash. Pinned in Task 4 (`test_playlist_types_rejected`, `test_same_frequency_rejected`).

---

### Task 1: Project skeleton and hinge probe

This is the gate from the spec's Risk 1. Nothing else starts until the measurements are written down.

**Files:**
- Create: `.gitignore`, `project.yml`, `App/HingeRadioApp.swift`, `App/HingeProbeView.swift`, `docs/hinge-measurements.md`

**Interfaces:**
- Produces: `HingeRadio.xcodeproj` with scheme `HingeRadio`; `docs/hinge-measurements.md` with the three decisions listed in Step 5.

- [ ] **Step 1: Start the repository.** `git init` if the folder is not already a repository. `.gitignore` holds `build/`, `HingeRadio.xcodeproj/`, `tools/cache/`, `__pycache__/`, `.DS_Store`.

- [ ] **Step 2: Write `project.yml`** for one iOS application target `HingeRadio` with sources `App`, using the identifiers, deployment target and plist keys from Global Constraints, Swift language version 6, iPhone device family, all orientations supported for now, and an empty `UILaunchScreen`.

- [ ] **Step 3: Write the probe.** `HingeProbeView` uses `.onHingeChange { old, new in … }` and shows, in large text: `new.hinge?.angle.degrees` to two decimals (or "no hinge"), the status, a count of updates received, and the view's size in points. `HingeRadioApp` shows it.

- [ ] **Step 4: Build and launch.**

Run: `xcodegen generate && xcodebuild -project HingeRadio.xcodeproj -scheme HingeRadio -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.2' -derivedDataPath build/DerivedData build`
Expected: `** BUILD SUCCEEDED **`. Launch `build/DerivedData/Build/Products/Debug-iphonesimulator/HingeRadio.app` with the simulator tool's `launch`.

- [ ] **Step 5: Measure and record.** With `set_posture`, visit closed, half open at 20°, 45°, 70°, 70.5°, 71°, 90°, 110°, 150°, 170°, and open. Screenshot each. In `docs/hinge-measurements.md` record a table (angle set, angle reported, status, which screen is lit, screenshot size) and these decisions:
  1. **End angles.** Keep 70° and 150° unless the inner screen is dark at either; otherwise the nearest angles at which it is lit.
  2. **Fold direction.** The interface orientation in which the fold runs left to right across the middle of the app. Later tasks lock the app to it.
  3. **Reading quality.** Whether a reading arrives before the hinge first moves, and the smallest change that produces a new reading. If that is coarser than 1.5°, or readings do not arrive, write "tune with the debug slider" here; the build continues regardless.

- [ ] **Step 6: Commit.** `git add -A && git commit -m "chore: project skeleton and hinge measurements"`

---

### Task 2: Station file and dial scale

**Files:**
- Create: `Packages/RadioCore/Package.swift`, `Packages/RadioCore/Sources/RadioCore/StationFile.swift`, `DialConfig.swift`, `DialScale.swift` (same folder)
- Test: `Packages/RadioCore/Tests/RadioCoreTests/StationFileTests.swift`, `DialScaleTests.swift`

**Interfaces:**
- Produces:

```swift
public struct Station: Codable, Hashable, Identifiable, Sendable {
    public let callSign: String, name: String, licenceCity: String
    public let frequency: Double            // MHz
    public let streamURL: URL
    public let homepage: URL?, radioBrowserID: String?
    public var id: String { callSign }
}
public struct City: Codable, Hashable, Identifiable, Sendable {
    public let id: String, name: String, key: String
    public let stations: [Station]
}
public struct StationFile: Codable, Sendable {
    public let generated: String
    public let cities: [City]
    public static let empty: StationFile
    public static func load(from data: Data) throws -> StationFile   // decodes, then validates
}
public enum StationFileError: Error, Equatable {
    case unsorted(city: String), duplicateFrequency(city: String, frequency: Double)
    case tooManyStations(city: String, count: Int), outOfBand(city: String, callSign: String)
}
public struct DialConfig: Sendable, Equatable {
    public var minAngle = 70.0, maxAngle = 150.0, minFrequency = 87.5, maxFrequency = 108.5
    public var minSpacing = 4.5, lockWidth = 3.0, releaseMargin = 0.5, fadeWidth = 0.75, closedBelow = 45.0
    public init()
}
public struct DialScale: Sendable {
    public struct Mark: Sendable, Equatable { public let station: Station; public let angle: Double; public let position: Double }
    public init(stations: [Station], config: DialConfig)
    public let marks: [Mark]
    public func position(forAngle angle: Double) -> Double       // 0...1, clamped
    public func position(forFrequency frequency: Double) -> Double
    public func frequency(atPosition position: Double) -> Double
}
```

- [ ] **Step 1: Write the failing tests.** A helper `st(_ f: Double)` makes a station with call sign `"S\(f)"`. Use the values from Task 1 only through `DialConfig()`; these tests assume the defaults.

```swift
// StationFileTests
@Test func loadsValidFile()          // 1 city, 2 stations → cities[0].stations[1].frequency == 98.0
@Test func rejectsDuplicateFrequency() // 90.3 twice → .duplicateFrequency(city: "seattle", frequency: 90.3)
@Test func rejectsSeventeenStations()  // → .tooManyStations(city: "seattle", count: 17)
@Test func rejectsOutOfBand()          // 87.4 → .outOfBand
@Test func rejectsUnsorted()           // [98.0, 90.3] → .unsorted
@Test func allowsCityWithNoStations()

// DialScaleTests
@Test func straightWhenSpacingIsZero() {
    var c = DialConfig(); c.minSpacing = 0
    let s = DialScale(stations: [st(88.5), st(98.0)], config: c)
    #expect(abs(s.marks[0].angle - 73.8095) < 1e-3)
    #expect(abs(s.marks[1].position - 0.5) < 1e-9)
}
@Test func closePairIsPushedApartAndFarStationIsLeftAlone() {
    let s = DialScale(stations: [st(88.1), st(88.3), st(103.5)], config: DialConfig())
    #expect(abs(s.marks[0].angle - 71.5) < 1e-6)
    #expect(abs(s.marks[1].angle - 76.0) < 1e-6)
    #expect(abs(s.marks[2].angle - 130.95238) < 1e-4)
}
@Test func chicagoLowEndKeepsSpacingOrderAndBounds() {
    // 88.1 88.3 88.5 88.7 88.9 89.1 89.3 90.1 90.7 90.9 91.5 92.7 93.9 95.5 98.7 103.5
    // every neighbouring gap >= 4.5 - 1e-9; first >= 71.5; last <= 148.5; angles strictly increasing
}
@Test func spacingShrinksWhenTooManyToFit() {
    // 20 stations 88.1, 88.3 … 91.9 → every gap == 77.0 / 19 within 1e-9
}
@Test func scaleRoundTrips() {
    // frequency(atPosition: 0) == 87.5; (1) == 108.5; at each mark's position == its station's frequency;
    // position(forFrequency: frequency(atPosition: p)) ≈ p for p in 0, 0.05 … 1
}
@Test func anglesClamp() { // position(forAngle: 60) == 0; 160 == 1; 110 == 0.5 }
@Test func emptyScaleIsStraight() { // no marks; frequency(atPosition: 0.5) == 98.0 }
```

- [ ] **Step 2: Run them.** `swift test --package-path Packages/RadioCore`. Expected: build failure, types not defined.

- [ ] **Step 3: Implement.** `Package.swift` declares the library `RadioCore` and its test target, platforms iOS 27.1 and macOS 14. Placement of marks, in degrees:
  1. Ideal angle `a[i] = minAngle + (f[i] − minFrequency) / (maxFrequency − minFrequency) × (maxAngle − minAngle)`.
  2. Bounds `lo = minAngle + lockWidth / 2`, `hi = maxAngle − lockWidth / 2`. Spacing `s = min(minSpacing, (hi − lo) / (n − 1))` for `n > 1`.
  3. Let `b[i] = a[i] − i × s`. Replace `b` with its best non-decreasing fit by pooling adjacent violators (each run that is out of order becomes its mean).
  4. Clamp every `b[i]` into `lo ... hi − (n − 1) × s`, then `angle[i] = b[i] + i × s`.
  
  Frequency and position convert through straight lines between the anchors (87.5 at 0), each mark, (108.5 at 1).

- [ ] **Step 4: Run them.** Same command. Expected: all pass.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: station file and stretched dial scale"`

---

### Task 3: Tuner and radio state

**Files:**
- Create: `Packages/RadioCore/Sources/RadioCore/Tuner.swift`, `Radio.swift`
- Test: `Packages/RadioCore/Tests/RadioCoreTests/TunerTests.swift`, `RadioTests.swift`

**Interfaces:**
- Consumes: `Station`, `City`, `StationFile`, `DialConfig`, `DialScale` from Task 2.
- Produces:

```swift
public struct HingeReading: Sendable, Equatable {
    public var angle: Double        // degrees
    public var isClosed: Bool
    public var time: TimeInterval   // unused by the direct rule; kept for a later knob-style rule
    public init(angle: Double, isClosed: Bool, time: TimeInterval)
}
public struct TuningState: Sendable, Equatable {
    public var needle: Double         // 0...1; rests on the mark while locked
    public var frequency: Double      // MHz for the readout
    public var locked: Station?
    public var candidate: Station?    // locked, or the one station being faded toward
    public var strength: Double       // 1 while locked, falling to 0 across fadeWidth outside the zone
    public var edgeDistance: Double   // degrees outside the nearest zone, 0 inside
}
public struct Tuner: Sendable {
    public init(stations: [Station], config: DialConfig)
    public let scale: DialScale
    public private(set) var state: TuningState
    @discardableResult public mutating func update(_ reading: HingeReading) -> TuningState
}
public enum Playback: Sendable, Equatable { case idle, connecting, playing }
public enum Lamp: Sendable, Equatable { case off, seeking, locked }
public struct Display: Sendable, Equatable { public var title: String, subtitle: String; public var lamp: Lamp; public var bars: Int }
public struct Radio: Sendable {
    public init(file: StationFile, config: DialConfig = DialConfig())
    public let cities: [City]
    public private(set) var cityID: String        // first city, or "" when there are none
    public private(set) var powerOn: Bool         // starts false
    public private(set) var isClosed: Bool
    public private(set) var tuning: TuningState
    public private(set) var dead: Set<String>     // call signs, kept for the session
    public var scale: DialScale { get }
    public var isLive: Bool { get }               // powerOn && !isClosed
    public var station: Station? { get }          // tuning.candidate when live and not dead
    public mutating func togglePower()
    public mutating func selectCity(_ id: String) // unknown id: no change; keeps the last hinge reading
    public mutating func hinge(_ reading: HingeReading)   // closed when reading.isClosed || angle < closedBelow
    public mutating func markDead(_ callSign: String)
    public func display(playback: Playback) -> Display
}
```

`display` copy, exactly, checked in this order: closed → "Closed" / "Open the phone to listen again."; off → "Off" / "Switch on to listen"; live with no candidate → "· · ·" / "Static"; candidate in `dead` → station name / "No signal"; candidate not yet playing → name / "Tuning in", lamp `.seeking`; playing → name / `licenceCity`, lamp `.locked`, bars `max(1, Int((strength × 5).rounded()))`. Bars are 0 otherwise.

- [ ] **Step 1: Write the failing tests.** One station at 98.0 sits at 110°.

```swift
// TunerTests — r(_ angle) = HingeReading(angle: angle, isClosed: false, time: 0)
@Test func locksAndSnaps()        // 111.4 → locked 98.0, needle 0.5, frequency 98.0, strength 1
@Test func holdsWithinReleaseMargin() // 110 then 111.9 → still locked
@Test func releasesPastMargin()   // 110 then 112.1 → locked nil, needle 0.52625, strength ≈ 0.2, candidate 98.0
@Test func approachDoesNotLockEarly() // fresh, 111.9 → locked nil, strength ≈ 0.46667
@Test func staticBeyondFade()     // 113.0 → strength 0, candidate nil, edgeDistance 1.5
@Test func neighboursNeverOverlap() // stations 98.0, 98.2; at the midpoint of their two mark angles → strength < 1e-9, locked nil
@Test func badAnglesAreSafe() {
    // .nan → state unchanged from the previous reading; -20 → needle 0, frequency 87.5; 400 → needle 1;
    // 0 then 180 in one step → needle 1, no trap
}

// RadioTests — file with seattle [98.0] and chicago [90.1]
@Test func startsOff()            // hinge at 110 → station nil, display.title "Off"
@Test func powerOnPlaysLockedStation() // togglePower → station?.frequency == 98.0
@Test func closingSilencesAndReopeningResumes() // isClosed reading → station nil; open again → station back, powerOn still true
@Test func sliderAngleBelow45CountsAsClosed()   // angle 40, isClosed false → isClosed true
@Test func cityKeepsNeedle()      // selectCity("chicago") at 110° → station nil, tuning.needle 0.5; selectCity("nowhere") → cityID unchanged
@Test func deadStationIsSilentButShown() // markDead → station nil, tuning.locked non-nil, display.subtitle "No signal"
@Test func displayCopy()          // each row of the copy table above
@Test func emptyFileIsStaticOnly() // Radio(file: .empty): power on, hinge at 110 → station nil, title "· · ·", cityID ""
```

- [ ] **Step 2: Run them.** `swift test --package-path Packages/RadioCore`. Expected: build failure.

- [ ] **Step 3: Implement** both files. A station's zone is `lockWidth / 2` either side of its mark angle. It locks inside the zone and lets go only beyond the zone edge plus `releaseMargin`.

- [ ] **Step 4: Run them.** Expected: all pass.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: tuner and radio state"`

---

### Task 4: Station builder and the four city lists

**Files:**
- Create: `tools/build_stations.py`, `tools/corrections/seattle.json`, `new-york.json`, `chicago.json`, `los-angeles.json`, `App/Resources/Stations.json`
- Test: `tools/test_build_stations.py`, `Packages/RadioCore/Tests/RadioCoreTests/BundledStationsTests.swift`

**Interfaces:**
- Consumes: the `StationFile` JSON shape from Task 2 (keys exactly as the Swift property names).
- Produces: `App/Resources/Stations.json`, and

```python
CITIES: dict   # id -> {"name", "key", "lat", "lon", "states"}
def parse_fcc(text: str) -> list[dict]        # call, frequency, service, status, city, state, lat, lon
def distance_km(a: tuple[float, float], b: tuple[float, float]) -> float
def base_call(call: str) -> str               # drops -FM, -LP, -HD1…
def stream_candidates(station: dict, directory: list[dict]) -> list[dict]   # best first
def is_playable_type(content_type: str, url: str) -> bool
def apply_corrections(candidates: list[dict], corrections: dict) -> list[dict]
def check_stream(url: str, timeout: float = 10.0) -> bool
def main(argv: list[str]) -> int              # fetch | candidates <city> | build [--no-verify]
```

Pinned values:
- `CITIES`: seattle (47.6062, −122.3321, WA); new-york (40.7128, −74.0060, NY NJ CT); chicago (41.8781, −87.6298, IL IN); los-angeles (34.0522, −118.2437, CA). Radius 60 km.
- FCC: `https://transition.fcc.gov/fcc-bin/fmq?state={ST}&serv=FM&list=4&size=9`. Split each line on `|`; index 1 call, 2 frequency, 3 service, 9 status, 10 city, 11 state, 19–22 latitude (N/S, degrees, minutes, seconds), 23–26 longitude. Keep service `FM` with status `LIC`.
- Radio Browser: server list at `https://all.api.radio-browser.info/json/servers`, falling back to `de1.api.radio-browser.info`; then `/json/stations/search?countrycode=US&hidebroken=true&limit=100000`. Use `url_resolved`.
- Downloads are cached in `tools/cache/`.
- A directory entry matches when its name holds the base call sign as a whole word. Reject it when the name also holds an FM frequency other than the station's, or an AM frequency (530 to 1700) with no matching FM frequency. Order: last check ok, then `https`, then click count.
- Playable types: anything starting `audio/` except `audio/x-scpls` and `audio/x-mpegurl`; plus `application/vnd.apple.mpegurl` and `application/x-mpegurl`. A URL ending `.pls` or `.m3u` is never playable; `.m3u8` is.
- `check_stream` passes on HTTP 200, a playable type and at least one byte within the timeout.
- Corrections file: `{"pick": [call signs], "stations": {call: {"name", "stream", "exclude"}}}`, every key optional. With no `pick`, take up to 16 by click count, skipping any that share a frequency with one already taken. With a `pick`, more than 16, or two on one frequency, raises `ValueError` naming the city and the clash. Output is sorted by frequency.
- `build` checks every chosen stream. If any fail it lists their call signs, writes nothing and exits non-zero.

- [ ] **Step 1: Write the failing tests.** The FCC fixture is this one line:

```
|KUCC        |88.1  MHz |FM |201 |ND  |                    |A  |-  |LIC    |CLARKSTON                |WA |US |BLED-20131119BDR    |0.46   kW |0.46   kW |138.0   |138.0   |88292      |N |46 |27 |46.5  |W |116 |54 |28.5  |UPPER COLUMBIA MEDIA ASSOCIATION |
```

```python
def test_parse_fcc_line(self):        # the fixture → call "KUCC", frequency 88.1, city "CLARKSTON", lat ≈ 46.4629, lon ≈ -116.9079
def test_distance(self):              # Seattle to (47.2529, -122.4443) is between 39 and 41 km
def test_base_call(self):             # KEXP-FM→KEXP, KING-FM→KING, KNKX→KNKX, KMGP-LP→KMGP
def test_am_namesake_rejected(self):  # KJR-FM 93.3 vs ["1090 KJR", "KJR-FM 93.3 Seattle"] → only the second
def test_whole_word_match(self):      # KEXP vs ["KEXP", "KEXPX radio"] → only the first
def test_playlist_types_rejected(self):  # audio/x-scpls, a .pls URL, a .m3u URL → False; audio/mpeg, audio/aac, a .m3u8 URL with application/vnd.apple.mpegurl → True
def test_same_frequency_rejected(self):  # two picks on 89.9 → ValueError mentioning "89.9"
def test_seventeen_picks_rejected(self)
def test_corrections_apply(self):     # exclude drops; stream and name override; output sorted by frequency
```

```swift
@Test func bundledStationsLoad() {
    // read App/Resources/Stations.json relative to #filePath; StationFile.load succeeds;
    // city ids == ["seattle", "new-york", "chicago", "los-angeles"]; every city has 8...16 stations
}
```

- [ ] **Step 2: Run them.** `python3 -m unittest discover -s tools -p 'test_*.py'`. Expected: import error.

- [ ] **Step 3: Implement `tools/build_stations.py`.**

- [ ] **Step 4: Run the Python tests.** Expected: all pass.

- [ ] **Step 5: Build the lists.** Run `python3 tools/build_stations.py fetch`, then `candidates <city>` for each city, which prints call sign, frequency, city of licence and the proposed stream name and address. Write each corrections file by hand: fix wrong pairings, and pick up to 16 for variety (public, college, community, and commercial where one streams), never two on one frequency.

- [ ] **Step 6: Generate.** `python3 tools/build_stations.py build`. Expected last line: `4 cities, N stations, 0 failed`. When streams fail, choose another stream or station in the corrections file and rerun until none do. If a city cannot reach 8 passing stations, raise that city's radius to 80 km in `CITIES` and rerun.

- [ ] **Step 7: Run the Swift test.** `swift test --package-path Packages/RadioCore`. Expected: all pass, including `bundledStationsLoad`.

- [ ] **Step 8: Commit.** `git add -A && git commit -m "feat: station builder and four city lists"`

---

### Task 5: Screens and hinge source (silent radio)

**Files:**
- Create: `App/RadioModel.swift`, `App/HingeSource.swift`, `App/RootView.swift`, `App/Views/Face.swift`, `DialView.swift`, `PlateView.swift`, `ClosedCard.swift`, `DebugHingeSlider.swift` (same folder)
- Modify: `project.yml` (add the local package `Packages/RadioCore` as a dependency and lock orientations to the one recorded in Task 1; `App/Resources/Stations.json` is already picked up as a bundle resource), `App/HingeRadioApp.swift`
- Delete: `App/HingeProbeView.swift`

**Interfaces:**
- Consumes: `Radio`, `Display`, `Playback`, `HingeReading`, `DialScale` from Tasks 2 and 3; `Stations.json` from Task 4; the end angles and fold direction from `docs/hinge-measurements.md`.
- Produces:

```swift
@MainActor @Observable final class RadioModel {
    init(stationData: Data?)                 // nil or unreadable → StationFile.empty
    private(set) var radio: Radio
    var playback: Playback = .idle           // written by Task 6
    func hinge(_ reading: HingeReading)
    func togglePower()
    func selectCity(_ id: String)
    func markDead(_ callSign: String)
}
extension View { func hingeReadings(into model: RadioModel) -> some View }   // HingeSource.swift
```

- [ ] **Step 1: Wire the model and hinge source.** `hingeReadings` turns each `onHingeChange` context into a `HingeReading` (`angle.degrees`, `status == .closed`, the current uptime). When the context has no hinge, a horizontal drag on the dial glass supplies the angle instead: `minAngle + x / width × (maxAngle − minAngle)`. The model sits at 110° until the first reading arrives.

- [ ] **Step 2: Build the views** from the mock's lid and base (`reference/hinge-radio.html`, the `.dial` and `.plate` blocks) with the colours in Global Constraints.
  - `RootView`: `ClosedCard` when `radio.isClosed`; otherwise the dial filling exactly the half above the fold and the plate the half below, with no spacing and no view crossing the middle. Sizes scale with the half's width.
  - `DialView`: "HINGE RADIO", the city name, five signal bars, the lamp, the glass, then `display.title` and `display.subtitle`. The glass draws a tick at each whole MHz from 88 to 108 at `scale.position(forFrequency:)`, taller with a number every 4 MHz, one dot per mark (orange for the candidate, struck through when dead, no labels, not tappable) and the needle at `tuning.needle`.
  - `PlateView`: the dotted speaker grille, four keys labelled with each city's `key` (the current one pressed in), the readout `tuning.frequency` to one decimal with "MHz", and the power button.
  - `ClosedCard`: "Hinge Radio", then the closed copy from `display`.
  - The screen stays awake while `radio.isLive`.

- [ ] **Step 3: Add the debug slider**, compiled only under `#if targetEnvironment(simulator)`. A long press on "HINGE RADIO" shows or hides it. Range 24 to 160 in steps of 0.5. While it is showing it replaces hinge readings, and it prints the angle and frequency beside itself.

- [ ] **Step 4: Build and launch** with the Task 1 command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Check on the simulator.** Save screenshots to `docs/check/`.
  - Closed → the closed card on the outer screen.
  - Half open at 110° → dial above the fold, plate below, title "Off".
  - Tap power → lamp and title change; step the hinge to a Seattle mark's angle (print the marks once at launch to know them) → that station's name with "Tuning in"; step to a gap → "· · ·" and "Static".
  - Tap `CHI` → the city name and the marks change; the needle does not move.
  - Open flat → same layout; nothing crosses the fold in any screenshot.

- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: dial, plate and hinge source"`

---

### Task 6: Sound

**Files:**
- Create: `Packages/RadioCore/Sources/RadioCore/Connection.swift`, `Mix.swift`, `App/Audio/StationPlayer.swift`, `App/Audio/NoiseEngine.swift`
- Modify: `App/RadioModel.swift`
- Test: `Packages/RadioCore/Tests/RadioCoreTests/ConnectionTests.swift`, `MixTests.swift`

**Interfaces:**
- Consumes: `Station`, `Radio.station`, `Radio.isLive`, `TuningState.strength`, `.edgeDistance`, `RadioModel.playback`, `RadioModel.markDead`.
- Produces:

```swift
public struct Connection: Sendable {           // timing rules only; no audio
    public enum Action: Sendable, Equatable { case none, connect(Station), disconnect, fail(Station) }
    public init(settle: TimeInterval = 0.24, hold: TimeInterval = 6, failAfter: TimeInterval = 12)
    public private(set) var connected: Station?
    public mutating func want(_ station: Station?, at time: TimeInterval)
    public mutating func playerReported(_ station: Station, playing: Bool, at time: TimeInterval)
    public mutating func reset() -> Action       // .disconnect if anything was connected, forgets pending work
    public mutating func tick(at time: TimeInterval) -> Action
}
public struct Mix: Sendable, Equatable { public var station, staticLevel, whistle, whistleHz: Double }
public func mix(isLive: Bool, playing: Bool, strength: Double, edgeDistance: Double) -> Mix

@MainActor final class StationPlayer {         // owns one AVPlayer and a Connection, ticks every 0.1 s
    var onPlayback: ((Playback) -> Void)?
    var onFailed: ((Station) -> Void)?
    var volume: Float
    func want(_ station: Station?)
    func stop()
}
@MainActor final class NoiseEngine {           // AVAudioEngine: looped noise through a 1.7 kHz band-pass, a sine, a click
    func start() throws
    func stop()
    func set(staticLevel: Float, whistle: Float, whistleHz: Float)
    func click()
}
```

`Connection` rules: a wanted station connects once it has been wanted for `settle` without a change. After `want(nil)` the connection is kept for `hold`. `.fail` comes `failAfter` after connecting with no sound, or `failAfter` after sound stops; it also drops the connection and forgets the wanted station. Reports about a station that is no longer connected are ignored.

`mix`, exactly, with `live = (isLive && playing) ? strength : 0`: `station = live^1.3`; `staticLevel = isLive ? 0.015 + 0.24 × (1 − live)^1.6 : 0`; `whistle = (isLive && 0 < edgeDistance < 2.25) ? 0.012 × sin(π × edgeDistance / 2.25) : 0`; `whistleHz = 180 + 700 × edgeDistance`.

- [ ] **Step 1: Write the failing tests.**

```swift
// ConnectionTests — stations A, B, C
@Test func sweepingConnectsOnlyTheLast()  // want A@0, B@0.1, C@0.2; tick@0.3 → .none; tick@0.45 → .connect(C)
@Test func holdsThenDrops()               // connected A; want nil@10; tick@15.9 → .none; tick@16 → .disconnect
@Test func returningWithinHoldKeepsIt()   // connected A; want nil@10; want A@12; tick@20 → .none; connected == A
@Test func neverStartingFails()           // connect A@0.24; tick@12.2 → .none; tick@12.25 → .fail(A)
@Test func stallAfterPlayingFails()       // A playing@1; playerReported(A, playing: false)@5; tick@16.9 → .none; tick@17 → .fail(A)
@Test func resetForgetsPending() {
    // want A@0; reset()@0.1 → .none (nothing connected); tick@1 → .none
    // connected A, not yet playing; reset() → .disconnect; tick@13 → .none (no .fail); playerReported(A, playing: true)@14 changes nothing
}

// MixTests
@Test func offIsSilent()        // isLive false → all four are 0 except whistleHz, which is unchecked
@Test func lockedAndPlaying()   // strength 1 → station 1, staticLevel 0.015, whistle 0
@Test func connectingIsAllStatic() // playing false → station 0, staticLevel 0.255
@Test func halfStrength()       // strength 0.5 → station ≈ 0.4061, staticLevel ≈ 0.0942 (within 1e-3)
@Test func whistlePeaksMidGap() // edgeDistance 1.125 → whistle ≈ 0.012
```

- [ ] **Step 2: Run them.** `swift test --package-path Packages/RadioCore`. Expected: build failure.

- [ ] **Step 3: Implement `Connection` and `mix`.** Run again. Expected: all pass.

- [ ] **Step 4: Implement `StationPlayer` and `NoiseEngine`, and wire `RadioModel`.**
  - The audio session uses the `.playback` category and is activated on first power on.
  - After every change to `radio`, the model calls `player.want(radio.station)`, sets the player volume and noise levels from `mix`, and calls `player.stop()` plus `noise.set(staticLevel: 0, whistle: 0, whistleHz: 0)` when not live.
  - `onFailed` calls `markDead`. `onPlayback` writes `playback`.
  - When `tuning.locked` changes to a station while live: `noise.click()` and one light impact haptic.
  - Log through `Logger(subsystem: "HingeRadio", category: "sound")`: `CONNECT <call>`, `PLAYING <call>`, `FAILED <call>`, `STOP`.

- [ ] **Step 5: Build, launch and check on the simulator.** Read the log with `xcrun simctl spawn booted log show --last 3m --predicate 'subsystem == "HingeRadio"' --style compact`.
  - Power on at a Seattle mark → `CONNECT` then `PLAYING` for that call sign; the lamp turns green and the subtitle shows the city of licence.
  - Sweep quickly across three marks and stop on the third → one `CONNECT`, for the third only.
  - Close → `STOP`. Reopen → `CONNECT` again for the same station.

- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: station playback, static and connection timing"`

---

### Task 7: Acceptance pass and README

**Files:**
- Create: `README.md`, `docs/check/` screenshots

- [ ] **Step 1: Run everything.** `swift test --package-path Packages/RadioCore` and `python3 -m unittest discover -s tools -p 'test_*.py'`. Expected: all pass.

- [ ] **Step 2: Walk the spec's "How we will know it works" list** on the simulator, in all four cities, saving one screenshot per city plus closed and flat. For each city, visit every mark's angle and note in the README any station that logged `FAILED`; remove it through the corrections file and rebuild if it fails twice.

- [ ] **Step 3: Write `README.md`:** what this is; how to generate the project, build and run; how to show the debug slider; how to rebuild the station lists; the measured hinge facts from Task 1; and what the simulator cannot show (hinge feel, haptics, how it sounds, which only the owner can judge by listening).

- [ ] **Step 4: Commit.** `git add -A && git commit -m "docs: acceptance pass and README"`
