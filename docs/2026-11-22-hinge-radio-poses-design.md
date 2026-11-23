# Hinge Radio: poses and touch tuning

Date: 2026-11-22. Status: approved by the owner on 2026-11-22.

This follows `docs/2026-11-22-hinge-radio-us-local-design.md` (the first design). Where the two disagree, this one wins. Everything the first design says that this one does not mention still holds.

Lines marked **(my call)** are choices Claude made that the owner has not confirmed. Everything else was said or picked by the owner.

## What the owner asked for

After trying the first build, in their words:

1. "Only allow flex mode - no need of any other mode"
2. "Give the ability to slide the on the radio frequency on the bottom screen as i keep in flex mode and use it"
3. "i can also keep it and use it like a standby mode where the its partially fold or stand up mode"

For 3 they pointed at Apple's support page "Pose iPhone Duo" and then picked **book and tent** as the standby poses.

## Why

The owner sets the phone down half open and uses it there. **(my call)** In the first build the hinge angle chose the station, so a phone resting at one angle was held on one frequency, and tuning meant moving the screen. Tuning has to move to a finger.

## The poses

Names are Apple's, from that page, with the owner's word where it differs.

| Pose | How the phone is | Screen facing you |
|---|---|---|
| **Flex** (Apple: seated) | Partly folded, lower half flat on the table | Inner, portrait |
| **Book** | Partly folded, stood on its long edge like an open book | Inner, landscape |
| **Tent** | Partly folded, stood like a tent | Outer, landscape |
| **Flat** | Fully open | Inner |
| **Shut** | Closed | Outer |

## Goals

1. **Flex is the radio.** The full radio shows only in flex.
2. **A finger tunes.** In flex, sliding along a tuning strip on the lower half moves the needle.
3. **The hinge no longer tunes.** Claude told the owner this on 2026-11-22 as a consequence of 1 and 2. The owner carried on without objecting and has not confirmed it in words.
4. **Book and tent are standby.** A face that can be read from across a room, with the radio still playing.
5. **Flat shows a card** asking for the phone to be folded. No radio controls.
6. **Shut is silent**, as now. Opening again resumes if the radio was on.
7. **Moving between poses never cuts the sound. (my call)** Only shutting the phone, switching off, or leaving the app silences it.

## Non-goals

- Apple's own StandBy (locked phone, charging, background playback). The owner picked an in-app standby.
- **(my call)** Tuning or changing city in standby. You put the phone in flex to do either.
- **(my call)** A clock, or anything on the standby face that is not the radio's own state.
- The hinge as a knob.
- Telling a phone that is set down from one held in the hand. The phone does not report it.
- Remembering the station between launches.
- A real phone. Still simulator only.

## What would make it a failure even if it runs

- A tuning strip too fiddly to land on a station and stay there with a finger.
- Sound that drops out when the phone is moved from one pose to another.
- A standby face that cannot be read from across a room.
- Anything important on the fold. In flex the fold runs across the middle; in book it runs down the middle.
- The radio playing while the phone is shut.

## What we know

- **Apple's page names three partly folded poses.** Book has the inner display facing you in landscape, tent has the outer display facing you in landscape, and seated has the inner display in portrait. It suggests book and tent for StandBy.
- **The hinge reports two things only**: an angle, and a status of closed, partly open or fully open. Checked in the iOS 27.2 simulator SDK on 2026-11-22. It says nothing about which screen is lit, which way up the phone is, or whether it is on a table.
- **Screen sizes** (from `docs/hinge-measurements.md`): inner 669 x 951 pt in portrait and 951 x 669 in landscape; outer 466 x 678 pt. The inner screen is two outer-size panels. The fold line is worked out from that geometry; the simulator draws none.
- **On the simulator, status reads "closed" whenever the outer screen is lit**, even with the hinge at 70 or 110 degrees. So status cannot tell tent from shut. The angle can: shut reads 0.00, and a commanded 20 reads 24.17.
- **Which screen the simulator lights depends on how the hinge got there.** A jump from closed to 84 or less keeps the outer screen. Stepping up from closed keeps the outer screen until about 170. Stepping down from open keeps the inner screen down to 16.
- **Not known:** whether the app is told it is in landscape on the outer screen; what the app sees when the simulator is turned while partly folded; how a real phone chooses the lit screen.
- **The tuning rules do not care where a position comes from.** The hinge, a debug slider and a hidden drag on the dial all feed the same function today.

## Approaches considered

**Standby.** Put to the owner on 2026-11-22.

1. **Our own standby face for book and tent.** All in the app, checkable on the simulator. Tent costs more: the outer screen being lit means "closed and silent" today, and the simulator is fussy about which screen lights. **Picked by the owner.**
2. **Book only.** About half the work and none of the tent risk.
3. **Apple's real StandBy.** Apple's look, needs background playback, and probably cannot be shown on the simulator.

**How a finger moves the needle. (my call)** Not put to the owner as a choice; their words were "slide on the radio frequency".

1. **Position strip.** The strip is a copy of the dial's scale and the needle goes to where the finger is. Station marks line up with the dial above. The snap rule carries over unchanged. **Picked.**
2. **Thumbwheel.** Dragging moves the needle by the distance dragged. Finer, but slow from one end to the other, and it needs new rules.
3. **Step buttons.** Next and previous station. Loses the static between stations, which is the radio's character.

## How it behaves

### Which pose the phone is in

The app works the pose out from four things: which screen is showing it, whether that screen is in landscape, the hinge angle, and the hinge status.

| Screen | Hinge | Way up | Pose | Shows | Sound |
|---|---|---|---|---|---|
| Either | Angle below 20 degrees | Any | Shut | Closed card | Silent |
| Outer | 20 degrees or more | Landscape | Tent | Standby face | Plays |
| Outer | 20 degrees or more | Portrait | Not a named pose | Standby face, upright **(my call)** | Plays |
| Inner | 20 to 175 degrees | Portrait | Flex | Full radio | Plays |
| Inner | 20 to 175 degrees | Landscape | Book | Standby face, two panels | Plays |
| Inner | 175 degrees or more, or status fully open | Any | Flat | "Fold me" card | Plays |

- **(my call)** 20 degrees is a starting point. It replaces today's "closed below 45 degrees". The first build step checks it.
- **(my call)** Flat starts at 175 degrees, not only at the "fully open" status. In the measurements the status says fully open only at 180, and 165.84 still reads partly open, so by status alone flat would almost never show when folding by hand. The first build step checks this number too.
- **(my call)** A phone with no hinge, and Xcode previews, count as the inner screen partly open: flex in portrait, standby in landscape.
- "Plays" means: if the radio is switched on and the app is in front.
- The app stops being locked to portrait. It supports portrait and both landscapes.

### Flex

The top half is the dial, as now. The lower half changes.

```
+------------------------------------------------+
| HINGE RADIO               SEATTLE  .:|||   (o) |
| +--------------------------------------------+ |
| |  KNKX   KUPS KEXP   KBCS      KUOW   KING  | |
| |  88      90   |  92     96    100   108    | |
| +--------------------------------------------+ |
| KEXP                                           |
| Seattle                                        |
+ - - - - - - - - - - fold - - - - - - - - - - - +
|  [ SEA ] [ NYC ] [ CHI ] [ LA ]   90.3 MHz (I) |
|                                                |
| +--------------------------------------------+ |
| |  '  '  |  '  ' [#] '  |  '  '  |  '  |  '  | |
| |  88      90     ^     92     96   100  108 | |
| +--------------------------------------------+ |
+------------------------------------------------+
```

- **The tuning strip** runs the full width of the lower half. It carries the same stretched scale and station marks as the dial, so a station sits at the same place across on both.
- **(my call)** It takes the place of the speaker grille, which was decoration. The city keys, the frequency readout and the power button stay.
- **Touching or dragging the strip puts the needle under the finger.** A tap jumps there.
- **The snap is unchanged.** Inside a station's zone the needle rests on the station's mark and the station plays. The finger has to move a little past the zone's edge to let go.
- **(my call)** Lifting the finger leaves the needle where it is. Lift between stations and it stays on static.
- **(my call)** The strip is at least 60 pt tall so a finger can find it without looking.
- **(my call)** The dial on the top half does not respond to touch. Pressing the upright half tips the phone.
- At launch the needle starts mid-dial, as now. Changing city keeps the needle's place, as now.
- The soft click and the haptic tick on each lock stay.

### Standby (book and tent)

- **Shows:** the station name, the line under it (city of licence, or "Tuning in", "No signal", "Static", "Switch on to listen"), the frequency, the lamp, and the power button.
- **The station name and the frequency are the two biggest things on the screen.**
- **Book** uses the two panels, with nothing in the clear band at the fold:

```
+----------------------+----------------------+
|                      |                      |
|  KEXP                |        90.3          |
|  Seattle        (o)  |        MHz     (I)   |
|                      |                      |
+----------------------+----------------------+
       left panel     fold     right panel
```

- **Tent** is one panel with the same things on it.
- No tuning strip and no city keys.
- Same colours as the radio face. The screen stays awake while the radio is on, as now.

### Flat

- A card, kept off the fold. Title: **"Fold me"**. Line under it: **"Sit the phone half open to use the radio."**
- **(my call)** If the radio is on it keeps playing. Flat is something you pass through; silence there would break goal 7.

### Shut

- The closed card and silence, as now. Its words stay: "Closed" and "Open the phone to listen again."

### What goes away

- Tuning by hinge angle.
- **(my call)** The debug hinge slider and the long-press that showed it. Its job was tuning by hand on the simulator while listening; the strip does that now.
- **(my call)** Dragging on the dial glass on a phone with no hinge. The strip works on every phone.
- The portrait lock.

## How it is made

All **(my call)**.

- **The pose rule is plain logic in `RadioCore`**, next to the other rules, with a unit test for every row of the pose table.
- **The radio takes two separate inputs** where it took one: a dial position from the finger, and what the hinge and screen report. Sound follows goal 7; the display follows the pose.
- **The dial's own numbers stay as they are.** The scale is still laid out in the old "degrees" (70 to 150, stations at least 4.5 apart, zones 3 wide), now as plain dial units with no tie to the hinge, so the tested snap and fade rules are untouched.
- **The app** reads the hinge with `onHingeChange` as now, and works out which screen and which way up from the window it is given.
- **Views:** the plate gains the strip and loses the grille; a new standby view; a new "Fold me" card.
- Tests that pin hinge tuning and "below 45 degrees is closed" are replaced by tests for the new rules.

## Left to the builder

- How the app tells the inner screen from the outer one, and landscape from portrait, once the first build step has measured what the simulator reports.
- Exact sizes, spacing and type sizes, within the rules above.
- How the strip's marker looks.
- Which panel holds what in book pose, if the sketch does not fit.
- Where on its half each card sits.

## How we will know it works

- Unit tests pass: every row of the pose table; tuning by position, with snap and release; sound on in every pose but shut.
- On the Duo simulator, driven from here, with the app's log read at each step:
  - **Flex:** dragging the strip moves the needle, locks a station, and the player reports it playing.
  - **Flex to book:** the standby face shows the same station, and the log shows no stop or reconnect.
  - **Tent:** the standby face on the outer screen, still playing.
  - **Flat:** the card, still playing.
  - **Shut:** the player stops. Reopening restarts it.
- A screenshot of each pose shows nothing important on the fold.
- The owner tries the strip with a finger and listens. Claude can drag the strip on the simulator but cannot judge how it feels or hear it.

## Risks

1. **Tent may be hard to reach or to recognise on the simulator.** Which screen lights is path-dependent, status reads "closed" on the outer screen, and landscape on the outer screen is untested. The first build step measures all three before anything else is built. If tent cannot be told from shut there, flex and book are built and checked, and tent ships with its rule written and unit tested but marked unverified.
2. **A real phone may choose its lit screen differently.** Not testable here.
3. **If the system does not turn the app** (an orientation lock, say), book pose shows the flex layout on its side.
4. **Finger precision.** Sixteen stations share a strip about 600 pt wide. The closest pair is about 34 pt apart and a zone is about 22 pt wide. That may be tight.
5. **The 20 degree line.** Too low and the radio could play when nearly shut; too high and a narrow tent goes silent.
6. **Flat keeps playing behind a card.** The owner may prefer silence there.
