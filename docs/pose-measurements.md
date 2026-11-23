# Pose measurements

Device: iPhone Duo simulator (iOS 27.1, UDID 6FBE2E12-829F-4E36-AACD-4F03F4E0638E). Probe: a throwaway view (since deleted, not committed) that showed and logged, on every `onHingeChange`, the hinge angle (two decimals), the hinge status, the size in points of a `GeometryReader` that ignores the safe area, and a counter in `@State` that goes up on every hinge change. It also logged a `size-change` line whenever that size changed, and a `PHASE` line on every `scenePhase` change. Log lines are subsystem `HingeRadio`, category `probe`, read with `log show`. Interface orientations allowed: portrait, landscape left, landscape right.

How to read the tables. "Lit screen" is the size the `set_posture` or `rotate` result text gave (taken from the tool's result text, not a screenshot, unless the row also has a probe size that agrees). "Reported" and "Size" are the probe's settled values (angle, status, size) from a screenshot after the call and from the log. "Count" is the counter. Each posture call was followed by one screenshot. Screenshots taken straight after a `rotate` sometimes showed the screen from before the turn (the tool said so in the result), so for turns the size column comes from the `size-change` log lines, which carry timestamps.

Run facts, from the whole log (314 hinge lines, 21 size-change lines):

- `PHASE` lines in the whole run: two, `inactive` then `active`, 36 ms apart, at app launch (17:43:07.792 and 17:43:07.828). None at any later time, through all six sequences.
- The counter only went up (3 at the first reading, 314 at the last). It never went back to a lower value, so the view was not rebuilt.
- A jump to an angle also plays an animation: the probe logs many intermediate angles, a few every 35 ms or so, before the settled one (for example 109.02 arrived after 105.93, 95.71, 79.82 on the way from 180 to 110 closing, and `closed` was reached via angles from 105.93 down to 0). Rows below give the settled value.

## Sequence 1: inner, partly folded, four turns

| Step | Lit screen | Reported angle | Status | Size (pt) | Count | PHASE lines since last posture |
|---|---|---|---|---|---|---|
| `open` | inner 669x951 | 180.00 | fullyOpen | 669x951 | 3 | none after launch |
| 110 (from open) | inner 669x951 | 109.02 | partiallyOpen | 669x951 | 29 | none |
| rotate left | inner 951x669 | 109.02 | partiallyOpen | 951x669 | 30 | none |
| rotate right | inner 669x951 | 109.02 | partiallyOpen | 669x951 | 31 | none |
| rotate right | inner 951x669 | 109.02 | partiallyOpen | 951x669 | 32 | none |
| rotate left | inner 669x951 | 109.02 | partiallyOpen | 669x951 | 33 | none |

Every turn on the inner screen changed the size (log: `size-change` 951x669 at 17:43:33.740, 669x951 at 17:43:40.654, 951x669 at 17:43:47.271, 669x951 at 17:43:53.186) and also fired one hinge callback carrying the unchanged angle 109.02 (the counter rose by one each time). The hinge line logged at that moment still carried the size from before the turn, so the size-change line came about 50 to 100 ms after it.

## Sequence 2: outer, partly folded, four turns

| Step | Lit screen | Reported angle | Status | Size (pt) | Count | PHASE lines since last posture |
|---|---|---|---|---|---|---|
| `closed` (from inner portrait) | outer 678x466 | 0.00 | closed | 678x466 | 44 | none |
| 60 (from closed) | outer 678x466 | 61.95 | closed | 678x466 | 69 | none |
| rotate left | outer 678x466 | 61.95 | closed | 678x466 (no size-change line) | 69 | none |
| rotate right | outer 678x466 | 61.95 | closed | 678x466 (no size-change line) | 69 | none |
| rotate right | outer 466x678 | 61.95 | closed | 466x678 | 69 | none |
| rotate left | outer 678x466 | 61.95 | closed | 678x466 | 69 | none |

Notes on this sequence, all from the log:

- On the outer screen no turn fired a hinge callback (the counter stayed at 69 and the angle at 61.95 for all four turns).
- Only the last two turns produced a `size-change` line (466x678 at 17:44:41.175, then 678x466 at 17:44:41.759). The first two turns (left, then right) produced none: the size stayed 678x466. Lag cannot be ruled out as the cause (see Decision 2).
- The size was wider than tall (678x466) at the start of this sequence and at every outer reading except the one 466x678 reading after the third turn. This is the size the outer screen reported after `closed` was set while the inner screen had just been turned back to portrait. An earlier measurement (`docs/hinge-measurements.md`, launched closed with no turns) read 466x678 on the outer screen, so the outer size without a turn depends on what came before. This run did not find out why.
- While the 60 degree jump settled, the probe reported the inner size first: at 17:44:12.235 a `size-change` to 669x951 with status partiallyOpen (angles 25.09 up to 61.95), then at 17:44:13.533 a `size-change` back to 678x466 with status closed, 1.3 s later. See the shut line table.

## Sequence 3: shut line, each jump from `closed`

Each row: `closed` first, then one jump. Lit screen was 678x466 (outer) for every commanded angle, from the tool's result text.

| Commanded | Reported angle (settled) | Status (settled) | Size (settled) | Count | Inner size shown on the way? |
|---|---|---|---|---|---|
| `closed` | 0.00 | closed | 678x466 | 44 (also 271 later) | no |
| 10 | 14.73 | closed | 678x466 | 89 | no |
| 15 | 19.45 | closed | 678x466 | 108 | no |
| 20 | 24.17 | closed | 678x466 | 134 | yes, 17:45:36.140 to 17:45:37.435 (1.3 s) |
| 25 | 28.89 | closed | 678x466 | 160 | yes, 17:45:51.296 to 17:45:52.648 (1.35 s) |
| 30 | 33.62 | closed | 678x466 | 188 | yes, 17:46:05.605 to 17:46:06.980 (1.4 s) |

Where the inner size was shown on the way (commanded 20, 25, 30, and 60 in sequence 2): the first line with status partiallyOpen was at 20.28 (jump to 20; the line before it was 19.88 closed), 21.03 (jump to 25) and 22.20 (jump to 30), still with the outer size; the size became 669x951 about 70 to 120 ms later while the angle kept rising with status partiallyOpen. The status went back to closed together with the settled angle (24.17, 28.89, 33.62) about 0.7 to 1 s later, with the size returning to the outer 678x466 about 0.1 s after that. For the 10 and 15 jumps no line had status partiallyOpen (checked over the log lines with counters 84 to 125) and no inner size was shown.

## Sequence 4: flat line, from `open`

Lit screen was inner 669x951 for every row (tool result text, and the probe size agrees).

| Commanded | Reported angle | Status | Size (pt) | Count |
|---|---|---|---|---|
| `open` | 180.00 | fullyOpen | 669x951 | 206 |
| 170 | 165.77 | partiallyOpen | 669x951 | 220 |
| 172 | 167.73 | partiallyOpen | 669x951 | 222 |
| 174 | 169.62 | partiallyOpen | 669x951 | 224 |
| 175 | 170.56 | partiallyOpen | 669x951 | 225 |
| 176 | 171.51 | partiallyOpen | 669x951 | 226 |
| 178 | 172.50 | partiallyOpen | 669x951 | 227 |
| 179 | 173.72 | partiallyOpen | 669x951 | 228 |
| `open` | 180.00 | fullyOpen | 669x951 | 230 |

The highest settled reading below `open` was 173.72 (commanded 179). Only `open` read 175 or more.

## Sequence 5: screen switch, open, 110, closed, 60, open

| Step | Lit screen | Reported angle | Status | Size (pt) | Count | PHASE lines since last posture |
|---|---|---|---|---|---|---|
| `open` (the last row of sequence 4) | inner 669x951 | 180.00 | fullyOpen | 669x951 | 230 | none |
| 110 | inner 669x951 | 109.02 | partiallyOpen | 669x951 | 258 | none |
| `closed` | outer 678x466 | 0.00 | closed | 678x466 | 271 | none |
| 60 | outer 678x466 | 61.95 | closed | 678x466 | 296 | none |
| `open` | inner 669x951 | 180.00 | fullyOpen | 669x951 | 314 | none |

Size changes from the log: 678x466 at 17:47:34.911 (closing), 669x951 at 17:47:42.465 then 678x466 at 17:47:43.766 (the 60 jump, the same 1.3 s inner flash as above), 669x951 at 17:47:51.225 (opening). The counter went from 230 to 314 without a reset, and no `PHASE` line appeared at any switch.

## Sequence 6: blip length

Not run. The step applies only if a `PHASE` line left `active`; none did in any sequence (see the run facts above), so there was nothing to repeat and no gap to measure.

## Decisions

### 1. Which screen

Keep the rule: outer when the window's short side is under 560 pt.

Readings: every outer reading had a short side of 466 (678x466, and 466x678 once). Every inner reading had a short side of 669 (669x951 and 951x669). 466 is under 560 and 669 is over, with no exceptions among the settled readings. Keeping 560 rests on those settled readings and is a judgement, since the transient inner-size readings below appear for about 1.3 s. One caveat from the log: for about 1.3 s after a jump from `closed` to 20 degrees or more, the probe reported the inner size (669x951) before the outer size returned (sequence 3, and sequence 2 and 5 at 60). Any code that decides the screen from the size will see the inner answer for that time.

### 2. Which way up

What was measured on the inner screen: each of the four turns changed the window size (951x669, 669x951, 951x669, 669x951, sequence 1, with `size-change` lines about 6.6 s apart), and each fired one hinge callback. On the inner screen, wider than tall was a usable landscape signal.

What was measured on the outer screen: the size was already wider than tall (678x466) before any turn. Of the four turns, only the last two produced a `size-change` line (466x678, then 678x466, 0.6 s apart); the first two produced none, and no hinge callback fired on any outer turn. These turn results are inconclusive: the turns were sent in quick succession and screenshots after a rotate were seen to lag, so it is not shown that the first two turns had settled when the next call went in. A timing artifact cannot be ruled out, so "outer turns are unreliable" is not a measured fact.

Rule that follows: landscape = wider than tall on the inner screen. On the outer screen, wider than tall is not evidence of a turn (it was true with no turn at all), so nothing may depend on the outer screen's way up. The only orientation signal the probe observed was the window size; it did not look at interface or device orientation, so no claim is made about other signals.

### 3. Shut line

20 stays.

Readings: `closed` reads 0.00 (below 20). A commanded 25 reads 28.89 on settled (20 or more). A commanded 15 reads 19.45 and a commanded 20 reads 24.17, so the settled readings cross 20 between commanded 15 and 20. During the jump to 20 and above the probe also logged status partiallyOpen from 20.28 and an inner size for about 1.3 s, then status closed again at the settled angle (sequence 3).

### 4. Flat line

175 stays.

Readings: `open` reads 180.00 (175 or more); a commanded 170 reads 165.77 (below 175). Also measured: no commanded angle below `open` read 175 or more; the highest was 173.72 at commanded 179, and commanded 175 read 170.56. So on this simulator only `open` itself (status fullyOpen) reaches the flat line.

### 5. Scene phase

Stays active through screen switches and turns.

Readings: in the whole run there were two `PHASE` lines, `inactive` then `active` at launch, and none after. That includes the switch sequence (open, 110, closed, 60, open), all turns on both screens, and all jumps. The blip-length step did not apply (sequence 6).

### 6. Tent verdict

Tent can be told from shut on the simulator.

Readings: on the outer screen, partly folded, the settled reported angle was 24.17, 28.89, 33.62 and 61.95 (commanded 20, 25, 30, 60), all 20 or more, with status closed and an outer window size (678x466); `closed` read 0.00. The reason it can be told: the outer screen reports the hinge angle while partly folded, and the status stays `closed` there, so the angle is what separates a partly folded outer pose from shut. The inner-size flash of about 1.3 s after a jump (sequence 3) is a separate effect that a tent check based on the settled angle would need to wait out.
