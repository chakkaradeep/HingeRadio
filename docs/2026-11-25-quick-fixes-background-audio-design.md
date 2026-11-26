# Hinge Radio: quick fixes and background audio

Date: 2026-11-25. Status: chosen by the owner ("Quick fixes and background audio") from `docs/2026-11-25-performance-ux-review.md`, items 1, 2, 6, 7, 8 and 13. Lines marked **(my call)** are Claude's and unconfirmed.

## Why

The review found the radio wastes battery when it is doing nothing, stops whenever the phone locks or Control Center opens, hides HERE's messages, and strikes stations off for the rest of a run. This pass fixes those, and lets the radio play with the screen off and be controlled from the lock screen.

## Goals

1. **The sound engine rests.** With the radio off, the engine and the audio session stop 2 s after the last tick or click, and start again on the next touch of a wheel or the band switch, or on power-on. Measured before: about 10% of a core while off and untouched (simulator). **(my call: 2 s)**
2. **The player is checked only while it has work.** The 0.1 s check runs only while a station is wanted, connecting or playing.
3. **Control Center, alerts and the location prompt no longer stop the radio.** Only going to the background matters, and:
4. **Background audio.** With the radio on, going to the background (locking the phone, another app) keeps it playing: the `audio` background mode, the `.playback` session as now. With the radio off, going to the background suspends it as now. Unplugging headphones (the old route going away) switches the radio off, as music apps pause. **(my call)** Interruptions (a call, an alarm) behave as now: the system stops the sound and the radio resumes when the system recommends it.
5. **Lock screen and Control Center.** While the radio is on, Now Playing shows:
   - title: the station's shown name, or "Between stations" when nothing is locked **(my call)**, or "No signal";
   - artist: the frequency under the needle and the licence city, for example "90.3 MHz · Seattle";
   - album: the band's name ("Seattle", or HERE's town);
   - live stream, no progress bar; artwork: the app icon.
   Commands: play switches on (at the last volume), pause switches off, next and previous step a station (as a tap on the tuning wheel). No seeking. Cleared when the radio switches off.
6. **HERE says what is happening, even switched off.** With HERE as the band and the radio off, the line under the name shows HERE's status: "Finding stations…", "No stations found here", "Location is off". Failures are told apart:
   - no position in time: "Can't find where you are";
   - no network (the FCC lookup failed to connect): "No connection";
   - the FCC answered with no licensed stations at all: "HERE covers the US only" **(my call: that answer is what a place outside the US gets)**;
   - stations in reach but none with a stream: "No stations found here".
7. **"No signal" is not for ever.** A station marked "No signal" is tried again when the needle comes back onto it 60 s or more after it was marked **(my call: 60 s)**, and every such station is tried again when the network comes back after being lost.
8. **HERE stops searching again and again.** A short dial (under 8 stations) is still searched again after 10 minutes the first time; each refresh that finds the same stations doubles the wait (20 min, 40 min, … up to 24 hours) **(my call)**. A search that finds nothing is not repeated on returning to the app within 10 minutes, unless HERE is chosen by hand.

## Non-goals

- A night face, text that scales, VoiceOver announcements, the first-run hint, the flat card, measuring redraws (later batches in the review).
- Letting the screen sleep while playing: the screen still stays on while the radio is on, so the standby face can be read; the side button now locks it without stopping the sound **(my call)**.
- A Settings link from "Location is off".

## Approaches

- **Background audio: chosen** — the system's `audio` background mode with the existing `.playback` session and `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter`. The only way an iOS radio plays with the screen locked.
- Engine rest: **chosen** — stop the engine after a short idle while off. The alternative, rendering a cheaper silent graph, still keeps the hardware awake.

## How it is made

- Rules in `RadioCore`, with tests: when the engine may rest; what Now Playing says; HERE's new statuses and their words; when a dead station is tried again; the refresh back-off.
- The app wires them: the scene phase, the session, route changes, the network path (`NWPathMonitor`), the remote commands.

## How we will know

- Unit tests for each rule.
- On the Duo simulator (when it is free): Time Profiler with the radio off and untouched shows the engine idle; Control Center pulled down keeps the station; locking keeps it playing, and Now Playing shows it.
- On CDuo: the owner locks the phone and keeps listening, and uses the lock screen's controls.
