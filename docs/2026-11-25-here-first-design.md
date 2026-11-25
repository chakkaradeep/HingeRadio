# Hinge Radio: HERE first, remembered, and its search rules under test

Date: 2026-11-25. Status: approved in advance. The owner asked: "see if you can design the better selection of Here vs cities - just do what you recomenmd", and to put HERE's search rules under automatic tests (ruling H16 of the local stations build). The owner is away; every choice below is Claude's.

## Why

HERE is the radio's point: the stations where you are. Today it is the last of five equal positions, after four cities you may never visit, and the radio forgets it on every launch, so someone who lives on HERE has to choose it again each time.

## Approaches

- **A. HERE first, set apart, and remembered (chosen).** HERE is the switch's first position; a printed divider separates it from the cities, which follow as before. The radio reopens on the band and needle position it was left on. Small, keeps one control, reads like a real radio's LOCAL setting.
- **B. A separate LOCAL / CITIES switch.** Two controls where one does; more to learn and to fit on the plate.
- **C. HERE replaces the bundled city you are in.** Clever, but the band switch would change under you, and the bundled cities would come and go.

## What changes

1. **Order.** HERE is the first position, then SEA, NYC, CHI, LA. A thin printed rule sits between HERE and SEA on the switch. VoiceOver order follows.
2. **Remembered.** The band and the needle position are saved when they change and restored at launch. Power and volume are not: the radio still opens switched off, so it never blares. A saved band that no longer exists (HERE in a build without it) falls back to the first city.
3. **First launch** stays on Seattle with the needle settled, so nobody is asked for location before choosing HERE.
4. **Opening on HERE** behaves exactly like choosing HERE: the kept dial shows at once and a search runs only when it is due. With location off it says "Location is off", as now.
5. **Search rules under test.** The decisions in `App/Here/HereSearch.swift` and the taken-needle rule in `RadioModel` (when to search on choosing and returning, what cancelling clears, which kept dial counts as here, what a missing fix shows, hunt or show or refresh, when a refresh may replace a dial, whether a return may move the needle) move into a value type in `RadioCore` with tests. `HereSearch` keeps only the waiting and the calls. No behaviour changes.

## Not changing

The four bundled cities, the HERE search itself, the scan, the faces.

## How we will know

Tests for every moved rule and for the order and restore rules; on the simulator, a launch after leaving HERE opens on HERE with its dial in well under a second, and a launch after leaving Chicago at a station opens there, switched off, needle on the station; the switch screenshot shows HERE first with its divider.
