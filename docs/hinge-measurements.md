# Hinge measurements

Device: iPhone Duo simulator (iOS 27.1, UDID 6FBE2E12-829F-4E36-AACD-4F03F4E0638E). Probe: `App/HingeProbeView.swift`, reading `onHingeChange`. Reported angles and statuses below were read from probe screenshots taken after a `set_posture` call; rows marked "text only" took the lit screen from the `set_posture` result and have no screenshot. Screenshots are 1398x2034 px for the outer screen and 2853x2007 px for the inner screen (landscape).

## Table: ascending sweep from closed

First sweep, run once after launch. Each posture was set in turn, starting closed, rising, with irregular steps (20, 45, 70, 70.5, 71, 90, 110, then a 40 degree step to 150). Updates is the probe's running counter.

| Angle set | Angle reported | Status | Lit screen (pt) | Updates | View size (pt) | Screenshot (px) |
|---|---|---|---|---|---|---|
| closed (launch) | 0.00 | closed | outer 466x678 | 1 | 382x644 | 1398x2034 |
| 20 | 24.17 | closed | outer 466x678 | 17 | 382x644 | 1398x2034 |
| 45 | 47.78 | closed | outer 466x678 | 37 | 382x644 | 1398x2034 |
| 70 | 71.39 | closed | outer 466x678 | 56 | 382x644 | 1398x2034 |
| 70.5 | 71.87 | closed | outer 466x678 | 57 | 382x644 | 1398x2034 |
| 71 | 71.87 (no new reading) | closed | outer 466x678 | 57 | 382x644 | 1398x2034 |
| 90 | 89.96 | closed | outer 466x678 | 82 | 382x644 | 1398x2034 |
| 110 | 108.85 | closed | outer 466x678 | 111 | 382x644 | 1398x2034 |
| 150 | 146.95 | partiallyOpen | inner 951x669 | 135 | 867x635 | 2853x2007 |
| 170 | 165.84 | partiallyOpen | inner 951x669 | 146 | 867x635 | 2853x2007 |
| open | 180.00 | fullyOpen | inner 951x669 | 155 | 867x635 | 2853x2007 |

## Screen thresholds, by procedure

Which screen is lit, and the status, depend on how the hinge reached an angle, so each procedure is listed on its own. "Jump" is one `set_posture` call straight from closed or open. "Step" is a series of calls. "Text only" means the lit screen comes from the `set_posture` result and no screenshot was taken at that angle. Every reported angle and status is from a probe screenshot. "Outer" is the 466x678 screen (view 382x644 pt), "inner" is 951x669.

### (i) Jump from closed

One call from closed to the commanded angle (closed was set again before each row).

| Commanded | Lit screen | Reported |
|---|---|---|
| 70 | outer | 71.39 closed |
| 75 | outer (text only) | not read |
| 80 | outer (text only) | not read |
| 82 | outer | 82.73 closed |
| 83 | outer | 83.67 closed |
| 84 | outer | 84.62 closed |
| 85 | inner | 85.56 partiallyOpen |
| 90 | inner (text only) | not read |
| 100 | inner (text only) | not read |
| 110 | inner | 109.17 partiallyOpen |
| 111 | inner | 110.12 partiallyOpen |

Result: among the angles tried (70, 75, 80, 82, 83, 84, 85, 90, 100, 110, 111), a jump from closed first lights the inner screen at 85 commanded (85.56 reported) and not at 84.

The controller sequence "closed, then 111, 112, 113, 114, 115" is also a jump from closed followed by 1 degree steps: 111 lit, and 112 to 115 stayed lit (text only). 116 to 120 were not run in that sequence.

### (ii) Stepped from closed

Result: this depends on the step size. In run A (10 degree steps) the inner screen first lights at 170 commanded, and stays dark through 160. In run B (10 degree steps to 160, then 1 degree steps) it first lights at 172 commanded (text only), and stays dark through 171. In the first sweep, a single 40 degree step from 110 to 150 lit the inner screen (146.95 partiallyOpen, row 150 of the table at the top). The earlier run ("steps of 1 degree after a 25 degree step", below) stayed outer through 120.

Run A, 10 degree steps (closed, then 10, 20 ... 170, then open), run twice:

| Commanded | Lit screen | Reported |
|---|---|---|
| 10 to 150 | outer (text only, both runs) | not read |
| 160 | outer | 156.07 closed (screenshot, second run) |
| 170 | inner | 165.84 partiallyOpen (screenshot, second run; first run text only) |
| open | inner (text only, first run) | not read |

Run B, same 10 degree steps to 160, then 1 degree steps (the 10 to 160 steps were text only):

| Commanded | Lit screen | Reported |
|---|---|---|
| 161 to 168 | outer (text only) | not read |
| 169 | outer | 164.57 closed |
| 170 | outer | 165.52 closed |
| 171 | outer (text only) | not read |
| 172 | inner (text only) | not read |
| 174, 176, 178, 179, open | inner (text only) | not read |

Run B did not run 173, and the inner screen at 172 was not confirmed with a screenshot.

Earlier run, steps of 1 degree after a 25 degree step (closed, jump to 84, then 85, then 110, then 111 to 120, in this order):

| Commanded | Lit screen | Reported |
|---|---|---|
| 85 (after 84) | outer | 85.56 closed |
| 110 | outer | 108.85 closed |
| 111 | outer | 109.79 closed |
| 115 | outer | 113.57 closed |
| 120 | outer | 118.29 closed |
| 112 to 114, 116 to 119 | outer (text only) | not read |

First sweep (table at the top): outer and `closed` through 110 (108.85), then a 40 degree step to 150 gave inner (146.95 partiallyOpen).

### (iii) Stepped down from open

Result: stepping down from open, the inner screen stays lit down to 16 commanded (text only) and goes dark at 15 commanded (19.37 reported, closed).

Run (open, then 150, 120, 90, 60, 40, 30, then 29, 28 ... 15):

| Commanded | Lit screen | Reported |
|---|---|---|
| 150, 120, 90, 60, 40 | inner (text only) | not read |
| 30 | inner | 33.55 partiallyOpen |
| 29 to 26 | inner (text only) | not read |
| 25 | inner | 28.81 partiallyOpen |
| 24 to 21 | inner (text only) | not read |
| 20 | inner | 24.09 partiallyOpen |
| 19 to 17 | inner (text only) | not read |
| 16 | inner (text only) | not read |
| 15 | outer | 19.37 closed |

Earlier descending run (open, 130, 120, 110, 100, 90, 70, 50, 30, 10): inner (text only) at 130, 120, 110, 100; 90 inner (90.21 partiallyOpen); 70 inner (71.31 partiallyOpen); 50 and 30 inner (text only); 10 outer (text only).

### (iv) Jump down from open

Result: a jump from open down to 30, 29, 28, 27 or 20 goes dark; a jump from open to 110 stays lit.

| Commanded | Lit screen | Reported |
|---|---|---|
| 30 | outer | 33.61 closed |
| 29, 28, 27 | outer (text only) | not read |
| 26 to 21 | not measured | not measured |
| 20 | outer | 24.37 closed |
| 110 (from open) | inner | 109.02 partiallyOpen (several runs) |

Open then 20 (a separate earlier run) was also outer, text only.

### Other single readings

| Path | Commanded | Lit screen | Reported |
|---|---|---|---|
| jump up from 15 (outer lit), then back to 15, then jump up again | 130, then 120 | inner at both (130 text only) | 120: 118.62 partiallyOpen |
| steps down from 50 to 30 to 10 (20 degree steps) | 10 | outer (text only) | not read |
| inner screen, portrait orientation | 120 (from 15) | inner 669x951, view 669x835 | 118.62 partiallyOpen, orientation "portrait" |


The reported angle is not the commanded angle: +4.17 at 20, +2.78 at 45, +1.39 at 70, -0.04 at 90, -1.15 at 110, -3.05 at 150, -4.16 at 170 (first sweep). The dial must use the reported angle.

## Decisions

1. **End angles.** The end angles stay at 70 and 150 by controller decision. Reason, from the tables: with the hinge stepped down from open, the inner screen is lit at 150, 120, 110 and 100 (all text only), 90 (90.21 partiallyOpen) and 70 (71.31 partiallyOpen), and down to 16 (text only); so 70 to 150 is covered on that path. A jump from open to 110 is also lit (109.02 partiallyOpen). It is not covered on a jump from closed to 70, 75, 80, 82, 83 or 84 (outer; 85 lit at 85.56 partiallyOpen). Stepping up from closed, the angle at which the inner screen lights depends on the step size: with 10 degree steps the first lit command was 170 (165.84 partiallyOpen; 160 was outer at 156.07 closed); with 1 degree steps after 160 it was 172 (text only); and in the first sweep a single 40 degree step from 110 lit the screen at 150 (146.95 partiallyOpen). So no single rising threshold exists in these measurements. A jump from open to 30, 29, 28, 27 or 20 is dark (30 reads 33.61 closed, 20 reads 24.37 closed). Consequence: when opening from closed the lit angle depends on how large the step is; with 10 degree steps from closed nothing from 70 to 150 was lit (text only at every angle except 160, which is not in that range, so all of 70 to 150 is text only); with 1 degree steps only 85 to 120 was measured (the earlier run, which began with a 25 degree step) and it stayed outer, while 121 to 150 was not measured in 1 degree steps; and with the 40 degree step 150 was lit. Rule for later tasks: to reach any angle between 70 and 150 with the inner screen lit, set `open` first and then move to the angle, staying at or above 20 (stepped down from open, 20 is lit at 24.09 partiallyOpen and 15 is dark at 19.37 closed). Jumping from open to 30 or 20 is dark, so move there in steps. A jump from open to 70 or to 150 was not measured on its own; 70 and 150 were reached lit by steps. App rule, not a measurement: the app treats status `.closed` as closed and silent.
2. **Fold direction.** Lock the app to **portrait**. The inner screen is 951x669 pt in its default landscape orientation, which is two 466x678 outer-size panels side by side with a vertical fold. Rotating a quarter turn left gives 669x951 pt, the probe reports interface orientation "portrait", and the two panels are then stacked, so the fold runs left to right across the middle of the app. Evidence is the screen geometry; the simulator draws no fold line, so this was not seen directly.
3. **Reading quality.** A reading arrives before the hinge first moves: 1 update at launch, reporting 0.00 closed (and 118.62 partiallyOpen when launched with the hinge already at that angle). Direct test with the inner screen lit, from open then 110: setting 110, 109, 108 ... 100 in 1 degree steps gave a reading each time, so 10 of 10 steps produced a new reading (109 to 100; 110 itself is the start). Readings: 110 gave 109.02, then 108.05, 107.10, 106.16, 105.21, 104.17, 103.22, 102.28, 101.33, 100.39, 99.44 (the last is commanded 100). Differences between consecutive readings: smallest 0.94, largest 1.04 degrees. Then 100.0, 100.25, 100.5, 100.75, 101.0 in that order: 99.44, 99.96, 99.96, 99.96, 99.96; only 100.25 gave a new reading (a 0.52 degree change); the 100.5, 100.75 and 101.0 steps (rising) gave none. The tool's result text rounded the commanded angles to 100.3 and 100.8, so the quarter degree steps were not exact. Result by this test: readings arrive at about 1 degree in a descending run, which is finer than 1.5 degrees, so no "tune with the debug slider" is needed. Caveat: after reversing direction, rising 100 to 101 in 0.25 degree steps gave one new reading, 99.96, and then nothing, while the same commanded 101 reached while descending read 100.39; the reading lags by about 0.4 degrees after a reversal. Simulator only; real hardware not measured.
