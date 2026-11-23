# Hinge Radio

Hinge Radio is a small SwiftUI app for the iPhone Duo, a folding iPhone. It is an FM radio with a dial. You pick one of four cities (Seattle, New York, Chicago or Los Angeles) and tune across that city's real FM stations, which play over the internet. You tune with a finger, on a sliding tape on the lower half of the inner screen. The hinge does not tune. It only tells the app how the phone is folded, and the app shows a different face for each way of folding. It is a prototype that runs in the iPhone Duo simulator only; it has not been put on a real phone.

## How to run it

You need Xcode 27.2 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). The Xcode project file is generated, not stored.

A Mac can have more than one simulator named "iPhone Duo" (the one this was built on has three), so use the device id rather than the name. List them and pick one:

```
xcrun simctl list devices | grep Duo
```

Then, with `<id>` standing for the chosen device id:

```
xcodegen generate
xcodebuild -project HingeRadio.xcodeproj -scheme HingeRadio \
  -destination 'platform=iOS Simulator,id=<id>' \
  -derivedDataPath build/DerivedData build
```

To launch it, either open `HingeRadio.xcodeproj` in Xcode, choose that simulator and press Run, or from the command line:

```
xcrun simctl boot <id>          # skip if it is already running
xcrun simctl install <id> build/DerivedData/Build/Products/Debug-iphonesimulator/HingeRadio.app
xcrun simctl launch <id> com.example.HingeRadio
```

## How to use it

The phone has five poses. The app works out which one from the hinge angle, which screen is lit and which way up the screen is. Each pose is written to the log as `POSE <name>` when it changes.

| Pose | How the phone is | What the app shows | Sound |
|---|---|---|---|
| Flex | Partly folded, inner screen, upright | The full radio | Plays |
| Book | Partly folded, inner screen, on its side | Standby face: station name, the line under it, frequency, lamp, power button | Plays |
| Tent | Partly folded, outer screen | The same standby face | Plays |
| Flat | Fully open | A "Fold me" card | Plays |
| Shut | Closed | A "Closed" card | Silent |

"Plays" means the radio is switched on and the app is in front. The design is that moving between poses never cuts the sound. This held in the moves checked (flex to book, flex to flat, and back); flex to tent without a break was not checked. Only shutting the phone, switching off, or leaving the app does.

### Flex: the radio

The top half is the dial: a lamp, the city name, the needle, and a row of dots for the stations. It does not respond to touch. The lower half has the four city keys (SEA, NYC, CHI, LA), the frequency readout, the round power button, and the tape.

1. Press the power button. The lamp goes green when a station is playing.
2. Drag the tape. It is the dial magnified three times, sliding under a fixed pointer in the middle. Each station shows its call sign and frequency. Drag left to go up the band.
3. Near a station the tape settles on it, the name and its city of licence appear, and the station plays. Between stations the screen says "Static".
4. A slow release stays where you let go. A quick flick carries on and settles on the nearest station. A tap on a station's label glides to that station.
5. A city key switches city. The dial redraws with that city's stations and the old city goes quiet at once. The needle stays where it was.

### Book and tent: standby

Same face on both. It is made to be read from across a room, with the station name and the frequency as the two biggest things on it. You cannot tune or change city here. Put the phone in flex to do that.

### Flat and shut

Flat shows a card that says "Fold me" and, if the radio was on, it keeps playing. Shut shows "Closed" and goes silent. Opening the phone again resumes the radio if it was on.

### Reaching each pose on the simulator

Use the Simulator's hinge controls, or the iOS Simulator tool's `set_posture` and `rotate`.

- Flex: set the hinge to open (flat), then bend it to about 110 degrees. The inner screen stays lit and upright.
- Book: from flex, turn the simulator a quarter turn. The inner screen goes wider than tall.
- Flat: set the hinge to open.
- Shut: set the hinge to closed. The outer screen lights.
- Tent: set the hinge to closed first, then bend it to about 60 degrees. The outer screen stays lit.

The outer screen is only reached through closed, which silences the radio. So moving from flex to tent without a break could not be tried on the simulator.

Leaving the app (for example with the Home button) pauses the radio. Coming back reconnects to the station you were on.

The measurements behind these rules (the shut line at 20 degrees, the flat line at 175, which screen is lit) are in `docs/pose-measurements.md`. The older measurements are in `docs/hinge-measurements.md`.

On the simulator, for about 1.3 seconds after a jump from closed, the app briefly sees the inner screen's size (that figure is from `docs/pose-measurements.md`; in the poses pass below, on the jump to 60 degrees the log had `POSE tent` at 18:32:40.418, `POSE flex` at 18:32:40.485 and `POSE tent` again at 18:32:41.807). A passing `POSE flex` and `POSE tent` can show in the log then. They cause no stop and no reconnect.

### Running silently

Launch with the argument `-HingeRadioMuted YES` and the app plays nothing: stations still connect, and the lamp, text and log lines behave the same. In Xcode, add it under the scheme's Run, Arguments. From the command line:

```
xcrun simctl launch <id> com.example.HingeRadio -HingeRadioMuted YES
```

### The log

Lines are in the `HingeRadio` subsystem. Read them with:

```
xcrun simctl spawn <id> log show --last 3m --style compact --predicate 'subsystem == "HingeRadio"'
```

- `POSE shut|tent|flex|book|flat` when the pose changes.
- `LOCK <call> <position>` or `STATIC <position>` only when the locked station changes.
- `CONNECT`, `PLAYING`, `RETRY`, `FAILED` and `STOP` from the player.

## The stations

There are 55 stations: 10 in Seattle, 15 in New York, 16 in Chicago and 14 in Los Angeles. Frequencies and licence cities come from the FCC's public FM list. The stream addresses come from the Radio Browser directory. The finished list is `App/Resources/Stations.json`.

To rebuild it (needs the internet; the Python tools use only the standard library):

```
python3 tools/build_stations.py fetch               # download the FCC lists and the Radio Browser directory
python3 tools/build_stations.py candidates seattle  # show proposed pairings for one city
python3 tools/build_stations.py build               # check the streams and write Stations.json
```

Each city has a corrections file in `tools/corrections/` (`seattle.json`, `new-york.json`, `chicago.json`, `los-angeles.json`). All keys are optional:

- `pick`: the call signs to use. Their order does not matter: the station list is sorted by frequency.
- `stations`: per call sign, `name` (what the dial shows), `stream` (use this stream address), `exclude` (drop this station), and `note`.
- `note` is free text for the next person, for example why a stream was chosen. The build ignores it.

Any other key (a misspelling, say) prints a warning naming the file, the key and where it was found, and is otherwise ignored; the build carries on.

At the end of `build`, the hosts of the plain-`http://` streams are compared with the hosts the app allows (see "Stations on plain http"). If they differ, it prints which hosts to add to or remove from `project.yml`.

## Tests

```
swift test --package-path Packages/RadioCore          # 74 tests
python3 -m unittest tools/test_build_stations.py      # 19 tests
```

On 2026-11-22, on commit `8987edd`, the Swift suite passed 74 of 74 and the Python suite 19 of 19. One of the Python tests checks that the plain-http hosts in `Stations.json` and the ones `App/Info.plist` allows are the same set.

## Poses pass (2026-11-22, commit 8987edd)

This pass ran on the final build (commit `8987edd`) on the iPhone Duo simulator (iOS 27.1), muted, reading the log after each step. What was seen:

- **Flex, one station in each city.** The drag was scripted, with about 150 ms between touch samples and a pause before lifting. Each city locked and played:
  - Seattle: `LOCK KZOK-FM`, `CONNECT KZOK-FM`, `PLAYING KZOK-FM` (1.1 s after connect).
  - New York: `LOCK WQXR-FM`, `CONNECT`, `PLAYING` (2.3 s).
  - Chicago: `LOCK WFMT` (after `LOCK WKSC-FM` and `LOCK WPNA-FM` on the way past), `CONNECT`, `PLAYING` (2.8 s).
  - Los Angeles: `LOCK KROQ-FM` (after `LOCK KIIS-FM`, `LOCK KOST` and `LOCK KPWR` on the way), `CONNECT`, `PLAYING` (5.8 s).
  - Passing stations logged a `LOCK` each and no `CONNECT` for them. Pressing the city key also gave a `STOP`, then a new `LOCK`, `CONNECT` and `PLAYING` for the station under the needle (WHTZ in New York, WSRB in Chicago).
- **Flex to book and back.** Turning the simulator logged `POSE book`, then turning back `POSE flex`. No `STOP` and no `CONNECT` between them. In a screenshot the book screen showed "KROQ", "Pasadena", "106.7", "MHz", the green lamp and the power button.
- **Flat and back.** Hinge to open logged `POSE flat`, then 110 degrees logged `POSE flex`. No `STOP` and no `CONNECT` between. In a screenshot the flat screen showed "Hinge Radio", "Fold me" and "Sit the phone half open to use the radio."
- **Shut and reopen.** Hinge to closed logged `STOP` and `POSE shut` (with a passing `POSE tent` just before, as the hinge swept down). A screenshot of the outer screen showed "Hinge Radio", "Closed" and "Open the phone to listen again." From closed, the hinge at 60 degrees logged `CONNECT KROQ-FM` and, 2.7 s later, `PLAYING KROQ-FM`. Passing `POSE flex` and `POSE tent` lines showed in between and caused no extra `STOP` or `CONNECT`.
- **Tent.** After that 60 degree jump the log settled on `POSE tent` and a screenshot showed the standby face on the outer screen ("KROQ", "Pasadena", "106.7 MHz", green lamp, power button). Moving from flex to tent without a break could not be checked: the outer screen is only reached through closed, which stops the radio.
- **Leaving the app.** Pressing HOME logged `STOP` at 18:33:09.9, about a second or less after the press (the press itself is not in the log). Launching the app again logged `CONNECT KROQ-FM`, then `PLAYING KROQ-FM` 1.9 s later. A passing `POSE tent`, `POSE flex` also appeared after HOME, with no extra `STOP` or `CONNECT`.
- **No hinge.** Run on the iPhone 17 simulator on iOS 27.2, muted. (A first try on an iPhone 17 on iOS 26.2 could not install the app, which needs iOS 27.1.) Upright, the app showed the full radio: dial on top, then the city keys, readout and power button, then the tape. The log showed no `POSE` line at launch. After switching on and a slow drag on the tape, it logged `STATIC`, `LOCK KZOK-FM`, `CONNECT KZOK-FM` and, 2.1 s later, `PLAYING KZOK-FM`. Turned on its side it logged `POSE book` and showed the standby face ("102.5 KZOK", "Seattle", "102.5 MHz", green lamp, power button). Turned back it logged `POSE flex`. No `STOP` and no `CONNECT` in between. On the sideways face the Dynamic Island covered the left edge of the station name (the "1" of "102.5" and the start of "Seattle"). In the upright screenshot it covered the middle of the title row ("HINGE RADI" and "TTLE" showed). Neither was fixed.

Two things seen that were not expected, and not fixed here:

- When the radio was first switched on, it played the station already under the needle (`CONNECT KING-FM`) without a `LOCK` line for it. `LOCK` is logged only when the locked station changes.
- At launch the log had `POSE flat` at 18:29:54.143, then `POSE flex` at 18:30:04.120, when the hinge was set to 110.

Screenshots of the earlier poses are in `docs/check/` (`21` to `30`). No screenshots were retaken in this pass.

## Final acceptance pass (2026-11-22, commit 646a949)

This section describes the earlier build, where the hinge tuned the dial. That build is gone.

This pass played every station on the final build (commit `646a949`), on the iPhone Duo simulator (iOS 27.1), muted. For each station the hinge was moved onto its mark until the log said `LOCK`, then the log was read for up to 16 seconds for `PLAYING` or `FAILED`.

| City | Stations on the dial | Played | Failed |
|---|---|---|---|
| Seattle | 10 | 10 | 0 |
| New York | 15 | 15 | 0 |
| Chicago | 16 | 16 | 0 |
| Los Angeles | 14 | 14 | 0 |
| Total | 55 | 55 | 0 |

No station logged `FAILED`, and none gave no result, so no station needed a second try after a relaunch. Stations reached `PLAYING` between 0.8 and 8.1 seconds after `CONNECT` (the slowest was WHPK in Chicago, 8.1 seconds; the next slowest were WONC at 6.9 and WRSU-FM at 5.0).

One station needed a `RETRY`: KING-FM (Seattle). On the first connect of the pass, the log showed `ITEM FAILED KING-FM: unknown error`, then `RETRY KING-FM`, a second `CONNECT`, and `PLAYING` 5.4 seconds after the first `CONNECT`. When KING-FM was tuned again later in the pass it reached `PLAYING` 1.2 seconds after `CONNECT` with no `RETRY`. No other station logged `RETRY`.

## What was checked in the earlier acceptance passes (earlier builds, 2026-11-22)

This section describes the earlier build, where the hinge tuned the dial. Its hinge-tuning, debug slider and "closed below 45 degrees" behaviour are gone.

This section describes the two earlier runs, on builds before the final one. Run on the iPhone Duo simulator (iOS 27.1), muted. For every station the hinge was moved onto its mark until the log said `LOCK`, then the log was read for up to 14 seconds for `PLAYING` or `FAILED`. A station that failed was tried a second time after relaunching the app (the app does not retry a station it has marked "No signal" in the same session).

| City | Stations on the dial now | Played in the first pass (original build) | Played in the re-run (after the https and by-name fix) | Total played |
|---|---|---|---|---|
| Seattle | 10 | 8 | 2 (KUPS, KBCS) | 10 |
| New York | 15 | 11 | 4 (WNYC-FM, WBAI, WHTZ, WQXR-FM) | 15 |
| Chicago | 16 | 12 | 4 (WCRX, WMXM, WONC, WDCB) | 16 |
| Los Angeles | 14 | 10 | 4 (KXLU, KPFK, KYSR, KROQ-FM) | 14 |
| Total | 55 | 41 | 14 | 55 |

The first pass found 15 stations blocked because their stream addresses were plain `http://`. They were fixed the same day: eight were moved to the `https://` form of the same address (through the corrections files) and seven are allowed by host name (see "Stations on plain http"). All 15 were then run again from a fresh launch: 14 reached `PLAYING`. The fifteenth, WHCR-FM (New York 90.3), failed on both tries over https with "The operation could not be completed", and was left out of the station list on 2026-11-22; plain http is blocked by the app. The other 41 stations played in the first pass and their addresses did not change. KING-FM failed its first connect in the first pass (`unknown error`) and played on its next two tries.

Played stations reached `PLAYING` between 0.6 and 8.1 seconds after `CONNECT`.

Also seen, in every city: moving the hinge into a gap between stations logs `STATIC` and no `CONNECT`; tapping a city key changes the city name and redraws the needle and marks; closing the phone logs `STOP`; switching the radio off logs `STOP`.

One short unmuted run was also done: it logged `CONNECT`, `PLAYING` and `STOP`, and nobody listened to it.

Two paths that had never been seen working were checked:

- A station that does not answer: with one Seattle station's address pointed at nothing (a temporary change, undone), the log showed `CONNECT` then `FAILED` within about a tenth of a second, the screen said "No signal", the station's mark was struck through, and the next station tuned still reached `PLAYING`.
- A phone with no hinge: on the standard iPhone 17 simulator (iOS 27.2) the app launches, and dragging a finger along the dial moves the needle and logs `LOCK` and `STATIC` lines with changing angles.

Screenshots are in `docs/check/`: `10` to `13` were retaken on the final build (commit `646a949`) and each shows one station playing in a city, with the green lamp and the city of licence under the station name, and no mark struck through: `10-sea-playing.png` shows "102.5 KZOK" with "Seattle" under it, `11-nyc-playing.png` "Lite FM" with "New York" (106.7 MHz), `12-chi-playing.png` "WGCI" with "Chicago" (107.5 MHz), and `13-la-playing.png` "KROQ" with "Pasadena" (106.7 MHz); `14-closed.png` the closed screen, `15-flat.png` the phone flat, `16-no-signal.png` the no-answer case and `17-no-hinge-drag.png` the iPhone 17 drag.

## Stations on plain http

Most streams are `https://`. Seven stations only offer plain `http://`, and iOS blocks that unless the host is allowed by name. The allowed hosts are listed under `NSAppTransportSecurity`, `NSExceptionDomains` in `project.yml`, and nothing else is allowed:

- `nap.casthost.net` (KUPS)
- `stream.pacificaservice.org` (KBCS)
- `stream.wbai.org` (WBAI)
- `wmxm.streamguys1.com` (WMXM)
- `webcast.wonc.org` (WONC)
- `wdcb-ice.streamguys.org` (WDCB)
- `stations.pacifica.org` (KPFK)

If a rebuild of the station list adds a station on a new plain-`http://` host, add that host to the same list in `project.yml`, run `xcodegen generate` and rebuild. Otherwise that station shows "No signal". The builder prints which hosts to add or remove, and a test fails until the two lists match. This is acceptable for a prototype and would need a second look before shipping. All seven played in the second pass.

## What has not been verified

- How the tape feels under a finger. The drags in this pass were scripted and slow. Flicks and taps were not tried in this pass. When the tape was built, a scripted 120 ms flick on the simulator settled on a station and a tap on a station label locked that station (from that task's report). Nobody has tried any of it by hand.
- How it sounds. Every run was muted except a short unmuted launch at the end; nobody listened.
- A real phone. Anything on a real iPhone Duo, including how it chooses its lit screen.
- Moving from flex to tent without a break. The outer screen is only reached through closed on the simulator.
- Tent itself, beyond what is above: it was only reached from closed, and the radio had stopped and restarted on the way.
- Where the fold line is. It is inferred from screen sizes (the inner screen is two outer-size panels), and the simulator draws no fold line.
- The screen staying awake while the radio is on. The code asks for it; nobody watched the screen stay on.
- The iOS 27.2 Duo simulator. The app was built and checked on 27.1.
- Haptics. The simulator has none.

## Known rough edges

- When the player reports an error for a station, the app loads it once more; a second error before any sound, or 12 seconds without sound, marks it "No signal" until the app is relaunched. Before this retry existed, KING-FM was marked "No signal" after a player error 1.6 seconds after connecting, and played on the next launch.
- Seattle has only 10 stations.
- On a phone with no hinge (not the intended device) the Dynamic Island covers part of the title when upright and the left edge of the station name when on its side. The frequency number was cut off in the earlier build; it was not cut off in the final build.
