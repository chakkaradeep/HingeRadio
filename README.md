# Hinge Radio

Hinge Radio is a small SwiftUI app for the iPhone Duo, a folding iPhone. The phone stands half open on a table, and bending the hinge turns a real FM dial: the further back you lean the screen, the higher the frequency. Pick Seattle, New York, Chicago or Los Angeles and the dial lands on that city's real FM stations, which play over the internet. It is a prototype that runs in the iPhone Duo simulator only; it has not been put on a real phone.

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

## How to use it on the simulator

1. Open the phone flat first (Simulator menu, Device, or the hinge controls), then bend it back to an angle between 70 and 150 degrees. The inner screen lights up and the dial follows the hinge. 70 is the bottom of the dial (87.5 MHz) and 150 is the top (108.5 MHz).
2. Press the round power button at the bottom right to switch the radio on. The lamp at the top right goes green when a station is playing.
3. Bend the hinge to move the needle. Near a station the dial locks onto it and the name and its city of licence appear. Between stations the screen says "Static".
4. The four keys (SEA, NYC, CHI, LA) switch city. The dial redraws with that city's stations and the old city goes quiet at once.
5. Closing the phone silences the radio and shows a "Closed" screen on the outer display. Opening it again shows the dial again with the power button still on. (Reopening was checked by opening the phone all the way flat.) If the hinge goes below 45 degrees while the inner screen is still lit, the "Closed" screen sits above the fold.
6. Leaving the app (for example with the Home button) pauses the radio; coming back reconnects to the station under the needle.

One thing to know about the simulator: if you open the phone slowly from closed, the outer screen stays lit until the hinge is at about 170 degrees. To get the inner screen at an angle between 70 and 150, set the hinge to flat first and then bend back. The measurements are in `docs/hinge-measurements.md`.

### The debug slider

Long-press the "HINGE RADIO" title. A slider appears and replaces the hinge, including closing: while it is showing, the real hinge is ignored. Long-press the title again to go back to the hinge. It only exists in simulator builds.

### Running silently

Launch with the argument `-HingeRadioMuted YES` and the app plays nothing: stations still connect, and the lamp, text and log lines behave the same. In Xcode, add it under the scheme's Run, Arguments. From the command line:

```
xcrun simctl launch <id> com.example.HingeRadio -HingeRadioMuted YES
```

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
swift test --package-path Packages/RadioCore          # 56 tests
python3 -m unittest discover -s tools -p 'test_*.py'  # 19 tests
```

On 2026-11-22, after the review fixes, the Swift suite passed 56 of 56 and the Python suite 19 of 19. One of the Python tests checks that the plain-http hosts in `Stations.json` and the ones `App/Info.plist` allows are the same set.

## What was checked in the acceptance pass (2026-11-22)

Run on the iPhone Duo simulator (iOS 27.1), muted. For every station the hinge was moved onto its mark until the log said `LOCK`, then the log was read for up to 14 seconds for `PLAYING` or `FAILED`. A station that failed was tried a second time after relaunching the app (the app does not retry a station it has marked "No signal" in the same session).

| City | Stations on the dial now | Played in the first pass (original build) | Played in the re-run (after the https and by-name fix) | Total played |
|---|---|---|---|---|
| Seattle | 10 | 8 | 2 (KUPS, KBCS) | 10 |
| New York | 15 | 11 | 4 (WNYC-FM, WBAI, WHTZ, WQXR-FM) | 15 |
| Chicago | 16 | 12 | 4 (WCRX, WMXM, WONC, WDCB) | 16 |
| Los Angeles | 14 | 10 | 4 (KXLU, KPFK, KYSR, KROQ-FM) | 14 |
| Total | 55 | 41 | 14 | 55 |

After the last rebuild (the builder fix and the removal of WHCR-FM), which changed no stream address, only WHTZ was played again, and New York's marks were listed. The other stations were played on the earlier builds, not on the final one.

The first pass found 15 stations blocked because their stream addresses were plain `http://`. They were fixed the same day: eight were moved to the `https://` form of the same address (through the corrections files) and seven are allowed by host name (see "Stations on plain http"). All 15 were then run again from a fresh launch: 14 reached `PLAYING`. The fifteenth, WHCR-FM (New York 90.3), failed on both tries over https with "The operation could not be completed", and was left out of the station list on 2026-11-22; plain http is blocked by the app. The other 41 stations played in the first pass and their addresses did not change. KING-FM failed its first connect in the first pass (`unknown error`) and played on its next two tries.

Played stations reached `PLAYING` between 0.6 and 8.1 seconds after `CONNECT`.

Also seen, in every city: moving the hinge into a gap between stations logs `STATIC` and no `CONNECT`; tapping a city key changes the city name and redraws the needle and marks; closing the phone logs `STOP`; switching the radio off logs `STOP`.

One short unmuted run was also done: it logged `CONNECT`, `PLAYING` and `STOP`, and nobody listened to it.

Two paths that had never been seen working were checked:

- A station that does not answer: with one Seattle station's address pointed at nothing (a temporary change, undone), the log showed `CONNECT` then `FAILED` within about a tenth of a second, the screen said "No signal", the station's mark was struck through, and the next station tuned still reached `PLAYING`.
- A phone with no hinge: on the standard iPhone 17 simulator (iOS 27.2) the app launches, and dragging a finger along the dial moves the needle and logs `LOCK` and `STATIC` lines with changing angles.

Screenshots are in `docs/check/`: `10` to `13` were taken in the first pass and each shows one station playing in a city, with the green lamp, but they also show several marks struck through from the plain-http failures of that pass, and `11-nyc-playing.png` still shows the since-removed WHCR-FM mark; `14-closed.png` the closed screen, `15-flat.png` the phone flat, `16-no-signal.png` the no-answer case and `17-no-hinge-drag.png` the iPhone 17 drag.

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

- How it sounds. The simulator's sound was not listened to; only that streams report as playing.
- How the hinge feels, and the haptics. There was no phone, and the simulator has no haptics.
- Where the fold line is. It is inferred from screen sizes (the inner screen is two outer-size panels), and the simulator draws no fold line.
- The screen staying awake while the radio is on.
- The iOS 27.2 Duo simulator. The app was built and checked on 27.1; only the iPhone 17 simulator was run on 27.2.
- Anything on a real iPhone Duo.

## Known rough edges

- The needle glides for about half a second while the name changes at once. (This comes from reading the code during review, not from watching the screen.)
- When the player reports an error for a station, the app loads it once more; a second error before any sound, or 12 seconds without sound, marks it "No signal" until the app is relaunched. Before this retry existed, KING-FM was marked "No signal" after a player error 1.6 seconds after connecting, and played on the next launch.
- Seattle has only 10 stations.
- On the iPhone 17 simulator (not the intended device) the layout is rough: the Dynamic Island covers part of the title and the frequency number is cut off.
