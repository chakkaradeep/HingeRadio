# Hinge Radio: script badge, grille on every face, and no repeated frequency

Date: 2026-11-25. Status: approved by the owner on 2026-11-25. A small change.

Lines marked **(my call)** are Claude's and unconfirmed.

## What the owner asked

"the cover screen and standby - we could probably use a good logo and radio themed lettering , call our name and place it - otherwise it looks very plain". Shown three directions, the owner chose: **"Script badge, but why do we have two times 94.7 station displayed?"**

## Approaches

- **A. Script badge (chosen).** A maker's badge from a 1950s or 60s pocket radio. Most nostalgic; the bare script H is the weakest of the three as an app icon.
- **B. Dial plate.** Wide hi-fi capitals on a dark plate. Strong icon, more serious, competes with the station name.
- **C. Open fold.** Deco lettering and an opening phone with signal arcs. Friendly, but arcs are a common radio symbol.

## The badge

- "Hinge" in a flowing script, underlined by a line that ends in the orange tuning needle, with RADIO in small spaced capitals.
- Drawn as a vector shape, so no font ships in the app. The lettering starts from an open-licence script whose licence is checked first, and is adjusted so it is our own: Yellowtail (Astigmatic, Apache 2.0; its licence text ships in the app), with a round station dot for the i, a hand-drawn RADIO, and an underline that parts around the g.
- It sits low on the closed, tent and book faces, like a maker's plate, and stays visible when the radio is off **(my call)**. On flex it replaces the plain HINGE RADIO at the top left **(my call)**.
- VoiceOver skips it on standby, and reads "Hinge Radio" once on flex, as now **(my call)**.
- App icon: the script H over the underline and needle, cream on dark. The app has no icon today **(my call)**.

## The grille

- Closed, tent and book get the flex face's speaker grille in their empty space **(my call)**. Book: below the lamps on the left panel. Closed and tent on its long side: a tall strip beside the frequency. Upright: between the lamps and the frequency.
- It keeps clear of the fold, the camera corner and the widest reading, "100.0". It is the same size whatever the name, so it does not change as you tune.
- The flat card ("Fold me") shows the badge in place of the plain name **(my call)**.

## The repeated frequency

94.7 shows twice because the station's own name in the list is "94.7 WLS", and the radio also shows the frequency. 7 of the 55 stations do this: 102.5 KZOK, WBGO Jazz 88.3, 94.7 WLS, 103.5 KISS FM, LAist 89.3, Real 92.3, 102.7 KIIS FM.

- **Rule (my call):** when a name contains the station's exact frequency, the radio shows the name without it: KZOK, WBGO Jazz, WLS, KISS FM, LAist, Real, KIIS FM.
- Names with a nickname number stay whole, because the number is the brand: Hot 97, Z100, Power 106.
- If removing it would leave nothing, the call sign shows.
- The rule lives in `RadioCore`, so every face, VoiceOver and the later HERE band follow it. `Stations.json` keeps the full names.
- The station name and frequency keep their current typeface, so they read from across a room.

## Non-goals

- A night face, new colours, or animating the badge.

## How we will know it works

- Unit tests for the seven names, the three nicknames and the nothing-left case.
- Screenshots on the Duo simulator of flex, book, closed, tent and upright, on and off, with the longest name and with 100.3.
- The owner sees it on their Duo.
