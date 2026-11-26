# Flat: the Tall dial

Fully open, the iPhone Duo shows "Fold me" and nothing else, so a radio that is playing cannot even be turned down without folding. This makes flat a pose in its own right: a radio whose dial runs straight across the fold, the one pose where the fold lies flat enough to draw across.

Tried as a throwaway on CDuo (branch `spike/flat-tall-dial`) and approved by the owner on 2026-11-26.

## Goals

- Flat is a whole radio: station, frequency, lamps, speaker, band switch, and the same volume and tuning wheels as every other face.
- Every station on the dial carries its call sign, readable at a glance.
- Works upright and on its side.

## Non-goals

- Tuning by dragging the dial. The owner chose the tuning wheel, which already has its feel, sound and VoiceOver.
- Dynamic Type. Every face sizes its text from the screen's width; flat does the same.

## Anti-goals

- Names that overlap, are cut off, or sit in two rows away from their dots. That was the first try on its side, and it read as a duplicate list.

## Approaches considered

Drawn as mockups (artifact "Hinge Radio Flat Faces", versions 1 to 3):

1. **Same radio**: the half-open face, unchanged. Least work; flat would feel like no pose at all.
2. **Tall dial** (chosen): the dial the full length of the screen, across the fold, each dot named.
3. **Across the room**: a big name and frequency with the standby wheels; no dial.
4. **Fold me, with volume**: today's card plus a volume wheel; still asks people to fold.

Within the Tall dial, on its side, names first went in two staggered rows, which read badly. The owner asked for the dial to extend for crowded stations instead: **the tape** below.

## Design

### Layout (as approved on CDuo)

- **Upright**: the dial on the left, a third of the width, the whole height; 88 at the bottom. On the right, top to bottom: the badge, the band (location arrow and town on HERE), the station's name (up to two lines) with its line right under it, the frequency, the lamps, the speaker beside the volume and tuning wheels, and the band switch.
- **On its side**: the badge and the band, then the dial along the full width; 88 on the left. Under it, left of the fold: the name and its line, the speaker, the band switch. Right of it: the frequency over the lamps, and the wheels at the edge. Each half keeps clear of the fold, as the book face does.
- Switched off, the dial and the frequency dim, and the name area stays empty but keeps its height, as on the half-open window.
- The frequency never wraps: 107.1 shrinks to fit.

### The tape

- Each station needs room along the dial: upright, its line height; on its side, its name's width plus a gap.
- Between two neighbours the dial keeps the band's own spacing, or the room their names need, whichever is more. The dial's length is the sum.
- If it fits the glass, it stands still and the needle moves, as on the half-open dial. Upright this is always the case with 16 stations.
- If it is longer, it slides under a needle held in the middle (on its side, the fold), and stops at either end so the needle can reach 88 and 108. Where it goes on past the glass, the edge fades out.
- The station tuned in has an orange dot and name; a dead station's are faded and struck through, as on the half-open dial.
- The tape's arithmetic (positions, rooms, glass length → where each position falls, how far the tape has slid) goes in RadioCore as a value type with tests. The app only measures the names and draws.

### The rest

- **VoiceOver**: the dial is a picture, as the half-open dial's is; the name, frequency, lamps, band switch and wheels speak, as they do elsewhere.
- **About the dial**: a long press on the badge, or its VoiceOver action, opens the About card in flat as in flex.
- **Radio.display** no longer replaces the station with "Fold me" in flat.
- **PoseCard** goes: flat on the outer screen cannot happen (the outer screen always reads as tent).
- **Drawing cost**: names are measured once per band and size, not on every frame of a turn.
- **README**: the poses table, the Flat section and the check steps describe the new face; new screenshots go in `docs/check/`.

## Left to the builder

- Exact sizes and gaps, kept to what was approved on CDuo.
- Whether the tape's offset eases or follows the needle exactly (it follows today, and the needle itself glides).
- The checking aid used in the spike (drawing the face off screen into the app's Documents) is not shipped.
