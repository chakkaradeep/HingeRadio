# Hinge Radio

Hinge Radio is a small SwiftUI app for the iPhone Duo, a folding iPhone. It is an FM radio with a dial. You pick one of four cities (Seattle, New York, Chicago or Los Angeles), or HERE, which finds the stations around the phone (see "HERE" below), and tune across that band's real FM stations, which play over the internet. The lower half of the inner screen is drawn like a 1960s pocket radio: a speaker grille, a band switch for the city and HERE, and two thumbwheels on the right edge, one for volume and power and one for tuning. The hinge does not tune. It only tells the app how the phone is folded, and the app shows a different face for each way of folding. It is a prototype.

## A reference app

Hinge Radio is published as a reference for building on the iPhone Duo's hinge with SwiftUI. It is not on the App Store, and it is not meant to be (see "The streams" below). Places worth reading:

- **The pose from the hinge.** `App/HingeSource.swift` feeds each hinge change in; `Packages/RadioCore/Sources/RadioCore/Pose.swift` turns the angle, the lit screen and the way up into one of five poses, with the measurements behind it in `docs/pose-measurements.md`.
- **A face for each pose.** `App/RootView.swift` picks the face; `App/Views/` holds the flex radio, the standby face used in book, tent and shut, and the flat card. Each keeps clear of the fold and of the outer screen's camera.
- **Rules apart from views.** Everything that decides something (tuning, locking, the feel of each tick, the station file, HERE's search plan) lives in the `RadioCore` package and is tested without a simulator: `swift test --package-path Packages/RadioCore`.
- **Real stations from open data.** The FCC's public licence list gives each station's frequency and reach; `HERE` finds the stations around the phone and their streams from NPR and the Radio Browser directory.
- **The design notes** in `docs/` record each decision, including what changed while it was built.

### The streams

The app plays each station's own public stream; none of them is licensed to this app. The station names belong to their broadcasters, and Hinge Radio is not affiliated with any of them. An app shipped from this code would need written permission from each broadcaster (App Review asks for it under guideline 5.2.3), and NPR's lookup is used without a key. Build your own station list, or ask the stations, before you ship anything.

### Licence

The code is under the Apache License 2.0 (`LICENSE`). The badge's and the app icon's letters are adapted from the font Yellowtail, also Apache 2.0 (`App/Resources/Yellowtail-LICENSE.txt`).

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

The build setting `HERE_CONDITION` (default `HERE`) compiles the HERE band in. Add `HERE_CONDITION=` to the `xcodebuild` line to build without it (see "HERE" below).

## How to use it

The phone has five poses. The app works out which one from the hinge angle, which screen is lit and which way up the screen is. Each pose is written to the log as `POSE <name>` when it changes.

| Pose | How the phone is | What the app shows | Sound |
|---|---|---|---|
| Flex | Partly folded, inner screen, upright | The full radio, with the band switch (HERE and four cities) and the badge's "About the dial" card | Plays |
| Book | Partly folded, inner screen, on its side | Standby face: station name, the line under it, power and tuned lamps, frequency, speaker grille, the Hinge Radio badge, and the volume and tuning wheels at the right edge | Plays |
| Tent | Partly folded, outer screen | The same standby face | Plays |
| Flat | Fully open | A "Fold me" card | Plays |
| Shut | Closed | The same standby face | Plays |

"Plays" means the radio is switched on and the app is in front. Sound follows the power alone: no pose cuts it. Only switching off or leaving the app cuts the sound.

### Flex: the radio

A name that contains the station's own frequency shows without it, because the frequency is already on the face ("94.7 WLS" shows as WLS). Other numbers stay (Hot 97, Z100).

The badge and the app icon are drawn by `tools/build_badge.py`; their letters are adapted from the font Yellowtail (Apache 2.0, see `App/Resources/Yellowtail-LICENSE.txt`).

A long press on the badge opens a sheet, "About the dial", with a Done button. It says where the stations and frequencies (the FCC), the streams (Radio Browser; with HERE also NPR), the town's name (Apple, with HERE only) and the lettering (Yellowtail) come from, and that the station names belong to their broadcasters and the app is not affiliated with them. It is set in the face's colours and its text follows the text-size setting. It sits on the lower half, clear of the fold, and goes away by itself when the phone leaves flex. To VoiceOver the badge still reads "Hinge Radio", with an "About the dial" action.

The top half is the dial: the badge, the city name, the needle, a row of dots for the stations, then the station name with its frequency beside it and two small lamps with their names printed beside them:

- POWER is red while the radio is on and unlit when it is off.
- TUNED is green while a station plays, glows dimly green while one tunes in, and is unlit off a station.

Switched off, the space for the station name is empty: the unlit POWER lamp says it is off. The dial and the frequency dim; the grille stays as it is. Switched on, the line under the name says the same thing as the lamps in words ("Static", "Tuning in", "No signal" or the station's city). VoiceOver reads the lamps as "Power, on" or "Power, off" and "Tuned, <station>", "Tuning in, <station>" or "Not tuned". The top half does not respond to touch, except for the long press on the badge.

The needle follows the tuning wheel on every move, near a station too, and the frequency under it changes with it. Inside a station's zone the station is locked and its name shows while the needle sits a little either side of the mark. When you let go slowly the needle eases onto the mark in about a fifth of a second, quietly (no ticks). A finger resting on the wheel stops a glide under it.

The radio opens where it was left: on the same band, with the needle where it came to rest, and on the station's mark when a station is locked there. It always opens switched off; the volume is not kept. The band and the needle are saved (`HingeRadioBand` and `HingeRadioPosition` in the app's defaults) when the needle comes to rest after a release, a glide or a step, when the band changes and when the app goes to the background, never while it moves and never while HERE's needle sweeps. The first launch, or a saved band this build does not have (HERE in a build without it), opens on Seattle with the needle mid-dial on KING-FM; a saved position that is not a number from 0 to 1 opens that band mid-dial. Opening on HERE is described under "HERE" below.

The lower half is the front of a pocket radio: a speaker grille, a band switch under it, and two ridged wheels at the right edge. Each wheel has its name printed over it and a short printed scale beside it with a dot that shows where it is turned. A wheel turns only once the finger has moved 6 pt; a touch that lifts before that is a tap.

1. Volume (the small wheel, top). Roll it up past the click and the radio comes on; keep rolling for louder; roll it down past the click and it goes off. Below 0.15 of its travel it is off. A tap on it switches the radio on (at the last volume used) or off. One wheel height of rolling covers the whole range.
2. Tuning (the tall wheel, bottom). Roll it up to go up the band, down to go down. Every 100 pt of rolling moves about a tenth of the band (the whole band is 932 pt of rolling), on every face; here that is a quarter of the band per wheel height. Near a station it settles on it, the name and its city of licence appear, and the station plays. Between stations the screen says "Static". A slow release on a station eases the needle onto its mark, and so does a slow release just short of a station where its name already shows (with the radio on, and not a station marked "No signal"); anywhere else it stays where you let go. A quick flick carries on and settles on the nearest station. A tap on the upper half of the wheel goes to the next station up, on the lower half to the next one down, counting from the locked station when there is one. On this wheel a tap must lift within 4 pt of where it began; a small nudge between that and 6 pt does nothing.
3. Band. Tap one of the five positions (HERE, marked with the location arrow, then SEA, NYC, CHI, LA; four without HERE) to slide the switch there. A short printed rule stands between HERE and SEA; a tap on it does nothing. On the iPhone Duo's inner screen each position is 68 pt wide. The dial redraws with that band's stations and the old band goes quiet at once. The needle stays where it was, unless one of the new band's stations is under it: then it eases onto that station's mark.

Each control ticks or clicks like a mechanical one, with a small sound and a matching tap you can feel, whether the radio is on or off:

- The ridges drawn on each wheel are spaced one tick apart, so each tick is a ridge going past.
- The tuning wheel gives a soft tick for each ridge it passes (every 1/160 of the band, about 0.13 MHz) and a firmer click when it settles on a station. A fast roll gives at most about 30 ticks a second, so it sounds like a ratchet.
- The volume wheel clicks where it switches on and off, and gives a very soft tick every 0.05 of its travel while on.
- The band switch clicks when it lands on a new city (one click, even when the new city has a station under the needle).
- Each wheel gives one firmer stop when it reaches the end of its travel.

Running silently (below) silences these sounds too; the taps you feel still happen.

With VoiceOver: "Volume" is adjustable in steps of a tenth (from off, one step up switches on at the click; a step down past the click switches off) and a double-tap switches the radio on or off; "Tuning" is adjustable to the next or previous station and reads the station name and its frequency ("Finding stations" while HERE's needle sweeps); "Band" reads as a picker of the bands in the switch's order, HERE first, as "Here" with its town once that is known; the badge has an "About the dial" action. With Reduce Motion on, a flick or a step jumps to the station instead of gliding.

### Book, tent and shut: standby

The same face on all three. It is made to be read from across a room, with the station name and the frequency as the two biggest things on it. Under the name are the same POWER and TUNED lamps as in flex; switched off, the name and the line under it are empty. The frequency is the locked station's own; between stations it is the one under the needle. It keeps one size while you tune (it is sized for five figures, so it does not jump at 100 MHz).

At the right edge are the same two wheels as in flex, with the same names, printed scales, ticks, clicks and VoiceOver actions: volume above, tuning below. Volume is also power: roll it up past the click or tap it to switch on, roll it down past the click or tap it again to switch off. Tuning works as in flex, including a tap on its upper or lower half to step a station, and a thumb movement tunes the same amount as in flex; on a taller wheel one wheel height just covers more of the band. In book the wheels sit at the right edge of the right panel, with the frequency to their left; the station name, the frequency and the word VOLUME start on one line across the fold, and the tuning wheel is 300 pt tall. The outer screen's camera sits in one corner, and which corner depends on the way up, so there the wheels keep a thumb's width clear of it: they stay about 104 pt in from each end of the long side, where the text keeps 80 pt. You cannot change city here. Put the phone in flex to do that.

Closing the phone keeps the radio playing and shows the standby face on the outer screen, whichever way up it is. If the hinge is nearly shut but the inner screen is still lit, the standby face shows on the half of the inner screen above the fold (or the panel left of it on its side).

### Flat

Flat shows a card that says "Fold me" and, if the radio was on, it keeps playing.

### Reaching each pose on the simulator

Use the Simulator's hinge controls, or the iOS Simulator tool's `set_posture` and `rotate`.

- Flex: set the hinge to open (flat), then bend it to about 110 degrees. The inner screen stays lit and upright.
- Book: from flex, turn the simulator a quarter turn. The inner screen goes wider than tall.
- Flat: set the hinge to open.
- Shut: set the hinge to closed. The outer screen lights.
- Tent: set the hinge to closed first, then bend it to about 60 degrees. The outer screen stays lit.

The outer screen is only reached through closed. Closing no longer silences the radio, so flex to closed to tent now plays throughout (see the pocket radio pass below).

Leaving the app (for example with the Home button) pauses the radio. Coming back reconnects to the station you were on.

The measurements behind these rules (the shut line at 20 degrees, the flat line at 175, which screen is lit) are in `docs/pose-measurements.md`. The older measurements are in `docs/hinge-measurements.md`.

On the simulator, for about 1.3 seconds after a jump from closed, the app briefly sees the inner screen's size (that figure is from `docs/pose-measurements.md`; in the poses pass below, on the jump to 60 degrees the log had `POSE tent` at 18:32:40.418, `POSE flex` at 18:32:40.485 and `POSE tent` again at 18:32:41.807). A passing `POSE flex` and `POSE tent` can show in the log then. They cause no stop and no reconnect.

### Running silently

Launch with the argument `-HingeRadioMuted YES` and the app plays nothing, ticks and clicks included: stations still connect, and the lamps, text, log lines and the taps you feel behave the same. In Xcode, add it under the scheme's Run, Arguments. From the command line:

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
- `FEEL click on|off|band|lock <call>` and `FEEL stop tuning|volume` for each click and stop; `FEEL tick tuning|volume` for each tick, at the info level (add `--info` to see them).
- `HERE ...` lines from HERE's search (`FCC <n> licences`, one line per call sign with the source that gave its stream or `none`, `TOTAL`, `SAVED`, `NAMED`, `CACHED`, `REFRESHED`, `TIME UP`, `CANCELLED`, `PLAY SENT`), and `SCAN` and `SCAN END` for the needle's sweep. The position and the town's name are never logged, but the call signs are, as they are for every band, so someone reading the phone's system log could tell the metro area.
- `WHEELS tuning <height> pt, <fraction> of the band` when the tuning wheel's height changes, at the debug level (add `--debug` to see it).

## The stations

There are 55 stations: 10 in Seattle, 15 in New York, 16 in Chicago and 14 in Los Angeles. Frequencies and licence cities come from the FCC's public FM list. The stream addresses come from the Radio Browser directory. The finished list is `App/Resources/Stations.json`. These are the four bundled cities; HERE's stations are found on the phone (next section).

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

## HERE: the stations around the phone

HERE is the first position on the band switch, marked with the location arrow and set apart from SEA, NYC, CHI and LA by a printed rule. Choosing it finds the FM stations licensed around the phone that also stream, at most 16, and puts them on the dial as a city's stations are. The dial's name becomes the nearest town, printed in the header after the muted location arrow ("➤ SEATTLE", and "➤ HERE" until the town is known; VoiceOver reads "Here, Seattle"); a long name shrinks to fit rather than run into the badge. While it looks, the line under the name says "Finding stations…" and the needle sweeps up the dial, each station's dot appearing as it is confirmed (with Reduce Motion the dots appear without the sweep). When it ends, the needle eases onto a station and it plays. With no stations it says "No stations found here"; with location refused, "Location is off". The other four bands work in each case. It covers the US only, because the list of stations is the FCC's.

How it finds them:

1. The position is rounded to 0.01 degree (about 1 km) before anything is done with it.
2. The FCC's list of licensed FM stations within 100 km of it. Only licensed stations (status `LIC`, service `FM`) count, one per call sign, and only those whose class reach covers the phone (class A 28 km, B1 and C3 39, B and C2 52, C1 72, C0 83, C 92, D 10). They are ranked by distance divided by reach, smallest first, then higher power, then lower frequency. At most 16, one to a frequency, within 88 to 108 MHz.
3. A stream for each, asked of NPR, then Radio Browser, and the first `https` one wins. Radio Browser counts only when the entry's name holds both the call sign and the frequency and its own check says the stream works.
4. Each stream is tried (one byte is enough) before its station goes on the dial. At most 3 addresses are tried for one station from one source. A request takes at most 8 seconds and at most 6 run at once. Every request says `User-Agent: HingeRadio/1.0`.
5. The whole search takes at most 30 seconds. At the limit it ends with the stations found by then, and they are the dial.

Leaving the app or choosing another band ends a search. The stations found so far are dropped; coming back to the app with HERE chosen searches again. The needle is left where it is for that search if you had a hand on the tuning in the one that was cut short. Choosing HERE yourself starts afresh, and choosing it again tries any of its stations marked "No signal" again. Reduce Motion switched on during the sweep stops the needle there; the search goes on.

Left on HERE, the radio opens on HERE with the needle exactly where it was left, on a station or in static. If a dial is kept for the last place it was used (see below) and is under 7 days old, it shows at once. Once the window is up and the app is active, HERE searches as a choice does (the location prompt, if iOS has not asked yet, comes only then), except that the needle is left alone: it neither sweeps nor eases onto a station in that first search. Near the last place the kept dial stays and is refreshed when due; somewhere new, it is searched for and its dots appear without the sweep. With location refused (denied or restricted) no dial shows at all, the last place is forgotten, and HERE says "Location is off". Choosing HERE yourself later gives the needle back as usual. The first time HERE is chosen in a run, the last place is read too, so with no position in time it can still show that place's dial.

### What is sent where

| To | What | For |
|---|---|---|
| The FCC (`transition.fcc.gov`) | The rounded position | The stations licensed around it |
| Apple (MapKit's place lookup) | The rounded position | The town's name |
| NPR (`station.api.npr.org`) | A call sign | The stream address |
| Radio Browser (its `api.radio-browser.info` servers, found with a DNS lookup of `all.api.radio-browser.info`, or `de1.api.radio-browser.info` when that names none in time) | A call sign; and, when a station it listed plays, that station's id, as it asks | The stream address and its play count |
| Each station's own stream server | An ordinary request for its stream, so it sees the phone's address | The sound |

Only the FCC and Apple get the position. Nothing is sent to anyone else, and there is no server of ours. No request carries an account, a device identifier or a cookie.

The play count goes to Radio Browser only while HERE is the band, once each time a station it listed starts playing: not again after a stall, a retry or a volume change, but again if the station is left and chosen again. A failed request is ignored.

### The prompt and the cache

The first time HERE is chosen, iOS asks to use the location while the app is in use, and the app asks for approximate location only. If the answer is no, HERE says "Location is off" and finds its stations when it is allowed again.

Each place's dial is kept on the phone, in the app's cache folder, for 7 days, on a grid of 0.1 degree (about 10 km). A kept dial shows at once. When it is over 24 hours old, or over 10 minutes old with fewer than 8 stations (a poor connection may have cut it short), it is searched for again in the background; the new list is only kept, and shows the next time HERE is chosen, so the station being listened to never moves. A refresh that finds nothing, or fewer than half as many stations, leaves the old dial alone. The last place a dial was shown or looked for is kept in the same folder (`last.json`) as its 0.1 degree cell only, the centre of the square its dial is filed under (for example 47.6, -122.3), so the radio can open on HERE with that dial; it is not kept anywhere else. It is rewritten each time HERE gets a position, deleted as soon as location is found refused (at launch or in a search), and removed with the other files once nothing has written it for 7 days. Each time a dial is kept, files in that folder last written over 7 days ago are removed.

### Building without HERE

The build setting `HERE_CONDITION` is `HERE` by default. Build with it empty to leave HERE, and every lookup, out of the app:

```
xcodebuild -project HingeRadio.xcodeproj -scheme HingeRadio \
  -destination 'platform=iOS Simulator,id=<id>' \
  -derivedDataPath build/DerivedData HERE_CONDITION= build
```

That build has four bands, never asks for the location and never contacts NPR or Apple, and its About card does not name them. It still contains two things it does not use: the addresses of the FCC and NPR lookups, which are in the rules package (`RadioCore`) that both builds link, and the location usage string in `App/Info.plist`. A build made for review should know that.

### What HERE depends on

HERE asks NPR and Radio Browser only. Until 2026-11-25 it asked iHeart first, whose lookup is not documented and was used without permission; it was removed before the code was published. In a dry run against the live sources that day, NPR and Radio Browser together gave a stream for at least 4 stations around Seattle, 3 around Fargo and 5 around Denver, so HERE's dial is usually short, and mostly public radio. NPR's lookup is not documented either, and Radio Browser's entries are the only source that is open. None of the streams is licensed to this app; a shipped version would need permission from each broadcaster and from NPR (see `docs/2026-11-22-local-stations-design.md`).

On the iPhone Duo simulator (muted, location set to Seattle, no kept dial) HERE found 16 stations in 8.0 seconds (the FCC listed 58 licences, 30 in reach), named the town "Seattle" and played KCMS (`docs/check/61-about.png` is the card in flex; `62-here-after-scan.png` is HERE after the scan). Built with `HERE_CONDITION=` it showed four bands, played KING-FM, and its card named the FCC, Radio Browser and Yellowtail only. Book, closed and flat on a bundled city looked as before.

With HERE first and remembered (2026-11-25, same simulator, muted, flex): the switch reads HERE | SEA NYC CHI LA (`docs/check/63-here-first.png`) and a tap on the rule chose nothing. Left on HERE with a kept Seattle dial, a relaunch logged `OPEN here 0.516` and `HERE OPENED 16 stations` 4 ms apart, before the first layout, then `HERE CACHED 16 stations` once active, and no sweep. Left on Chicago on WCHI-FM, a relaunch opened on Chicago, switched off, the needle on 95.5. With location refused, a relaunch on HERE said "Location is off". With both keys deleted it opened on Seattle; the build without HERE, launched after HERE was saved, opened on Seattle with four positions.

After the review fixes (same day): the header on HERE reads a small HERE before the town (`docs/check/64-here-header.png`); "MISSION VIEJO" fitted at full size. Left on HERE in static at 98.9, a relaunch logged `OPEN here 0.541` and `HERE OPENED 16 stations` 8 ms apart, then `HERE CACHED 16 stations`, with no lock, no ease and no sweep; the needle stayed at 98.9. With location refused, a relaunch on HERE logged `HERE OPENED refused` and `HERE locationOff` before the first layout, showed no dots, said "Location is off", and `last.json` was gone.

## Tests

```
swift test --package-path Packages/RadioCore          # 280 tests
python3 -m unittest discover -s tools                 # 19 tests
```

On 2026-11-22, on commit `8987edd`, the Swift suite passed 74 of 74 and the Python suite 19 of 19. After the review fixes the same day, the Swift suite passed 81 of 81 and the Python suite 19 of 19. With the pocket radio face, the Swift suite passed 85 of 85 and the Python suite 19 of 19. With the smooth needle, ticks and lamps, the Swift suite passed 95 of 95 and the Python suite 19 of 19; after the review fixes that followed, 110 of 110 and 19 of 19. With the side wheels on the standby faces, 110 of 110 and 19 of 19 (no new tests: the change is in the app's views, and the gearing constant carries no rule for RadioCore); after the review fixes, with five tests for where a slow release eases to, 115 of 115 and 19 of 19. One of the Python tests checks that the plain-http hosts in `Stations.json` and the ones `App/Info.plist` allows are the same set.

## Side wheels on the standby faces (2026-11-22)

The owner asked for the same side wheels in standby and the other poses. The volume and tuning wheels, their names, their printed scales and all their touch, feel and VoiceOver wiring now live in one view (`App/Views/SideWheels.swift`), used by the flex plate and by the standby face in book, tent and shut. The standby face's OFF/ON switch is gone: the volume wheel is power there too. Flat still shows "Fold me" with no wheels.

The tuning wheel is now geared by the point rather than by its height: 1/932 of the band per point, everywhere. That number came from the flex wheel, measured at 233 pt on the inner screen (from a `WHEELS tuning` log line the app now writes when the wheel's height changes), so a quarter of the band per flex wheel height is kept exactly. The volume wheel still covers its whole travel in one wheel height (93 pt on the inner screen, 92 pt on the outer one). Measured tuning wheel heights: flex 233 pt, book 415 pt, outer screen 249 pt (678x466) and 357 pt (466x678).

Checked on the iPhone Duo simulator (iOS 27.1), muted. Every touch was scripted. What was seen:

- **Flex** (`docs/check/40-pocket-flex.png`, retaken on WCPY in Chicago as before): compared pixel by pixel with the old one, the only differences were inside the tuning wheel's rim (the ridges sit at a slightly different phase). Everything else was the same.
- **Book** (`45-book-wheels.png`): a slow roll up the tuning wheel logged `LOCK WFMT 0.624` then `LOCK WPNA-FM 0.710`, in that order. Rolling the volume wheel down past the click logged `FEEL click off` and `STOP`; rolling it up logged `FEEL click on`, `CONNECT WKSC-FM` and `PLAYING WKSC-FM`. The screenshot shows the name ("103.5 / KISS FM", on two lines) and lamps on the left panel and the frequency and wheels on the right, nothing near the fold, the name and frequency at about the same size. It read 103.3 while the name said "103.5 KISS FM": the roll ended inside that station's tuning-in zone but not on its mark, so nothing was locked and the needle did not ease onto the mark (that is how flex behaves too).
- **Shut** (`47-closed-wheels.png`, 678x466): closing from flex while playing logged `POSE flex`, `POSE tent`, `POSE shut` and no `STOP`. A roll down the tuning wheel logged `LOCK WPNA-FM 0.742`, `CONNECT WPNA-FM` and `PLAYING WPNA-FM`. A tap on the volume wheel logged `FEEL click off` and `STOP`. The camera dot was top left, about 14 pt clear of the station name; the wheels ran from the top margin to the bottom margin, their right edge 81 pt in from the screen edge.
- **Tent** (`46-tent-wheels.png`, 678x466): after switching on in shut and bending to 60 degrees, the log had `POSE tent`, `POSE flex` and `POSE tent` within 1.4 s (the known flash) and no `STOP`. This time the camera dot was bottom right, about 15 pt clear of the tuning wheel. The first roll down ended between stations (`STATIC 0.692`), and 6 s later the player logged `STOP`, which is what it does after a few seconds on static, not the pose. A longer roll logged `LOCK WFMT 0.649`, `CONNECT WFMT` and `PLAYING WFMT`. Three taps on the lower half stepped down through WCHI-FM, WLS-FM and WCPY. A tap on the volume wheel logged `FEEL click off` and `STOP`.
- **The other outer size** (`48-tent-wheels-upright.png`, 466x678): it came up on the third turn on the outer screen. The camera dot was top right; the VOLUME name starts 82 pt from the top, below it. A tap on the tuning wheel's upper half logged `LOCK WFMT 0.621` and a tap on the volume wheel `STOP`.
- **Same gearing**: from WCPY (92.7, needle on the mark), the same scripted 100 pt roll up, held, read 95.3 during the hold in flex and in tent, and logged the same lines in both (`STATIC 0.501`, `LOCK WLS-FM 0.517`, `LOCK WCHI-FM 0.565`). The dial is not even in MHz, so the same roll elsewhere on the band moves the readout by a different number of MHz, the same on every face.

### Review fixes to that pass (2026-11-22)

A review found that the standby readout had been changed to follow the needle, that the book face's two panels no longer lined up, that on the 678x466 outer screen the camera sat about 15 pt beside a wheel end where a rolling thumb would cover it, and that a slow release just short of a station left the needle beside it. Fixed and checked on the iPhone Duo simulator (iOS 27.1), muted:

- **Readout**: the standby face again shows the locked station's own frequency (the flex dial still follows the needle). In book, at rest on WLS-FM, it read 94.7 (`45-book-wheels.png`).
- **Book**: the name's, the frequency's and VOLUME's cap tops now share one line, measured at 100.0, 100.3 and 101.0 pt in `45-book-wheels.png`; the wheels are centred top to bottom (tuning wheel 300 pt, foot at about 568 pt) and the lamps follow the name.
- **Outer screen**: in shut (678x466, camera bottom right) the tuning wheel's rim ended at 573.7 pt and the dot began at 612 pt, 38 pt apart (`47-closed-wheels.png`). In tent the camera came up top left, beside the name, 14 pt clear as before (`46-tent-wheels.png`); a roll there logged `LOCK WCHI-FM 0.567`, `CONNECT WCHI-FM`, `PLAYING WCHI-FM` and no `STOP`. Upright (466x678, `48-tent-wheels-upright.png`) the dot ended at 66 pt and the volume wheel began at 125 pt, 59 pt below it; the tuning wheel ended 104 pt from the bottom. A tap on the volume wheel there logged `FEEL click off`, `STOP`.
- **Slow release short of a station**: in flex, from WCPY's mark a scripted 37 pt roll up, held 4 s, then lifted. During the hold the log had `STATIC 0.495` and `CONNECT WLS-FM` and no `LOCK`; a capture then showed "94.7 WLS", "Chicago", 93.9 and the needle left of the mark. After the lift: `FEEL click lock WLS-FM` and `LOCK WLS-FM 0.511`, and the needle rested on the mark at 94.7.
- **Flex**: a new capture of the same WCPY face was pixel for pixel the same as `40-pocket-flex.png` from the first pass, so that file was kept.

## Wheel touch fix (2026-11-22)

A review found that one touch on a wheel could both turn it and count as a tap: near the click, a tap with a few points of jitter switched the radio on and straight back off. Now a wheel turns only after the touch passes 6 pt, measured from that point, and a touch that never got that far is the only kind that can be a tap. Checked on the iPhone Duo simulator (iOS 27.1), muted, in flex:

- With the volume wheel rolled to just under the click (still "Off", no log line), a touch that moved 3.5 pt up and lifted logged `CONNECT KING-FM` (19:37:10.314) and `PLAYING KING-FM` (19:37:11.580), and no `STOP` after it.
- A plain tap then logged `STOP` (19:37:26.282).
- A roll up logged `CONNECT KING-FM` (19:37:26.768) and `PLAYING` (19:37:28.021); a roll down past the click logged `STOP` (19:37:38.026). The roll up did not switch the radio off again on release.
- On the tuning wheel a 4 pt nudge logged nothing (no `LOCK`, no `STATIC`); a tap on its upper half logged `STATIC 0.558` and `LOCK KZOK-FM 0.699` (19:37:55), one station up.
- The wheel names now sit over their wheels, the black edge stripe is gone, and the space across the fold is smaller (about 66 pt from the TUNED row to the grille, none of it within 14 pt of the fold). `docs/check/40-pocket-flex.png` and `21-flex.png` were retaken.

## Smooth needle, ticks and lamps (2026-11-22)

After trying the face on a real phone the owner asked for smooth tuning on every move, ticks and clicks with haptics, and red and green lamps in place of the off words. Checked on the iPhone Duo simulator (iOS 27.1), muted, in flex unless a step says otherwise. Every touch was scripted. What was seen:

- **Off at launch** (`docs/check/43-lamps-off.png`): no words where the station name goes, both lamps pale and unlit with a thin ring, the dial and frequency dimmed. No `FEEL` line at launch.
- **Volume wheel tapped**: `FEEL click on` (19:50:07.866), `CONNECT KING-FM`, `PLAYING KING-FM` (19:50:09.291). The screenshot (`44-lamps-playing.png`) shows POWER red and TUNED green, each a small lit dome with a pinpoint highlight and a faint glow, labels level with the lamps.
- **Slow roll through a station**: up out of KING-FM's zone and back into it, then held. Log: `STATIC 0.540`, `FEEL click lock KING-FM` and `LOCK KING-FM 0.532` (19:51:28.597), ticks between. A capture taken during the hold showed the needle to the right of the KING-FM mark, the readout at 98.5 and "Classical KING FM" showing. After the lift (19:51:34.99) two ticks were logged as the needle eased back, and a screenshot showed the needle on the mark and 98.1.
- **Slow roll down through three stations** (about 220 pt over 4.4 s): `LOCK KIRO-FM 0.475`, `LOCK KUOW-FM 0.375`, `LOCK KJR-FM 0.319`, in that order, each with one `FEEL click lock`, then `PLAYING KJR-FM`. Two captures taken during the drag 1 s apart showed the needle at 96.0 ("Static") and then at 94.9 on KUOW ("Tuning in", TUNED dimly green). No crash.
- **Volume wheel rolled up and down**: soft `FEEL tick volume` lines on the way up and down, `FEEL click off` and `STOP` (19:52:55.774), then `FEEL stop volume` at the bottom. Rolled up again: `FEEL click on`, `CONNECT KJR-FM`, `PLAYING KJR-FM` (19:52:58.227).
- **Band switch to CHI**: `STOP`, `FEEL click band`, `LOCK WMBI-FM`, `CONNECT`, `PLAYING`. One click only, no lock click on top of it. `40-pocket-flex.png` and `21-flex.png` were retaken here.
- **Closed while playing** (`41-pocket-closed.png`): `POSE tent`, `POSE shut`, no `STOP`. The standby face showed "WMBI", "Chicago", both lamps lit, "90.1", the switch at ON. A tap on the switch: `FEEL click off`, `STOP`; the face then showed no name and no line, both lamps unlit.
- **Book** (`42-pocket-book.png`, `22-book.png`): both lamps lit under "Chicago" on the left panel, clear of the fold.
- **Flick** with the radio off, after a fresh launch: ticks about 33 to 58 ms apart, `STATIC 0.554`, `FEEL click lock KZOK-FM`, `LOCK KZOK-FM 0.700`, then one more tick 100 ms later; no `CONNECT` (sound follows power alone). A flick in an earlier build of this pass passed five Chicago stations with one lock click each.

### Review fixes to that pass (2026-11-22)

A review found the needle could rest beside a locked station (at launch and after a band change), that a tap or VoiceOver step from there landed on the same station, that the audio session stayed in playback after switching off, and that the click and tick rules had no tests. The rules (which feel a change gives, where a step goes) now live in RadioCore with tests. Checked again on the iPhone Duo simulator (iOS 27.1), muted, in flex:

- **Launch**: `SESSION ambient` and no feel line. Switched on: `SESSION playback` (20:06:15.290), `FEEL click on` 8 ms later, `CONNECT KING-FM`, `PLAYING KING-FM`. The needle sat on KING-FM's mark and the readout said 98.1 (`44-lamps-playing.png` retaken).
- **Off and on again**: `FEEL click off`, `STOP` (20:06:32.680), `SESSION ambient` 167 ms later; on: `SESSION playback`, `FEEL click on`, `CONNECT`, `PLAYING`. No error line from the app. The system logged a notice that a synchronous session call on the main thread can risk a hang.
- **One tap on the tuning wheel's upper half** from there: `STATIC 0.564`, `FEEL click lock KZOK-FM`, `LOCK KZOK-FM 0.698`: the next station, not KING-FM again.
- **Band change with a station under the needle**: on Seattle's KIRO-FM, a tap on CHI logged `FEEL click band` and `LOCK WCPY 0.458`, and no tick; the screenshot then showed the needle on WCPY's mark and 92.7 (`40-pocket-flex.png`, `21-flex.png` retaken). To NYC from KZOK-FM nothing locked (WHTZ is just outside its zone), and the needle stayed put.
- **Slow roll into WLS-FM and lift**: `FEEL click lock WLS-FM`, `LOCK WLS-FM 0.507`; ticks only while the finger moved, none after the lift; the needle then rested on the mark at 94.7. Ticks came about one per drawn ridge.
- **Volume**: up to the top: soft ticks then `FEEL stop volume` (20:09:09.529); down past the click: `FEEL click off`, `STOP`, `FEEL stop volume`, `SESSION ambient`.
- **Closed while playing** (`41-pocket-closed.png`): `POSE tent`, `POSE shut`, no `STOP`; both lamps lit, "94.7 WLS", and the readout 94.7.

## Pocket radio pass (2026-11-22)

This pass ran on the build committed with this section, on the iPhone Duo simulator (iOS 27.1), muted, in flex (open, then 110 degrees, upright) unless a step says otherwise. Every touch was a scripted tap or drag. What was seen in the log and on screen:

- **Volume wheel rolled up** from off: `CONNECT KING-FM` (19:23:28.240), then `ITEM FAILED`, `RETRY`, `CONNECT KING-FM` and `PLAYING KING-FM` (19:23:34.214). The volume dot turned orange above the click. **Rolled down past the click**: `STOP` (19:23:41.021).
- **Volume wheel tapped**: on (`CONNECT KING-FM` 19:23:41.741, `PLAYING` 19:23:45.907), tapped again: `STOP` (19:23:52.265). A third tap switched it on again for the next steps.
- **Tuning wheel, Seattle**: a slow roll up logged `STATIC 0.541` then `LOCK KZOK-FM 0.696`; a slow roll down `STATIC 0.683` then `LOCK KING-FM 0.529`; a fast upward roll released mid-flick logged `STATIC 0.545`, `LOCK KZOK-FM 0.696` and `PLAYING KZOK-FM`, so it settled on a station.
- **Tuning wheel, Chicago** (the most crowded dial): slow roll down `LOCK WFMT 0.652`, `LOCK WCHI-FM 0.590`, `LOCK WLS-FM 0.529` (falling); slow roll up `LOCK WLS-FM 0.513`, `LOCK WCHI-FM 0.575`, `LOCK WFMT 0.621` (rising), released on `STATIC 0.668`. A tap on the lower half of the wheel then logged `LOCK WFMT 0.656` and `PLAYING WFMT`.
- **Band switch**: a tap on NYC logged `STOP`, `STATIC 0.714`, `CONNECT WHTZ` and `PLAYING WHTZ`, and the header read NEW YORK with the knob under NYC. Taps on LA, SEA and CHI in quick turn logged `STOP`, then `LOCK KIIS-FM`, `LOCK KZOK-FM` and `LOCK WPNA-FM` within 0.4 s, then `PLAYING WPNA-FM`; the header read CHICAGO with CHI in ink. The LA and SEA faces were not screenshotted.
- **Closed while playing** (WFMT): the log showed `POSE shut` (19:25:31.780) and no `STOP` or `CONNECT`. The outer screen (678x466) showed the standby face: "WFMT", "Chicago", "98.7", "MHz", the lit lamp and the switch at ON. Bent to 60 degrees: `POSE flex` then `POSE tent` 1.3 s later (the known flicker), still no `STOP` or `CONNECT`. Back to closed and a tap on the switch: `STOP` (19:26:17.571), and the face read "Off", "Switch on to listen". Turned a quarter turn the outer screen went 466x678 and showed the same face upright, clear of the camera.
- **Book**: on its side the standby face sat either side of the fold; a tap on its switch logged `CONNECT WFMT` and `PLAYING WFMT`. From there through flex, tent, shut, tent, flex and flat (19:27:09 to 19:27:21) there was no `STOP` and no `CONNECT`.
- **Nearly shut on the inner screen**: a jump to 15 degrees lit the outer screen, so the inner-screen standby layout was not seen.
- Screenshots: `docs/check/40-pocket-flex.png` (Chicago, WFMT playing), `41-pocket-closed.png`, `42-pocket-book.png`; `21-flex.png`, `22-book.png`, `24-shut.png` and `25-tent.png` were replaced with this build's faces. In each, nothing sat within 14 pt of the fold and no label was clipped.

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

- How the wheels feel under a thumb. Every roll in the pocket radio pass was scripted on the simulator. Nobody has rolled them by hand.
- The wheels on the standby face by hand. On the outer screen they end about 104 pt in from the right edge in 678x466 and 29 pt in 466x678 (where they stay 104 pt from the top and bottom); in book about 43 pt. Whether a thumb finds them easily in a tent, and whether a hand holding the phone in book rolls them by mistake, is not known.
- Whether the right edge fights the system's edge gestures on a real phone. The wheels end about 43 pt in from the glass edge; on the simulator no roll was taken by the system, but the simulator's touches are synthetic.
- How it sounds. Every run was muted except a short unmuted launch at the end; nobody listened.
- A real phone. Anything on a real iPhone Duo, including how it chooses its lit screen.
- HERE on a phone with a real position. On the simulator it was tried in Seattle, Fargo, Chicago and London (which finds nothing).
- HERE with location restricted or switched off for the whole phone, and with no network at all. The 30 second limit was tried on the simulator with lookups that never answered.
- What VoiceOver reads for HERE: "Here, <town>" in the band picker, and "Finding stations" for Tuning during the sweep.
- The play count sent to Radio Browser. None of Seattle's 16 stations came from Radio Browser, so no count was sent; the rule for when to count is tested in `PlayCountTests.swift`, and the call from the app to `reportPlay` has not been seen working.
- The About card with VoiceOver, and with the largest text sizes.
- The standby face on the inner screen when nearly shut. On the simulator a jump to 15 degrees lit the outer screen, so that layout was never seen.
- Where the fold line is. It is inferred from screen sizes (the inner screen is two outer-size panels), and the simulator draws no fold line.
- The screen staying awake while the radio is on. The code asks for it; nobody watched the screen stay on.
- The iOS 27.2 Duo simulator. The app was built and checked on 27.1.
- Haptics and the tick and click sounds. The simulator has no haptics and every run here was muted, so nobody has felt the taps or heard the ticks and clicks. Their strength and timing are a first guess.
- The 120 frames a second drawing on a ProMotion screen. The app asks for it; the simulator does not show it.
- The audio session while off. With the radio off the app holds an ambient session (so ticks can sound without stopping other apps' audio, and the silent switch silences them); it switches to playback when the radio comes on, and back, letting other apps resume, when it goes off. This was not checked with another app playing.
- Interruptions (a call, an alarm, Siri) and a media services reset. The app brings the session and the tick engine back when the system recommends resuming, and rebuilds them after a reset; neither has been triggered.
- VoiceOver and Switch Control. The two wheels are adjustable on every face that has them, the volume wheel switches on and off with a double-tap, and the band switch reads as a picker. All of it was built but not tried.
- Reduce Motion. The jump instead of the glide was built but not tried.
- Shutting the phone while the app is in the background, beyond one simulator run. In that run (flex, radio on and playing KING-FM, HOME, `closed`, three seconds, app opened again on the outer screen) the log showed `POSE tent`, `POSE flex`, `POSE shut` within 1.5 seconds of closing, while the app was still in the background, and nothing on return: no new `POSE` line and no `CONNECT`. The outer screen showed the "Closed" card (that card has since been replaced by the standby face). Whether a real phone delivers the hinge change to a background app the same way is not known.

## Known rough edges

- When the player reports an error for a station, the app loads it once more; a second error before any sound, or 12 seconds without sound, marks it "No signal" until the app is relaunched. Before this retry existed, KING-FM was marked "No signal" after a player error 1.6 seconds after connecting, and played on the next launch.
- Seattle has only 10 stations.
- On a phone with no hinge (not the intended device) the Dynamic Island covers part of the title when upright and the left edge of the station name when on its side. The frequency number was cut off in the earlier build; it was not cut off in the final build.
