# Design Review: Hinge Radio

Date: 2026-11-22. Status: awaiting the owner's direction. Reviewed against the build on commit `dfe01eb`, from the code and the screenshots in `docs/check/`. The owner has used it on a real iPhone Duo; Claude has only seen the simulator.

The owner's two asks, in their words: "when playing, and closed, show the standby version - same as what would be in tent mode" and "we do need to win apple design award - so we need ot think more on the ux".

An honest note first. Nobody can promise an award. What a review can do is find where this app is already distinctive, where it would be marked down, and what to build so it is strong on every criterion and exceptional on two.

## Design thesis

**One radio that changes shape with the phone: fold it and it becomes a different instrument, and the music never stops.**

The feeling is a well-made object on a table, calm and tactile. The differentiator is that the fold is the interface. Every pose is a deliberate face of the same radio, and moving between them is continuous, like turning an object over in your hands.

## Where it stands today

The idea is strong and already unusual: real local stations at their true frequencies, static between them, a tape you drag, and a different face for each way the Duo can sit. The palette and type are restrained and consistent. The sound design (static, whistle, click) is a real asset.

The core problem is that the poses are **states, not a journey**. Changing pose swaps one screen for another with no motion connecting them. Two poses are dead ends: flat says "Fold me" and shut says "Closed". And the app is built for one kind of user: fixed type sizes, light mode forced, one gesture-only control, and almost no VoiceOver support outside the tape.

## Apple Design Award scorecard

| Criterion | Today | Biggest opportunity |
|---|---|---|
| **Innovation** | Strong. The fold deciding the face is new. | Make the fold feel continuous, and use the system: Now Playing, lock screen and background audio. |
| **Interaction** | Promising. The tape is direct and has detents. | Next and previous buttons beside the tape; physical ends (rubber-banding); a click for every station passed. |
| **Delight and Fun** | Some. Static and the lock click. | A signature moment (below). Today nothing makes you show a friend. |
| **Visuals and Graphics** | Good bones, plain finish. | A night face; a standby face with life in it; designed empty and error states. |
| **Inclusivity** | A liability. | Text that grows with the system setting, a dark face, Reduce Motion, VoiceOver on every screen, colour never the only signal. |
| **Social Impact** | Latent. It plays public, college and community radio. | Say so on the face: show what kind of station this is. |

Plan: be exceptional on **Innovation** and **Interaction**, and lift **Inclusivity** from liability to strength.

## What the owner asked for directly

**Closed while playing shows standby, like tent.** The radio keeps playing when the phone is closed, and the outer screen shows the standby face. Closed and switched off shows the same face in its "Off" state, so the "Closed" card goes away. **(my call on the off case.)**

This reverses the current rule that closing silences the radio. Two consequences to know:

- **It can play in a pocket.** That is how every music app behaves, and the power button is on the standby face.
- **On a real phone it only works properly with background audio.** Without it, locking the phone or switching apps still silences the radio. So this belongs with the system integration below.

## Proposed direction

**Colour.** Keep the cream face, dark ink and single orange accent. Add a deliberate **night face**: near-black ground, warm off-white ink, the same orange, a dimmer lamp. Follow the system's light and dark setting. Standby at a bedside is the case that needs it most.

**Type.** Keep the system font. Sizes stay tied to the screen, but multiply by the user's text-size setting, with layouts that reflow instead of clipping. Standby is already large; the flex face is where this matters.

**Motion.** One principle: *the radio is one object*. The station name, frequency, lamp and power button are the same four things in every pose, so they should travel between poses, not blink. With Reduce Motion on, they cross-fade.

**Depth.** Keep it flat and printed. No new shadows or glass.

**Sound and touch.** Every station the tape passes gets its click and tick, including on a long flick. The ends of the band resist and spring back.

## The signature moment

**The fold.** You are tuning in flex. You pick the phone up and stand it like a book, or close it, and the station name and frequency glide and grow into the standby face while the music plays on. Open it again and they glide back onto the dial and the tape.

No other phone can do this, it is the app's whole idea made visible, and it costs nothing to the user to discover: they just move the phone. It is worth disproportionate effort.

A second, smaller moment: **tuning in**. As the tape settles, the hatched static on it clears outward from the pointer, the lamp warms from orange to green, and the name arrives. Today these happen, but as three separate snaps.

## Prioritized changes

### Foundations (lift every screen)

1. **Closed plays and shows standby** (the owner's ask). Small.
2. **Background audio, Now Playing and lock-screen controls.** Makes closed, locked and other-app listening real. Medium. Reverses an earlier non-goal.
3. **Night face, following the system.** Medium.
4. **Text that scales with the system setting.** Medium.
5. **VoiceOver on every face**: grouped, labelled, with station changes announced. Small.
6. **Reduce Motion and Increase Contrast honoured.** Small.

### Signature

7. **The fold transition** between flex, book, tent and closed. Large.
8. **The tuning-in moment** on the tape. Medium.

### Polish

9. **Next and previous station buttons** beside the tape, so no one needs the gesture. Small.
10. **Standby with life**: a quiet level meter driven by the real audio, and the time. Medium.
11. **Flat is no longer a dead end.** Show the whole dial across the big screen with the station playing, and a gentle folding hint. Medium. Softens "flex only".
12. **Designed states**: no network, "No signal", first run (a one-time nudge that the tape slides). Medium.
13. **What kind of station** (public, college, community, commercial) under the name. Small, needs a field in the station list.
14. **Tape physics**: rubber-band ends and a click per station on long flicks. Small.

### Later

- A StandBy widget and a Live Activity.
- More cities, or the listener's own city.
- Localisation.
- Favourites.

## Accessibility and cross-generational notes

Commitments, each to be checked on screen and not just in code:

- Largest text size: nothing clips or overlaps on any face.
- Light and night faces both meet 4.5:1 for body text.
- Every action has a visible control at least 44 pt across. The tape stays as the fast way, never the only way.
- The lamp's meaning is never colour alone: the line under the name already says "Tuning in" or "No signal".
- VoiceOver reads "KEXP, 90.3 megahertz, playing" as one thing.
- Reduce Motion keeps every function and drops the travel.

## Risks

- **Scope.** This is several times the work of the poses change. It should be built in stages, each one usable.
- **Stream rights.** A shipped app playing these streams needs the broadcasters' terms checked. An award entry is a shipped app.
- **Real-phone unknowns.** The fold transition depends on how fast and how smoothly a real Duo reports the hinge and switches screens. The simulator switched screens abruptly.
