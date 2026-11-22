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

Observed: which screen is lit and the status depend on the direction of travel. Going up from closed, the outer screen stays lit and status stays `closed` through 110, and status stays `closed` the whole way (71.39 to 108.85 reported). The inner screen first lights at some angle in (110, 120]. Going down from open, the inner screen stays lit and status stays `partiallyOpen` down to 30, and goes dark in (20, 30]. Only whole-degree postures were tried, so those thresholds are bracketed to 10 degrees, not pinned.

The reported angle is not the commanded angle: +4.17 at 20, +2.78 at 45, +1.39 at 70, -0.04 at 90, -1.15 at 110, -3.05 at 150, -4.16 at 170. The dial must use the reported angle.

## Decisions

1. **End angles.** The brief's rule is "keep 70 and 150 unless the inner screen is dark at either". At 150 the inner screen is lit (146.95, partiallyOpen). At 70 it is dark when the hinge opens from closed: the outer screen stays lit through 110 and the inner screen first lights between 110 and 120 on the way up. It is lit at 70 only when arriving from the open side. So by the rule the low end moves to the nearest angle at which the inner screen is lit when opening: **120** (lit, 118.62 reported). Dial range by the rule: **120 to 150**. Caveat for the controller: that is only 30 degrees, and a user closing the hinge keeps the inner screen lit down to about 30. The threshold was bracketed to 110-120 only; 111-119 were not tried. Not measured: any hysteresis effect from other approach speeds (the simulator sets angles instantly).
2. **Fold direction.** Lock the app to **portrait**. The inner screen is 951x669 pt in its default landscape orientation, which is two 466x678 outer-size panels side by side with a vertical fold. Rotating a quarter turn left gives 669x951 pt, the probe reports interface orientation "portrait", and the two panels are then stacked, so the fold runs left to right across the middle of the app. Evidence is the screen geometry; the simulator draws no fold line, so this was not seen directly.
3. **Reading quality.** A reading arrives before the hinge first moves: 1 update at launch, reporting 0.00 closed (and 118.62 partiallyOpen when launched with the hinge already at that angle). The smallest change that produced a new reading was 0.48 degrees (set 70 to 70.5: 71.39 to 71.87), but one 0.5 degree step later gave no reading (100 to 100.5) and 70.5 to 71 gave none. Steps that did register: 1.13 degrees (99.54 to 100.67, set 100 to 101), 0.48 degrees. Moving 20 degrees produced about 16 to 20 updates, so readings come roughly every 1 to 1.25 degrees. This is finer than 1.5 degrees, so no "tune with the debug slider" is needed. Simulator only; real hardware not measured.
