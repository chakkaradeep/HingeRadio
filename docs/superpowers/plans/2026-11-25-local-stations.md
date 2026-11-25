# Local Stations (HERE) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fifth band, HERE, that finds and plays the real FM stations around the phone anywhere in the US.

**Architecture:** Pure rules (reading each source, filtering, matching, choosing, the HERE band's state) live in `Packages/RadioCore`, tested against saved real responses. The app adds a thin `StationFinder` (network, probe, cache), a `Locator`, and the HERE wiring and scan in `RadioModel`.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, CoreLocation, MapKit (`MKReverseGeocodingRequest`), URLSession, XcodeGen.

**Spec:** `docs/2026-11-22-local-stations-design.md`

## What a dry run of the spec showed (2026-11-25)

The rules were run once against the live sources:

| Place | In reach | With a stream | From iHeart | Without iHeart | Answered a probe | Time |
|---|---|---|---|---|---|---|
| Seattle | 29 | 25 | 23 | 4 | 24 of 25 | 4.4 s |
| Fargo | 21 | 15 | 14 | 3 | 15 of 15 | 3.5 s |
| Denver | 24 | 21 | 21 | 5 | 21 of 21 | 3.3 s |

1. **HERE is, in practice, iHeart.** Its lookup is undocumented and no permission for it is held. If it goes, HERE finds 3 to 5 stations.
2. **"Nearest 16" picks the wrong 16 (a change from the spec, for the owner to approve).** In Seattle 25 stations have streams. Nearest first keeps KMIH (30 watts, 9 km) and drops KZOK (73,000 watts, 30 km). This plan ranks by distance divided by the class's reach, so the stations that come in best win. It drops KMIH and brings in KZOK.
3. **Position goes to fewer places than the spec allows.** iHeart, NPR and Radio Browser are all searched by call sign, so only the FCC (and Apple, for the town name) gets the rounded position.

## Global Constraints

- No new third-party dependencies. `RadioCore` does no I/O.
- User-Agent on every request: `HingeRadio/1.0`. FCC also needs `Accept: */*`. Never send personal details.
- Position rounded to 0.01 degree (about 1 km) before any use. FCC radius 100 km. Request timeout 8 s. At most 6 lookups at once.
- Class reach, km: A 28, B1 39, C3 39, B 52, C2 52, C1 72, C0 83, C 92, D 10 (D is this plan's call); any other class 0.
- Only rows with service `FM` and status `LIC`. One per call sign. At most 16 on the dial, ranked by distance divided by reach (smallest first), then higher power, then lower frequency; frequencies unique, 88 to 108 MHz band limits of `DialConfig`.
- Streams `https` only, including after redirects. Order: iHeart, NPR, Radio Browser.
- Radio Browser only when the name holds both call sign and frequency, `lastcheckok == 1`, `ssl_error == 0`, `url_resolved` https.
- Cache: 7 days, grid 0.1 degree; refresh in the background when older than 24 h.
- Copy, exact: `HERE`, `Finding stations…`, `No stations found here`, `Location is off`.
- Build setting `HERE_CONDITION` (default `HERE`) compiles HERE in; `HERE_CONDITION=` leaves it, and every lookup, out of the app target (`#if HERE`).
- Simulator: only UDID 6FBE2E12-829F-4E36-AACD-4F03F4E0638E, always `-HingeRadioMuted YES`. No physical device until the owner asks.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No pushing.

## Review Focus

1. The owner picks another band, or leaves the app, mid-search: the late result must not move them or the needle (Task 6).
2. A source returns HTML, an empty body or half a response: that source is skipped, never a crash (Tasks 1, 2).
3. Outside the US, or at sea: the FCC returns no rows, and HERE says `No stations found here` (Tasks 1, 5).
4. Location allowed once, then refused in Settings: HERE says `Location is off` and recovers when allowed again (Task 5).
5. A refresh drops the station that is playing: the needle stays put and the dial moves under it without a crash (Task 3).

---

### Task 1: The FCC dial

**Files:** Create `Sources/RadioCore/FCCSearch.swift`, `Tests/RadioCoreTests/FCCSearchTests.swift`, `Tests/RadioCoreTests/Fixtures/fcc-seattle.txt` (all under `Packages/RadioCore`; tests read fixtures by `#filePath`, as `BundledStationsTests` does).

**Interfaces — Produces:**
```swift
public struct Place: Hashable, Codable, Sendable { public let latitude, longitude: Double
    public init(latitude: Double, longitude: Double)   // rounds to 0.01
    public var cacheKey: String }                      // 0.1 grid, e.g. "47.6,-122.3"
public struct Licence: Hashable, Sendable { public let callSign, city, stationClass: String
    public let frequency, kilowatts, distance: Double; public var baseCall: String; public var rank: Double }  // "KEXP-FM" -> "KEXP"
public func fccSearchURL(_ place: Place) -> URL
public func licences(fromFCC text: String) -> [Licence]
public func stationsInReach(_ licences: [Licence]) -> [Licence]   // filtered, one per call, ordered; not yet cut to 16
```

- [ ] **Step 1: Save the fixture.** Fetch `fccSearchURL(Place(latitude: 47.606, longitude: -122.332))` once with curl and the required headers; save unmodified.
- [ ] **Step 2: Failing tests**
  - URL for (47.606, -122.332) contains `dist=100`, `dlat2=47&mlat2=36&slat2=36`, `NS=N`, `dlon2=122&mlon2=19&slon2=48`, `EW=W`, `serv=FM`, `list=4`; a place whose seconds round to 60 carries into minutes.
  - `Place(47.6062, -122.3321)` equals `Place(47.61, -122.33)`; `cacheKey == "47.6,-122.3"`; -0.04 and 0.04 give the same key with no "-0.0".
  - From the fixture: KEXP-FM is 90.3, class C3, city "Seattle", under 5 km; KAOS (class A, about 79 km) parses but is not in reach; rows with STA, MOD or CP never appear; every call sign once.
  - Ordering: `rank` is distance divided by reach. Class C at 29.57 km (0.32) comes before class D at 9.27 km (0.93) and class C2 at 18.25 km (0.35). Equal ranks put the higher kilowatts first, then the lower frequency. In the fixture KZOK-FM comes before KMIH.
  - `""`, `"<html>busy</html>"`, a row cut mid-line and a row with a missing distance all give no crash and no bogus licence.
- [ ] **Step 3: Run** `swift test --filter FCCSearch`; expected: does not compile.
- [ ] **Step 4: Implement.** Split on `|` and trim. Fields by index: 1 call, 2 "90.3  MHz", 3 service, 7 class, 9 status, 10 city (title-case it), 14 "65.    kW"; distance is the field ending " km". Skip any row that lacks one.
- [ ] **Step 5: Run** `swift test`; expected: all pass.
- [ ] **Step 6: Commit** `feat: FCC radius search rules`.

### Task 2: A stream for each station

**Files:** Create `Sources/RadioCore/StreamSources.swift`, `Tests/RadioCoreTests/StreamSourcesTests.swift`, fixtures `iheart-kzok.json`, `npr-kuow.json`, `rb-kexp.json` (real, trimmed to the fields read plus a few neighbours).

**Interfaces — Consumes:** `Licence`. **Produces:**
```swift
public struct StreamChoice: Hashable, Sendable { public let name: String; public let urls: [URL]; public let radioBrowserID: String? }
public enum StreamSource: CaseIterable, Sendable { case iHeart, npr, radioBrowser }   // in order
public func lookupURL(_ source: StreamSource, for licence: Licence, radioBrowserHost: String) -> URL
public func streamChoice(_ source: StreamSource, from data: Data, for licence: Licence) -> StreamChoice?
public func isPlayable(status: Int, contentType: String?, finalURL: URL) -> Bool
```

- [ ] **Step 1: Save fixtures** from `us.api.iheart.com/api/v2/content/liveStations?callLetters=KZOK`, `station.api.npr.org/v3/stations?q=KUOW`, `<host>/json/stations/search?countrycode=US&hidebroken=true&limit=50&name=KEXP`.
- [ ] **Step 2: Failing tests**
  - iHeart: KZOK at 102.5 gives name "102.5 KZOK" and https URLs, `secure_hls_stream` before `secure_shoutcast_stream`; the same data for 99.9, for another call sign, or with band "AM" gives nil; a hit with only `http` streams gives nil.
  - NPR: KUOW at 94.9 gives name "KUOW", https audio hrefs, primary stream first; a wrong frequency gives nil.
  - Radio Browser: a name with call sign and frequency passes and uses the base call sign as the name, with the entry's UUID; call only, frequency only, `lastcheckok` 0, `ssl_error` 1, or http gives nil; "WKEXP 90.3" does not match KEXP, and "190.3" does not match 90.3.
  - Each source with `Data()`, `<html>`, and `{}` gives nil.
  - `isPlayable`: 200 with `audio/mpeg`, `audio/aac`, `audio/aacp`, `application/vnd.apple.mpegurl` or `application/x-mpegurl` is true, parameters after `;` ignored; `audio/x-scpls`, `audio/x-mpegurl`, `text/html`, nil, 404, an http final URL, and a path ending `.pls` or `.m3u` are false.
- [ ] **Step 3: Run**; expected: does not compile. **Step 4: Implement** with `Codable` types private to the file, every field optional. **Step 5: Run** `swift test`; expected: all pass.
- [ ] **Step 6: Commit** `feat: iHeart, NPR and Radio Browser lookup rules`.

### Task 3: The HERE band in Radio

**Files:** Create `Sources/RadioCore/Here.swift`, `Tests/RadioCoreTests/HereTests.swift`. Modify `Radio.swift`, `Feel.swift`.

**Interfaces — Consumes:** `Licence`, `StreamChoice`. **Produces:**
```swift
public enum HereStatus: Sendable, Equatable { case idle, finding, ready, empty, locationOff }
public let hereID = "here"
public func hereStations(_ found: [(Licence, StreamChoice, URL)]) -> [Station]   // at most 16, unique, sorted by frequency
public struct HereDial: Codable, Sendable { public let town: String; public let stations: [Station]; public let savedAt: Date
    public func isUsable(at: Date) -> Bool       // under 7 days
    public func needsRefresh(at: Date) -> Bool } // over 24 hours
extension Radio {
    init(file:config:poseConfig:here: Bool)                    // adds City(id: hereID, name: "Here", key: "HERE", stations: []) last; here defaults to false
    private(set) var hereStatus: HereStatus; private(set) var isScanning: Bool
    mutating func setHere(status: HereStatus); mutating func setScanning(_ on: Bool)
    mutating func setHereStations(_ stations: [Station], town: String?) }
```

- [ ] **Step 1: Failing tests**
  - `here: false` gives today's cities exactly; `true` adds HERE last, and launch still starts on the first city.
  - `setHereStations` on another band changes nothing on the dial; on HERE it rebuilds the dial, keeps `position`, locks a station under the needle, clears `dead` for the call signs it brings, and sets the city name to the town.
  - Replacing the stations with a list that lacks the locked one leaves `position` as it was with no lock; an empty list is safe.
  - While scanning: `station` is nil, `feel` gives no `lockClick` but still gives `tuningTick`. A refresh of HERE's stations gives no feel at all.
  - `display` on HERE, powered on, no candidate: `finding` gives title "· · ·" and subtitle "Finding stations…"; `empty` "No stations found here"; `locationOff` "Location is off"; `ready` "Static". Scanning always says "Finding stations…". Off says nothing, and other bands are unaffected.
  - `hereStations`: 20 found keep 16 by Task 1's order, then sorted by frequency; two on one frequency keep the better ranked; a station outside `DialConfig`'s band is dropped.
  - `HereDial` usable at 6 d 23 h and not at 7 d 1 h; refresh at 25 h and not at 23 h; a Codable round trip is equal.
- [ ] **Step 2: Run**; expected: does not compile. **Step 3: Implement.** `cities` becomes `public private(set) var`. **Step 4: Run** `swift test`; expected: all pass, the old tests unchanged.
- [ ] **Step 5: Commit** `feat: HERE band state in Radio`.

### Task 4: The station finder

**Files:** Create `App/Here/StationFinder.swift`, `App/Here/HereCache.swift`. Modify `project.yml`: `HERE_CONDITION: HERE` and `SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) $(HERE_CONDITION)"`.

**Interfaces — Consumes:** Tasks 1 to 3. **Produces:**
```swift
actor StationFinder { func find(at place: Place, onFound: @Sendable ([Station]) async -> Void) async -> [Station]
                      func reportPlay(radioBrowserID: String) async }
struct HereCache { func load(_ place: Place) -> HereDial?; func save(_ dial: HereDial, for place: Place) }  // Caches/here/<cacheKey>.json
```

- [ ] **Step 1: Implement `find`**: FCC text (Latin-1), in-reach licences, then a task group of at most 6, best ranked first, stopping once 16 distinct frequencies are confirmed and no earlier licence is pending. Per licence: each source in order, then probe each URL; the first playable wins. `onFound` gets the confirmed list so far through `hereStations`. Cancellation stops every request.
- [ ] **Step 2: Probe**: GET through `URLSession.bytes(for:)`, 8 s, read one byte, judge with `isPlayable` using the response's final URL, cancel.
- [ ] **Step 3: Radio Browser host**: `getaddrinfo` on `all.api.radio-browser.info`, `getnameinfo` on each address, keep names ending `.api.radio-browser.info`, pick one at random, fall back to `de1.api.radio-browser.info`. `reportPlay` GETs `/json/url/<uuid>` and ignores the answer.
- [ ] **Step 4: Log** one `HERE` line each for the FCC count, every station (call, source, or "none"), and the total with seconds. Never log the position.
- [ ] **Step 5: Verify** with a temporary launch argument that runs `find` for Seattle; expected in the log: at least 14 stations in under 15 s. Remove the argument. Both builds succeed: plain, and with `HERE_CONDITION=`.
- [ ] **Step 6: Commit** `feat: on-phone station finder and cache`.

### Task 5: Location and the HERE position

**Files:** Create `App/Here/Locator.swift`. Modify `project.yml` (`NSLocationWhenInUseUsageDescription`: "Hinge Radio uses your approximate location to find the FM stations around you."; `NSLocationDefaultAccuracyReduced`: true), `App/RadioModel.swift`, `App/Views/BandSwitch.swift`, `App/HingeRadioApp.swift`.

**Interfaces — Produces:** `@MainActor final class Locator { func place() async throws(LocatorError) -> Place; func town(for: Place) async -> String? }`, `enum LocatorError: Error { case refused, unavailable }`.

- [ ] **Step 1: Locator** asks only when HERE is chosen, for reduced accuracy, one fix, 10 s limit; refused or restricted throws `.refused`. `town` uses `MKReverseGeocodingRequest` on the rounded place, nil on failure (the name stays "Here").
- [ ] **Step 2: Model**: `selectCity(hereID)` starts one search `Task`: locate, show a usable cached dial at once, and find only when there is none or it needs refreshing. Any other band, or the app going to the background (scene phase `.background`, not `.inactive`: the location prompt itself makes the app inactive), cancels it. `.refused` gives `.locationOff`; `.unavailable` or no stations and no cache gives `.empty`. A refresh that finds nothing keeps the cached dial. Choosing HERE again, or returning to the app on HERE, retries when the status is `.locationOff` or `.empty`, or when a search was cancelled by the background.
- [ ] **Step 3: BandSwitch** takes five positions: the doc comment, and labels must not overlap at em for a 669 pt width. VoiceOver picker reads "Here" or the town.
- [ ] **Step 4: Verify on the simulator** (`xcrun simctl location … set`, `xcrun simctl privacy … grant|revoke location com.example.HingeRadio`): Seattle plays and its dial shares at least 5 call signs with the bundled list; Fargo has at least 8; London says "No stations found here"; revoked says "Location is off", the four cities still play, and granting recovers it; a second Seattle visit shows its dial in under 1 s. Screenshots `docs/check/56-here-seattle.png`, `57-here-fargo.png`, `58-here-off.png`.
- [ ] **Step 5: Commit** `feat: HERE band`.

### Task 6: The scan

**Files:** Modify `App/RadioModel.swift`, `App/Views/ScaleFace.swift`.

- [ ] **Step 1: Sweep**: with no cached dial, `setScanning(true)` and glide 0 to 1 over 4 s linearly, repeating while the search runs, ticking as it passes ridges. `onFound` feeds `setHereStations` as stations arrive. When the search ends, scanning stops and the needle eases to the nearest station (`liveMarkPositions`). Reduce Motion: no sweep, the needle stays put.
- [ ] **Step 2: Interrupt**: touching the tuning wheel ends the sweep and leaves the search running, with no later jump of the needle. Changing band or leaving the app ends both.
- [ ] **Step 3: Dots** fade and scale in over 0.25 s and slide when the spacing shifts; with Reduce Motion they fade only.
- [ ] **Step 4: Verify**: screenshots mid-scan and after (`59-here-scan.png`); switch to CHI mid-search and check the needle and band stay; grab the wheel mid-search; background and return mid-search.
- [ ] **Step 5: Commit** `feat: HERE scans the dial`.

### Task 7: Credits and the record

**Files:** Create `App/Views/AboutCard.swift`. Modify `App/Views/DialView.swift`, `App/RadioModel.swift`, `README.md`, the spec (dry-run findings, narrower privacy).

- [ ] **Step 1: About card**: a long press on the flex badge, and a VoiceOver action "About the dial", open a sheet titled "About the dial": the FCC for stations and frequencies; iHeart, NPR and Radio Browser for streams; Apple for the town name; Yellowtail (Apache 2.0) for the lettering. Without `HERE` it leaves out iHeart, NPR and Apple. It has a visible Done button.
- [ ] **Step 2: Clicks**: when a HERE station with a `radioBrowserID` starts playing, call `reportPlay` once per start.
- [ ] **Step 3: README**: HERE, what is sent where, the build switch, and that HERE depends mostly on iHeart.
- [ ] **Step 4: Verify** both builds; `swift test`; the station builder's tests; that flex, book, closed and flat look as before on a bundled city. Screenshot `60-about.png`.
- [ ] **Step 5: Commit** `feat: about card, play counts and README`.
