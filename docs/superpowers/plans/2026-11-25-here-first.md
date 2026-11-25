# HERE First Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** HERE's search rules move into tested RadioCore code, then HERE becomes the first, remembered band.

**Architecture:** A pure decision type in RadioCore drives `HereSearch`; band order lives in `Radio`; persistence is a small app-side store.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, UserDefaults.

**Spec:** `docs/2026-11-25-here-first-design.md`

## Global Constraints

- No behaviour change in Task 1. Earlier rulings H1 to H16 in the local stations build still hold (cancel on background only; currency checks after every wait; a background refresh never touches the dial being listened to; under half never replaces; thin dial refreshes after 10 minutes; town-only update keeps the lock; choosing HERE again revives dead stations; return keeps a taken needle; cancel clears only a partial dial).
- RadioCore does no I/O. No new dependencies. Position never logged or stored outside the HERE cache.
- Launch stays switched off. First launch on the first bundled city.
- Simulator 6FBE2E12-829F-4E36-AACD-4F03F4E0638E only, muted. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No pushing.

## Review Focus

1. A saved band that is not in this build (HERE in the HERE-off build) or a saved position that is not a number.
2. Launching on HERE with location refused, or with no network and a kept dial.
3. A launch on HERE must not sweep over a kept dial or prompt before the window shows.
4. VoiceOver order and the switch's tap areas with the divider.
5. The extracted rules must give exactly today's answers (the old and new code side by side in review).

---

### Task 1: HERE's search rules in RadioCore

**Files:** Create `Packages/RadioCore/Sources/RadioCore/HerePlan.swift`, `Tests/RadioCoreTests/HerePlanTests.swift`. Modify `App/Here/HereSearch.swift`, `App/RadioModel.swift` (the taken-needle rule only).

- [ ] **Step 1:** Name every decision `HereSearch` and the model's HERE hooks make today and write a failing test for each: search on choosing only if none runs; on return only if the last was cut short or the status is locationOff or empty; cancelling clears the stations only while finding, and marks the search cut short only if one ran; which place a fix counts as (within one cell of the last place with a kept dial, else its own); a missing fix shows the last place's kept dial when unavailable, else locationOff or empty; a kept dial is shown and named if unnamed and refreshed if due, otherwise a hunt; a hunt's empty result gives empty and saves nothing, a non-empty one saves at once with the unnamed town; a refresh saves only if the dial may be replaced; a return keeps a taken needle, a choice resets it.
- [ ] **Step 2:** Implement them as a value type (or pure functions) in `HerePlan.swift`; `HereSearch` and `RadioModel` call it and keep only the awaiting, the cancelling and the calls to the locator, finder, cache and model.
- [ ] **Step 3:** `swift test`; both app builds; on the simulator, Seattle from an empty cache, a repeat visit, background mid-search, and Don't Allow behave as before (logs).
- [ ] **Step 4:** Commit `refactor: HERE's search rules move to RadioCore with tests`.

### Task 2: HERE first and remembered

**Files:** Modify `Packages/RadioCore/Sources/RadioCore/Radio.swift`, `App/RadioModel.swift`, `App/HingeRadioApp.swift`, `App/Views/BandSwitch.swift`; create `App/BandMemory.swift`; tests in `Tests/RadioCoreTests/HereTests.swift` or a new file.

- [ ] **Step 1: Failing tests**: with `here: true` HERE is first in `cities` and the radio still starts on the first bundled city; `Radio` can be started on a given band and position (an unknown band falls back to the first bundled city; a not-a-number or out-of-range position is clamped or ignored), settled on a locked station as at launch today, switched off.
- [ ] **Step 2: Implement.** Save band id and position in `UserDefaults` (keys `HingeRadioBand`, `HingeRadioPosition`) when they settle, not every frame; restore at launch; opening on HERE runs the same path as choosing it, after the window appears.
- [ ] **Step 3: Switch.** HERE first, a printed divider between HERE and the cities that never takes a tap from either; labels and VoiceOver in the new order.
- [ ] **Step 4: Verify** on the simulator: switch screenshot `docs/check/63-here-first.png`; relaunch after HERE opens on HERE with its kept dial and no sweep; relaunch after Chicago at a station opens there, off, needle on it; HERE-off build opens on the first city even when HERE was saved.
- [ ] **Step 5: Commit** `feat: HERE first and remembered`.
