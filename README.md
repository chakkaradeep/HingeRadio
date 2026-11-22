# Hinge Radio

Hinge Radio is a small SwiftUI app for the iPhone Duo, a folding iPhone. The phone stands half open on a table, and bending the hinge turns a real FM dial: the further back you lean the screen, the higher the frequency. Pick Seattle, New York, Chicago or Los Angeles and the dial lands on that city's real FM stations, which play over the internet. It is a prototype that runs in the iPhone Duo simulator only; it has not been put on a real phone.

## How to run it

You need Xcode 27.2 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). The Xcode project file is generated, not stored.

```
xcodegen generate
xcodebuild -project HingeRadio.xcodeproj -scheme HingeRadio \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -derivedDataPath build/DerivedData build
```

To launch it, either open `HingeRadio.xcodeproj` in Xcode, choose the "iPhone Duo" simulator and press Run, or from the command line:

```
xcrun simctl boot "iPhone Duo"          # skip if it is already running
xcrun simctl install "iPhone Duo" build/DerivedData/Build/Products/Debug-iphonesimulator/HingeRadio.app
xcrun simctl launch "iPhone Duo" com.example.HingeRadio
```

## How to use it on the simulator

1. Open the phone flat first (Simulator menu, Device, or the hinge controls), then bend it back to an angle between 70 and 150 degrees. The inner screen lights up and the dial follows the hinge. 70 is the bottom of the dial (88 MHz) and 150 is the top (108 MHz).
2. Press the round power button at the bottom right to switch the radio on. The lamp at the top right goes green when a station is playing.
3. Bend the hinge to move the needle. Near a station the dial locks onto it and the name and its city of licence appear. Between stations the screen says "Static".
4. The four keys (SEA, NYC, CHI, LA) switch city. The dial redraws with that city's stations and the old city goes quiet at once.
5. Closing the phone silences the radio and shows a "Closed" screen on the outer display. Opening it again shows the dial again with the power button still on (checked at flat).

One thing to know about the simulator: if you open the phone slowly from closed, the outer screen stays lit until the hinge is at about 170 degrees. To get the inner screen at an angle between 70 and 150, set the hinge to flat first and then bend back. The measurements are in `docs/hinge-measurements.md`.

### The debug slider

Long-press the "HINGE RADIO" title. A slider appears and replaces the hinge, including closing: while it is showing, the real hinge is ignored. Long-press the title again to go back to the hinge. It only exists in simulator builds.

### Running silently

Launch with the argument `-HingeRadioMuted YES` and the app plays nothing: stations still connect, and the lamp, text and log lines behave the same. In Xcode, add it under the scheme's Run, Arguments. From the command line:

```
xcrun simctl launch "iPhone Duo" com.example.HingeRadio -HingeRadioMuted YES
```

## The stations

There are 56 stations: 10 in Seattle, 16 in New York, 16 in Chicago and 14 in Los Angeles. Frequencies and licence cities come from the FCC's public FM list. The stream addresses come from the Radio Browser directory. The finished list is `App/Resources/Stations.json`.

To rebuild it (needs the internet; the Python tools use only the standard library):

```
python3 tools/build_stations.py fetch               # download the FCC lists and the Radio Browser directory
python3 tools/build_stations.py candidates seattle  # show proposed pairings for one city
python3 tools/build_stations.py build               # check the streams and write Stations.json
```

Each city has a corrections file in `tools/corrections/` (`seattle.json`, `new-york.json`, `chicago.json`, `los-angeles.json`). All keys are optional:

- `pick`: the call signs to use, in the order wanted.
- `stations`: per call sign, `name` (what the dial shows), `stream` (use this stream address), `exclude` (drop this station), and `note`.
- `note` is free text for the next person, for example why a stream was chosen. The build ignores it.

## Tests

```
swift test --package-path Packages/RadioCore          # 41 tests
python3 -m unittest discover -s tools -p 'test_*.py'  # 11 tests
```

On 2026-11-22 both passed, before and after the https fix: 41 of 41 and 11 of 11.

## What was checked in the acceptance pass (2026-11-22)

Run on the iPhone Duo simulator (iOS 27.1), muted. For every station the hinge was moved onto its mark until the log said `LOCK`, then the log was read for up to 14 seconds for `PLAYING` or `FAILED`. A station that failed was tried a second time after relaunching the app (the app does not retry a station it has marked "No signal" in the same session).

| City | Stations | Played | Failed | Failed stations |
|---|---|---|---|---|
| Seattle | 10 | 10 | 0 | |
| New York | 16 | 15 | 1 | WHCR-FM |
| Chicago | 16 | 16 | 0 | |
| Los Angeles | 14 | 14 | 0 | |
| Total | 56 | 55 | 1 | |

The first pass found 15 stations blocked because their stream addresses were plain `http://`. They were fixed the same day: eight were moved to the `https://` form of the same address (through the corrections files) and seven are allowed by host name (see "Stations on plain http"). All 15 were then run again from a fresh launch: 14 reached `PLAYING` and WHCR-FM failed on both tries over https, with the message "The operation could not be completed". The other 41 stations played in the first pass and their addresses did not change. KING-FM failed its first connect in the first pass (`unknown error`) and played on its next two tries.

Played stations reached `PLAYING` between 0.6 and 8.1 seconds after `CONNECT`.

Also seen, in every city: moving the hinge into a gap between stations logs `STATIC` and no `CONNECT`; tapping a city key changes the city name and redraws the needle and marks; closing the phone logs `STOP`; switching the radio off logs `STOP`.

Two paths that had never been seen working were checked:

- A station that does not answer: with one Seattle station's address pointed at nothing (a temporary change, undone), the log showed `CONNECT` then `FAILED` within about a tenth of a second, the screen said "No signal", the station's mark was struck through, and the next station tuned still reached `PLAYING`.
- A phone with no hinge: on the standard iPhone 17 simulator (iOS 27.2) the app launches, and dragging a finger along the dial moves the needle and logs `LOCK` and `STATIC` lines with changing angles.

Screenshots are in `docs/check/`: `10` to `13` show one station playing in each city, `14-closed.png` the closed screen, `15-flat.png` the phone flat, `16-no-signal.png` the no-answer case and `17-no-hinge-drag.png` the iPhone 17 drag.

## Stations on plain http

Most streams are `https://`. Seven stations only offer plain `http://`, and iOS blocks that unless the host is allowed by name. The allowed hosts are listed under `NSAppTransportSecurity`, `NSExceptionDomains` in `project.yml`, and nothing else is allowed:

- `nap.casthost.net` (KUPS)
- `stream.pacificaservice.org` (KBCS)
- `stream.wbai.org` (WBAI)
- `wmxm.streamguys1.com` (WMXM)
- `webcast.wonc.org` (WONC)
- `wdcb-ice.streamguys.org` (WDCB)
- `stations.pacifica.org` (KPFK)

If a rebuild of the station list adds a station on a new plain-`http://` host, add that host to the same list in `project.yml`, run `xcodegen generate` and rebuild. Otherwise that station shows "No signal". This is acceptable for a prototype and would need a second look before shipping. All seven played in the second pass.

## Known problems

- WHCR-FM (New York, 90.3) does not play: it failed on both tries over https with "The operation could not be completed". Its address is `https://n05.radiojar.com/aafrqsmpyxquv`.

## What has not been verified

- How it sounds. The simulator's sound was not listened to; only that streams report as playing.
- How the hinge feels, and the haptics. There was no phone, and the simulator has no haptics.
- Where the fold line is. It is inferred from screen sizes (the inner screen is two outer-size panels), and the simulator draws no fold line.
- The screen staying awake while the radio is on.
- The iOS 27.2 Duo simulator. The app was built and checked on 27.1; only the iPhone 17 simulator was run on 27.2.
- Anything on a real iPhone Duo.

## Known rough edges

- The needle glides for about half a second while the name changes at once.
- For about a quarter of a second after landing on a new station, the screen can show it as playing before it is.
- A station that has not produced sound within 12 seconds is marked "No signal" until the app is relaunched. This was seen once with a station (KING-FM) that played on the next launch.
- Seattle has only 10 stations.
- On the iPhone 17 simulator (not the intended device) the layout is rough: the Dynamic Island covers part of the title and the frequency number is cut off.
