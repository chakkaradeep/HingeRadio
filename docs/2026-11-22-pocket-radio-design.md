# Hinge Radio: the pocket radio face

Date: 2026-11-22. Status: built from the owner's direction given piece by piece on 2026-11-22; lines marked **(my call)** are Claude's and unconfirmed.

Amends `docs/2026-11-22-hinge-radio-poses-design.md`. Where they disagree this wins. It is stage one of `docs/2026-11-22-design-review.md`.

## What the owner said

- "when playing, and closed, show the standby version - same as what would be in tent mode"
- "i like nostalgia, radio tuner could resemble how we tune radio on the side tuner - need like a real on button that you get in old pocket radios"
- On whether the wheel replaces the tape: "yes, replace - i need to be exactly like a pocket radio"
- "power on should also be on the side"

## Goals

1. **The flex face is a pocket radio.** Dial on the top half; on the lower half a speaker grille, a band switch, and two wheels at the right edge.
2. **A tuning wheel on the side** replaces the tape. Roll up for higher stations. A tick at each station, a firm stop at each end.
3. **Power is on the side too.** **(my call on the form)** It is the classic volume wheel that clicks on: roll it up past a click and the radio is on; keep rolling and it gets louder; roll it down past the click and it is off. A tap on it also switches on or off.
4. **Closed keeps playing and shows the standby face**, the same as tent. Closed and off shows that face in its "Off" state. The "Closed" card is gone.
5. Book, tent and flat are unchanged, except that the standby face's power button is replaced by a tappable on/off switch drawn in the same printed style **(my call)**.
   Later the same day (task 4) the owner asked for the side knobs in the other poses too: the standby face's on/off switch was replaced by the same side wheels as the flex plate, volume (also power) above tuning, on book, tent and shut. Flat keeps its card.

## Non-goals

- Background audio, Now Playing and lock-screen controls. Without them, locking the phone or leaving the app still silences the radio. That is stage two of the review.
- A telescoping antenna or other decoration that does nothing.
- The night face, text scaling and the fold transition (later stages).

## How it behaves

### Top half

- The dial as now: scale, station dots, orange needle.
- **A "tuned" lamp** replaces the signal bars and the green lamp **(my call)**: off when the radio is off or on static, orange while tuning in, lit steadily when the station is playing. The word under the station name still says the same thing, so the lamp is never the only signal.
- The station name and the line under it stay **(my call)**.

### Lower half

```
+------------------------------------------------+
|                                    VOLUME   ]|| |  small wheel: off / on / louder
|   : : : : : : : : :                OFF . ON ]|| |
|   : : : : : : : : :                             |
|   : : : : : : : : :     BAND                ]||||
|   : : : : : : : : :     [#| | | ]           ]|||| large wheel: tuning
|   : : : : : : : : :     SEA NYC CHI LA      ]||||
|                                    TUNING   ]||||
+------------------------------------------------+
```

- **Speaker grille**: a field of round holes, the largest thing on the plate.
- **Band switch** **(my call)**: a four-position slider for the four cities, replacing the keys. Each position can be tapped. Changing band keeps the needle's place.
- **Tuning wheel**: tall, ridged, half-hidden at the right edge. Dragging up or down rolls it; the ridges move with the finger. One full height of the wheel is about a quarter of the band **(my call)**. The snap, the flick and the rule that a slow release settles on the station all carry over from the tape, turned on end.
- **Volume wheel**: smaller, above the tuning wheel, with "OFF" and "ON" printed beside it and a dot that shows how far it is turned.
- The frequency readout stays on the top half only **(my call)**.

### Volume

- The wheel's travel is 0 to 1. Below 0.15 the radio is off. From 0.15 to 1 it is on, and loudness rises from quiet to full.
- Crossing 0.15 in either direction gives a click and a tick.
- The loudness applies to the station and the static alike. The phone's own volume buttons still work on top of it.
- At launch the wheel is at off.

### Closed

- The outer screen shows the standby face whenever the app is on it, whatever the hinge angle.
- Sound follows power alone. No pose silences the radio.

## Failure lines

- A wheel that cannot be rolled with a thumb at the screen edge without triggering the system's edge gestures.
- Either wheel being the only way to do its job. Tapping the volume wheel toggles power; VoiceOver can step stations and volume.
- Labels too small to read: nothing under 13 pt.

## Risks

- **The right edge.** iOS claims swipes that start within a few points of the screen edge. The wheels sit inside the plate's padding, not at the glass edge.
- **Playing while closed** can now happen in a pocket.
- **Two wheels close together** may be mis-touched. They are separated by at least 44 pt.
