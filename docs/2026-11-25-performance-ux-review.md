# Hinge Radio: performance and UX review

Date: 2026-11-25, on commit `c0f480c`. Status: findings only; nothing changed.

How it was done: two independent code reviews (performance, and UX walked as several kinds of people), each claim then checked against the code; one measurement with Instruments (Time Profiler) on the iPhone Duo simulator. A measurement on CDuo was tried but the app was not in front (screen off), so it recorded nothing from it. The simulator was then taken over by another app, so the "playing" and "rolling the wheel" measurements were not made. Full working notes: `.superpowers/review/perf-review.md` and `ux-review.md` (local, not committed).

Severity: **High** means many people hit it or it costs battery all the time. **Measured**, **Checked in code** or **Suspected** says how sure.

## The ranked list

| # | Finding | Kind | Severity | How sure |
|---|---|---|---|---|
| 1 | The sound engine runs all the time the app is in front, even switched off | Battery | High | Measured |
| 2 | Locking the phone, or opening Control Center, stops the radio | UX | High | Checked in code |
| 3 | Every drag and every frame redraws the whole screen | Smoothness, heat | High | Checked in code; cost suspected |
| 4 | At a bedside the bright cream face stays lit all night | UX, battery | High | Checked in code |
| 5 | First launch opens switched off, dim and silent, with no hint | UX | High | Checked in code |
| 6 | HERE's messages are hidden while off, and every failure says the same thing | UX | High | Checked in code |
| 7 | "No signal" sticks to a station until the app is relaunched | UX | High | Checked in code |
| 8 | HERE searches again almost every visit, now that its dial is short | Network, battery | Medium | Checked in code |
| 9 | Flat shows "Fold me" with no way to stop or turn down the radio | UX | Medium | Checked in code |
| 10 | Text sizes are fixed; contrast is low when off; Increase Contrast is ignored | Inclusivity | Medium | Checked in code |
| 11 | The tuning wheel's tap halves can't be discovered; volume isn't remembered | UX | Medium | Checked in code |
| 12 | VoiceOver hears nothing when a station starts, fails, or HERE finishes | Inclusivity | Medium | Checked in code |
| 13 | The player is polled every 0.1 s forever; sound-session calls block the main thread | Battery, smoothness | Low | Checked in code |
| 14 | `shownName` runs four regular expressions each time a name is drawn | Smoothness | Low | Checked in code |
| 15 | "About" opens only by a long press, and nothing else explains the radio | UX | Low | Checked in code |

## Details

### 1. The sound engine never rests (measured)

With the radio switched off and untouched in Seattle, the app used **1.47 s of CPU in 15 s (about 10% of a core)** on the simulator; 89% of it was the audio output thread rendering silence through the static generator, an EQ and a mixer. `RadioModel.appIsActive` starts the engine whenever the app comes to the front and off (`RadioModel.swift:224`), so the wheels' ticks can sound at once; nothing stops it while the radio stays off. On a phone this keeps the audio hardware awake, which costs battery in exactly the case the app is idle on a bedside or a desk.

Fix: start the engine on the first touch of a wheel or on power-on, and stop it (and release the session) about 2 s after the last tick while the radio is off. The first tick after a rest may come a few milliseconds late; prepare the engine on touch-down to hide it.

### 2. The radio stops when the phone locks, and on Control Center

There is no background audio mode, no Now Playing and no lock-screen controls. Any `scenePhase` that is not `.active` suspends the radio (`HingeRadioApp.swift:16`, `RadioModel.swift:222`), and `.inactive` includes pulling down Control Center or Notification Center, a system alert, or the location prompt: each drops the station and reconnects it. To keep listening, the screen must stay on, which is why the app disables the idle timer while playing (`RootView.swift:90`). This was item 2 in the 2026-11-22 design review and is still open.

Fix: suspend only on `.background`; then add the `audio` background mode, Now Playing info and remote commands (play/pause), so the radio plays on with the screen off and shows on the lock screen. Stream rights are unchanged by this.

### 3. One property drives every view

All of the radio's state is one `@Observable` property, `radio` (`RadioModel.swift:10`). Each drag event on the tuning wheel and each frame of a glide or HERE's sweep (up to 120 a second) writes it, so `RootView`, `DialView`, `ScaleFace`, `SideWheels`, `BandSwitch` and `StandbyView` all recompute, and the dial's Canvas and both wheel rims redraw, even the volume wheel when only tuning moves. Not measured: the simulator was taken by another app before the wheel could be rolled under Instruments.

Fix: measure first on CDuo with the SwiftUI and Animation Hitches templates while rolling the wheel. If it shows hitches, split what moves every frame (needle position, wheel phases) into their own observed values, so only the needle and the moving wheel redraw.

### 4. The bedside case

Light mode is forced (`RootView.swift:78`); there is no night face and no sleep timer, and the screen is kept on while the radio plays. A bright cream screen all night is the opposite of what a bedside radio should be. Fixing 2 lets the screen sleep; a night face (near-black, warm ink, the same orange) following the system's dark mode is design review item 3.

### 5. First launch

The radio always opens switched off (by design), and off shows no words at all: the dial dims to about 2:1 contrast, and nothing says to roll or tap VOLUME. A first-time user sees a greyed-out radio and no instruction. Fix: when off, the line under the name says "Roll VOLUME up to switch on" (or "Tap VOLUME to switch on") until the radio has been switched on once; a short first-run hint that the TUNING wheel rolls.

### 6. HERE's messages

`Radio.display` returns empty text whenever the power is off (`Radio.swift:220`), before HERE's status is considered, and the radio always opens off: so "Location is off", "Finding stations…" and "No stations found here" are hidden until the radio is switched on. And when no position arrives in time, HERE says "No stations found here" (`HerePlan.swift:119`), the same words as a search that found nothing; outside the US it says the same again. Fix: show HERE's status even when off; separate "Can't find where you are", "No connection", "No stations found here" and "HERE works in the US only"; with location refused, offer the Settings link.

### 7. "No signal" sticks

A station that fails twice is marked dead until the app is relaunched (or HERE is chosen again). On a poor connection stations die one by one and stay struck off, and a network outage looks the same as a station that is down. Fix: try a dead station again when the needle returns to it after a minute or more, and when the network comes back.

### 8. HERE searches again almost every visit

A dial with fewer than 8 stations counts as thin and is searched again after 10 minutes (`Here.swift:60-62`). Without iHeart, HERE's dial is usually 3 to 5 stations, so nearly every visit runs a full search (up to 30 s of network and the FCC), and an empty result searches again on each return. Fix: judge thinness against what that place found before (a refresh that found the same count is not thin), and back off after a refresh that changed nothing (10 minutes, then hours).

### 9. Flat

Flat shows only "Fold me" while the radio may be playing. Nobody can stop or turn it down without folding. Fix: put the volume wheel (or at least a power control) on the flat card, or show the whole dial as design review item 11 proposed.

### 10. Text and contrast

Text sizes are fixed and follow the screen, not the text-size setting or Bold Text (outside the About card). Off, the dial and frequency dim to about 2:1. Increase Contrast is not honoured. Fix: multiply sizes by the Dynamic Type scale with layouts that reflow; keep off-state text at 4.5:1; darken muted ink under Increase Contrast.

### 11 to 15

- **11.** Stepping a station by tapping the upper or lower half of the tuning wheel cannot be discovered, and a tap that moves 4 to 6 pt does nothing. Volume is not remembered, so every launch starts at the default. Visible next/previous controls were design review item 9.
- **12.** VoiceOver gets no announcement when a station starts playing, fails ("No signal"), or HERE finishes. Post an announcement for each.
- **13.** `StationPlayer` checks the player every 0.1 s for as long as the app runs (`StationPlayer.swift:25`), connected or not; the audio session's category and activation calls run synchronously on the main thread inside the volume gesture (the README already notes the system's warning). Tick only while connecting or playing; move session calls off the main thread.
- **14.** `Station.shownName` builds and runs four regular expressions per call, and the standby face reads the display five times per update. Work it out once per station when the list loads.
- **15.** "About" is reached only by a long press on the badge, and there is no help. The About screenshot (`docs/check/61-about.png`) still shows iHeart.

## What to keep

- Sound that never depends on the pose, and a standby face readable across a room.
- Lamps always backed by words, ticks and haptics: colour is never the only signal.
- The groundwork already in place for VoiceOver, Reduce Motion and location privacy (approximate location only, position rounded, never logged).

## Suggested order

1. **Quick, low-risk fixes** (about a day): 1 (engine rests), 2's first half (Control Center no longer drops the station), 6, 7, 8, 13.
2. **Background audio and the lock screen**: the rest of 2, which also lets the screen sleep (half of 4).
3. **Night face and text that scales**: 4, 10, 12.
4. **First run and flat**: 5, 9, 11, 15.
5. **Measure 3 on CDuo**, and restructure only if it shows hitches.
