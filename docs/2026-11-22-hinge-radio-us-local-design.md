# Hinge Radio, US local: native prototype design

Date: 2026-11-22. Status: approved by the owner on 2026-11-22.

Lines marked **(my call)** are choices Claude made that the owner has not confirmed. Everything else was said or picked by the owner.

## What it is

A tabletop radio for iPhone Duo. The phone stands half-open on a table. Bending the hinge sweeps a needle across the real FM dial of a US city, local stations come in at their true frequencies, and there is static in between.

It follows a web mock, `reference/hinge-radio.html`, where a slider stood in for the hinge and the frequencies were invented.

## Why

The owner wants to move from the web mock to prototyping on their own Mac, on the simulator only. They have not said what the prototype is for. **(my call)** I am treating it as a way to find out whether a real local dial, driven by a real hinge reading, works end to end: the stations, the sound and the layout. How the hinge feels in the hand is out of reach without a phone, and this build does not try to settle it.

## Still open

- **Which folder the project lives in.** The first build step needs it.

## Goals

1. Runs on the iPhone Duo simulator (iOS 27.2) from Xcode 27.2 on the owner's Mac.
2. The hinge tunes the dial. The needle snaps onto a station when the hinge gets near it and the station plays; between stations there is static.
3. Four cities to start: Seattle, New York, Chicago, Los Angeles. **(my call)**
4. Stations sit at their real FM frequencies, taken from the FCC's public list.
5. Only stations that actually play are on the dial. **(my call)**
6. The dial fills the top half of the open screen and the controls fill the bottom half, as in the mock.
7. It starts switched off. Closing the phone silences it; opening it again resumes if it was on.

## Non-goals

- Running on a real phone: signing, measuring the hinge on a device, tuning haptics. The owner chose simulator only.
- Fine-tuning how stations lock. The numbers only need to be workable in the simulator.
- Anything needed to ship: App Store review, stream licensing, privacy text.
- Finding the listener's location. The city is picked with a key.
- Small towns and full national coverage.
- The AM band, and stations that exist only online.
- Favourites, search, accounts, history.
- Playing in the background or from the lock screen.
- Refreshing station lists while the app runs.

## What would make it a failure even if it runs

- A dial that is too fiddly to hold on a station.
- Sweeping the dial and mostly landing on stations that do not answer.
- Invented frequencies or made-up stations.
- Anything important drawn across the fold.

## What we know (checked on this Mac, 2026-11-22)

- **The hinge is readable.** SwiftUI has `onHingeChange`, which delivers a `DeviceHinge` with an `angle` and a `status` of closed, partly open or fully open. UIKit has the matching `UIHingeInteraction`. Both need iOS 27.1.
- **The angle is coarse by policy.** Apple's header says the rate and precision of angle updates can change and must not be relied on.
- **The simulator hinge can be set** to closed, open, or any angle from 1° to 179°. Whether an app receives every angle smoothly has not been tested.
- **Real frequencies exist.** The FCC FM Query returns each licensed station's call sign, frequency, city and coordinates as pipe-separated text, for example `https://transition.fcc.gov/fcc-bin/fmq?state=WA&serv=FM&list=4&size=9`.
- **Streams exist for part of each dial.** Radio Browser lists 7,083 working US stations. A rough call-sign match found streams for 13 of Seattle's 33 full-power FM stations within 60 km, 28 of New York's 71, 26 of Chicago's 66 and 20 of Los Angeles's 43.
- **The match is crude.** KJR-FM 93.3 was paired with an AM stream called "1090 KJR". Every city needs a hand check.
- **Radio Browser's own location data is weak.** Only 26% of US stations have coordinates, so the FCC list is the source for where a station is.

## Approaches considered

**Global or US local.** A global dial has plenty of stations (53,195 across 224 countries) but its frequencies would be invented. A US-local dial is real but thinner. The owner picked US local.

**How to build it.**

1. **Native app on the Duo simulator.** Real hinge, plays more kinds of stream, can give a haptic tick, nothing thrown away. Slowest to first sound. **Picked by the owner.**
2. **The web mock inside a thin native shell.** Fastest route to a real hinge, but a throwaway that keeps the browser's limits.
3. **Stay in the browser.** Dropped: it can never say anything about the hinge.

## How it behaves

### Tuning

- The hinge sweeps the needle across the glass, as in the mock: 70° puts it at the left end (87.5 MHz) and 150° at the right end (108.5 MHz). Angles outside that range pin the needle to the nearest end.
- **(my call)** These numbers are a starting point. The first build step measures what the simulator reports and at what angle the inner screen goes dark, then adjusts them.
- **The scale stretches where a city is crowded. (my call)** About half of each city's streamable stations sit between 88.1 and 91.9 MHz (5 of 11 in Seattle, 13 of 26 in New York, 14 of 26 in Chicago, 9 of 16 in Los Angeles). On a straight scale that band gets only 15° of the 80° sweep. So each city's scale is drawn unevenly: stations keep their true frequencies and their order, but neighbours are placed at least 4.5° of hinge apart, and the tick marks between them follow.
- **Snap.** Each station has a zone 3° wide. Outside a zone the needle is exactly where the hinge points. Inside, the station is locked and the needle rests on its mark, never more than 1.5° from the hinge. The hinge has to move a little past the zone's edge to let go, so it does not chatter. Between zones there is at least 1.5° of static.
- **One number switches the stretch off.** With the minimum spacing set to zero the scale is straight, as on a real radio, so the two can be compared.
- **At most 16 stations per city. (my call)** Sixteen stations at 4.5° fill 72° of the 80° sweep.
- Two stations on the same frequency in one city cannot both be on the dial. The corrections file picks one.
- **(my call)** On a Duo the hinge is the only way to tune. Tapping a station on the dial does nothing, because a tap cannot move the hinge.
- **(my call)** On a phone with no hinge, and in Xcode previews, dragging along the dial tunes instead.
- **(my call)** Simulator builds also carry a stand-in slider, behind a debug switch, that feeds the app an angle exactly as the hinge would. The owner needs it to sweep the dial while listening, and it keeps the work going if the simulator's own hinge turns out too coarse.
- **(my call)** Only this direct rule is built now. The tuning model is fed hinge readings as they arrive over time, not a single angle, so a knob-style rule can be added later without reshaping it. See "Risks".

### Sound

- A station fades up as the needle locks; static and a faint tuning whistle fill the gaps, as in the mock.
- The app connects about a quarter of a second after the needle settles, and keeps the last station connected for a few seconds after leaving it, so coming straight back is instant.
- A station that has not started within 12 seconds is marked "no signal" and crossed out for the rest of the session.
- **(my call)** A soft click marks each lock. A haptic tick is requested too, in one line, but it cannot be felt in the simulator and is not tuned.
- **(my call)** Plain `http` streams are allowed. That is fine for a prototype and would need a second look before shipping.

### Screens

- **Half open or flat:** the dial on the half above the fold (name, city, signal bars, lamp, the scale with station marks and needle, the station name) and the plate below it (speaker grille, four city keys, frequency readout, power button).

```
+------------------------------------------------+
| HINGE RADIO               SEATTLE  .:|||   (o) |
| +--------------------------------------------+ |
| |  KNKX   KUPS KEXP   KBCS      KUOW   KING  | |
| |   o      o    O      o         o      o    | |
| |  ' ' | ' ' ' | ' ' ' | ' ' | ' | ' | ' |   | |
| |  88      90   |  92     96    100   108    | |
| +--------------------------------------------+ |
| KEXP                                           |
| Seattle                                        |
+ - - - - - - - - - - fold - - - - - - - - - - - +
|   ::::::       [ SEA ]  [ NYC ]                |
|  ::::::::      [ CHI ]  [ LA  ]                |
|   ::::::       90.3 MHz                  (I)   |
+------------------------------------------------+
```

  The needle is the bar under KEXP. Note the uneven scale: 88 to 92 takes a third of the glass.
- **Closed:** sound stops. **(my call)** The outer screen shows a plain card saying the radio is closed and to open it to listen.
- The four keys switch city. The needle keeps its place on the dial, so a new city may open on static.
- Colours and proportions come from the mock: cream face, dark ink, orange needle, green lamp. The face looks the same in light and dark mode.
- **(my call)** The screen stays awake while the radio is on.

## How it is made

All **(my call)**; the owner chose "native app" and left the rest.

- A SwiftUI app with no outside libraries, for iOS 27.1 and later.
- Four parts, each usable on its own:
  - **Tuning model.** Plain logic: given a city and the hinge readings as they arrive, where is the needle, which station is locked, how strong is it. Unit tested.
  - **Hinge reader.** Turns `onHingeChange` into an angle and an open or closed state, with a stand-in for previews, phones with no hinge and the debug slider.
  - **Radio sound.** One player for the station, and a small sound engine for the static, whistle and click.
  - **Views.** Dial, plate, closed card.
- **Station file.** One file bundled in the app: for each city, its stations with call sign, frequency, display name, city of licence, stream address and website.
- **Station builder.** A Python script in `tools/`, standard library only, that:
  1. downloads the FCC FM list for each city's states and the Radio Browser US list;
  2. keeps licensed full-power FM stations within 60 km of the city centre;
  3. proposes a stream for each by call sign;
  4. applies a hand-kept corrections file per city (pick this stream, rename, leave out, add a stream by hand);
  5. connects to every chosen stream and reports the ones that do not answer;
  6. writes the station file.
- Claude picks each city's 16 for variety (public, college, community, commercial where one streams) and the owner can change the corrections file.

## Left to the builder

- Exact zone widths, fade curves and timings: start from the mock and tune by ear.
- How the Xcode project is created and laid out.
- Whether to bundle the mock's two fonts (Hanken Grotesk, DM Mono) or use system fonts.
- Whether to tell Radio Browser when a station is played, as the mock does.
- How station marks are labelled when sixteen of them share the glass.
- Which way up the Duo sits on a table, and so which orientations the app supports. Measure this on the simulator.

## How we will know it works

- Unit tests pass for the tuning model, including Chicago's crowded low end and a stretch of zero.
- On the Duo simulator, with the hinge set from here: switching on shows the lamp; stepping the angle moves the needle; landing in a zone locks a station and its player reports it is playing; between zones there is no station; closing stops the player; reopening restarts it.
- Screenshots at closed, half open and flat show nothing important across the fold.
- The owner listens. Claude can see that a stream is playing but cannot hear it.

## Risks

1. **The simulator may not deliver smooth angles.** The first build step is a bare app that prints the angle, before anything else is built. If the angles arrive too coarse to tune by, the build carries on with the stand-in slider: the stations, the sound and the layout can still be judged, and how the hinge feels waits for a real phone.
2. **The station decides the screen angle.** With a direct mapping, a station at the low end of the dial needs the lid near 70°, leaning forward, and one at the high end needs it near 150°, leaning far back. This may be the thing the prototype exists to find out. If it is uncomfortable, the alternative is a hinge that works like a knob, where bending moves the needle on from wherever it is. That is not designed or built here; the tuning model leaves room for it.
3. **Streams move.** Broadcasters change addresses and some block by region. The checker and the "no signal" mark cover this.
4. **Hinge feel and haptics cannot be judged in the simulator.** Accepted: the owner chose simulator only.
5. **This folder is temporary.** The work has to move to a folder the owner chooses before the app is built.
