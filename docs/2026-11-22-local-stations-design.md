# Hinge Radio: local stations anywhere in the US

Date: 2026-11-22. Status: approved by the owner on 2026-11-25.

Lines marked **(my call)** are Claude's and unconfirmed. The research behind this is in `.superpowers/sdd/2026-11-22-pocket-radio/cities-research.md` and `indie-apps-research.md` (local, not committed).

## What the owner asked

"explore how we bring in support for other cities in US - there should be an open directory or something right based on the location?" Then, on whether live data fetched on demand should work: "if its live data and fetched on demand, it should work right?" Then, choosing between doing the lookups on the phone or on a server they would run: **"On the phone"**. Then: "do a research how other indie radio apps handle this" (findings below).

## What other radio apps do

- **The open directory, Radio Browser, is the common source** for indie apps (RadioDroid, Transistor, Shortwave, Triode's search, Eter, Pladio). The big apps (TuneIn, myTuner, radio.net) run their own catalogues with broadcaster deals.
- **"Local" usually means the country**, from the phone's region, with no location permission. Pladio filters by location; the indie app RadioLand uses the FCC database and signal modelling to show what a real radio would receive, but plays nothing.
- **Nobody found joins FCC call signs and frequencies to streams.** Apps that know frequencies do not stream; apps that stream do not know frequencies. That is this app's opening, and its risk.
- **Dead streams are left to Radio Browser's daily check** plus user edits.
- **No iOS radio developer was found explaining how they handle `http` streams**; Android apps simply allow them.
- **App Review:** in 2026 developers report radio apps built on Radio Browser being rejected under guideline 5.2.3, with Apple asking for documentary evidence of rights to each stream. Approvals described came with written permission from each station. These are developers' accounts, not Apple policy, and review has been inconsistent.

## Goals

1. Wherever the phone is in the US, the radio can show that area's real FM stations at their true frequencies and play the ones that stream.
2. Everything happens on the phone. No server of ours.
3. The four bundled cities stay, and still work offline.

## Non-goals

- Places outside the US. AM. Stations that exist only online.
- Typing a city or ZIP code to tune somewhere else **(my call; can follow)**.
- Plain `http` streams for found stations (iOS blocks hosts not named in advance).
- An App Store release. Shipping would need permission from each broadcaster (guideline 5.2.3), and from iHeart and NPR for their lookups. Radio Browser does not remove that need.

## How it behaves

### The band switch

- **A fifth position, HERE**, after SEA, NYC, CHI, LA **(my call on the name)**.
- The first time HERE is chosen, iOS asks for location while using the app. **Approximate location is enough** (a 60 km radius), so the app asks for approximate only **(my call)**.
- The city name on the dial becomes the nearest town, from the phone's own place lookup.

### Finding the stations

1. **The dial: the FCC.** A radius search around the phone (about 100 km) returns every licensed FM station with call sign, frequency, class, city and distance. Keep full-power licensed stations, one row per call sign, and only those whose **class reach covers the phone** (from the FCC's reference distance for each class, for example class A about 28 km, class B about 52 km, class C about 92 km), so the dial matches what a real radio there would pick up rather than a flat circle. At most 16, nearest first **(my call: nearest)**.
2. **A stream for each station**, trying in order and stopping at the first secure (`https`) stream:
   - iHeart, by call sign;
   - NPR's station finder, by call sign, for public radio;
   - Radio Browser, the open directory, only when the entry's name contains both the call sign and the frequency **(my call: strict, so a wrong station is never put on the dial)**, and only entries its own daily check marks as working and secure (`lastcheckok`, `is_https`, no SSL error). Its servers are found the way it asks (a DNS lookup of `all.api.radio-browser.info`), and a play is reported to its click counter, as its terms request.
3. **Each stream is tried quietly** on the phone. Only stations that answer go on the dial. Stations with no stream are left off, as now. **Secure streams only**: no iOS radio app in the research documents a better answer for `http`.
4. The search radius and source order are named settings, so they can be tuned.

### While it searches (the signature moment)

- The lamps stay as they are; the line under the name reads "Finding stations…".
- **The needle sweeps slowly up the dial, and each station's dot appears as it is confirmed**, like an old radio's scan **(my call)**. Ticks follow the sweep. With Reduce Motion, the dots appear without the sweep.
- First search for a place takes a few seconds; the cache makes the next visit instant.

### Cache and failures

- Each place's dial is kept on the phone for 7 days, keyed to a grid of about 10 km **(my call)**. A cached dial shows at once and refreshes quietly in the background.
- No network and no cache: "No stations found here", and the band switch still reaches the four cities.
- Location refused: "Location is off" with no dial, and the other bands work.
- A source that fails or is slow (8 s) is skipped; the others still run.

### Privacy

- The phone's position, rounded to about 1 km **(my call)**, is sent to the FCC, NPR and Radio Browser to search. iHeart gets only call signs.
- Nothing is stored off the phone. The location prompt says why it is needed.

## How it is made

- **Rules in `RadioCore`, tested with saved real responses**: reading the FCC rows, filtering and choosing the 16, converting the point to the FCC's degrees-minutes-seconds form, reading each stream source's answer, the strict name match, choosing the first secure stream, and the cache key.
- **The app**: a station finder that does the network calls with timeouts and a plain app User-Agent, a quick stream check, the on-disk cache, location, and the HERE position.
- The bundled `Stations.json` and the station builder stay as they are.
- **One build setting switches HERE off**, so a build for review or a competition can ship only the four bundled cities **(my call)**. iHeart and NPR sit behind the same setting.
- **An "About the dial" card** (a long press on the HINGE RADIO title) names where the stations and streams come from: the FCC, iHeart, NPR, Radio Browser **(my call)**.

## How we will know it works

- Unit tests over saved FCC, iHeart, NPR and Radio Browser responses.
- On the Duo simulator with its location set to Seattle, HERE builds a dial whose stations overlap the bundled Seattle list and play. Then Fargo, a small market. Then a second visit to Seattle is instant.
- Location refused, and network off, each show their message and the four cities still play.
- The owner tries HERE where they are.

## Risks

1. **Stream rights.** App Review asks radio apps for evidence of rights to each stream (5.2.3). Live discovery cannot produce that; the switch above keeps a shippable build possible, and the four bundled cities would need permission emails on file.
2. **Undocumented sources** (iHeart, NPR without a key, the FCC's `transition` host) can change or disappear. NPR's current terms could not be read and may require a key. The cache and the four bundled cities soften it.
3. **Coverage.** Strict matching and `https`-only will leave some real stations off, mostly independents that publish only an `http` stream.
4. **Radio Browser has one server** at the moment.
5. **First search is slow** on a poor connection.
