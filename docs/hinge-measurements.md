# Hinge measurements

Device: iPhone Duo simulator (iOS 27.1, UDID 6FBE2E12-829F-4E36-AACD-4F03F4E0638E). Probe: `App/HingeProbeView.swift`, reading `onHingeChange`. All values below were read from probe screenshots taken after each `set_posture` call. Screenshots are 1398x2034 px for the outer screen and 2853x2007 px for the inner screen (landscape).

## Table: ascending sweep from closed

Each posture was set in turn, starting closed, rising. Updates is the probe's running counter.

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

## Extra readings (not in the requested list)

Lit screen from the `set_posture` result text; angle and status only where a screenshot was taken.

| Approach | Angle set | Angle reported | Status | Lit screen |
|---|---|---|---|---|
| descending from open | 90 | 90.21 | partiallyOpen | inner |
| descending from open | 70 | 71.31 | partiallyOpen | inner |
| descending from 70 | 50, 30 | not read | not read | inner |
| descending from 30 | 10 | not read | not read | outer |
| descending from open | 20 | not read | not read | outer |
| ascending from 15 | 130, 120 | 120: 118.62 | partiallyOpen | inner at 130 and 120 |
| ascending from closed | 110 | 108.85 | closed | outer |
| descending from open | 130, 120, 110, 100 | not read | not read | inner |
| inner screen, portrait | 118.62 | 118.62 | partiallyOpen | inner 669x951, view 669x835, orientation "portrait" |
| fine steps in portrait | 100 / 100.5 / 101 | 99.54 / 99.54 / 100.67 | partiallyOpen | inner |

Observed: which screen is lit, and the status, depend on how the hinge got to an angle, not on the angle alone. The same commanded angle gave different results depending on whether the hinge was jumped there in one `set_posture` call or reached in small steps (see "Screen thresholds" below for the pinned values). In the first ascending sweep above (small steps from closed), the outer screen stayed lit and status stayed `closed` through 110; the inner screen lit at 150.

The reported angle is not the commanded angle: +4.17 at 20, +2.78 at 45, +1.39 at 70, -0.04 at 90, -1.15 at 110, -3.05 at 150, -4.16 at 170. The dial must use the reported angle.

## Screen thresholds

Pinned to 1 degree on the same simulator. "Jump" means one `set_posture` call straight from closed or open. "Step" means a series of calls in 1 degree increments (or larger, as stated). "Reported" is the probe's angle and status from a screenshot taken after the call; "text only" means the lit screen comes from the `set_posture` result and no screenshot was taken at that angle.

**Rising, controller procedure (closed, then 111, 112 ... 120).** From closed the first command, 111, already lights the inner screen: reported 110.12, partiallyOpen, view 867x635 pt. So the first commanded angle at which the inner screen is lit is 111. The same posture is dark when reached by steps: after the first call, 112 to 120 were set in order and the probe showed 113.57 closed (at 115) and 118.29 closed (at 120), outer screen, with the hinge arriving from 110 by steps. The probe at 111 reached from 110 in a step also read 109.79 closed, outer.

**Rising, jumps from closed (to find where a jump lights the inner screen).**

| Commanded | Result | Reported |
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

So a jump from closed first lights the inner screen at 85 commanded (reported 85.56), and 84 does not. The same commanded 85, reached by a step from 84, stayed outer: 85.56 closed. Stepping from there to 110 stayed outer (108.85 closed).

**Falling, controller procedure (open, then 30, 29, 28 ... 20).** From open the first command, 30, is already dark: reported 33.61, closed, outer screen (view 382x644 pt). 29, 28, 27 and 20 were also dark (text only at 29, 28, 27; at 20 a screenshot showed 24.37 closed). 26 to 21 were not run in this sequence. There is no commanded angle at which the inner screen is lit in this sequence, so the last lit angle is not measured here; the first dark angle is 30.

**Falling by steps (open, 150, 120, 90, 60, 40, 30, then 29 down by 1 degree).** Inner screen lit all the way down to 16 commanded (text only at 16; screenshots at 30: 33.55 partiallyOpen; 25: 28.81 partiallyOpen; 20: 24.09 partiallyOpen). First dark at 15 commanded: reported 19.37, closed, outer screen (screenshot). Last lit 16 (not confirmed with a screenshot).

Summary: the thresholds are not a fixed angle. A jump from closed lights the inner screen at 85 and above; small steps from closed did not light it through 120 (the sweep from 110 up to 120 and the first sweep up to 110), but a jump from 15 to 120 or 130 did (text only for 130; 118.62 partiallyOpen at 120). A jump from open to 30 or 20 goes dark; steps from open stay lit down to 16 and go dark at 15.

## Decisions

1. **End angles.** The end angles are kept at 70 and 150 by controller ruling. Measured reason: the inner screen is lit from about 30 up to 180 once the hinge has been opened, and when opening from closed it stays dark below the rising threshold only while status is `.closed`, where the radio is silent anyway. A 30 degree sweep (120 to 150) cannot hold 16 stations 4.5 degrees apart, which needs 72 degrees. Consequence: when opening from closed, the inner screen lights only past the rising threshold, so stations below that angle are reached by opening past it and bending back.
2. **Fold direction.** Lock the app to **portrait**. The inner screen is 951x669 pt in its default landscape orientation, which is two 466x678 outer-size panels side by side with a vertical fold. Rotating a quarter turn left gives 669x951 pt, the probe reports interface orientation "portrait", and the two panels are then stacked, so the fold runs left to right across the middle of the app. Evidence is the screen geometry; the simulator draws no fold line, so this was not seen directly.
3. **Reading quality.** A reading arrives before the hinge first moves: 1 update at launch, reporting 0.00 closed (and 118.62 partiallyOpen when launched with the hinge already at that angle). The smallest change that produced a new reading was 0.48 degrees (set 70 to 70.5: 71.39 to 71.87), but one 0.5 degree step later gave no reading (100 to 100.5) and 70.5 to 71 gave none. Steps that did register: 1.13 degrees (99.54 to 100.67, set 100 to 101), 0.48 degrees. Moving 20 degrees produced about 16 to 20 updates, so readings come roughly every 1 to 1.25 degrees. This is finer than 1.5 degrees, so no "tune with the debug slider" is needed. Simulator only; real hardware not measured.
