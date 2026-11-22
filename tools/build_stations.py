#!/usr/bin/env python3
"""Builds App/Resources/Stations.json: real FCC FM frequencies paired with Radio Browser streams.

Usage:
    build_stations.py fetch                 download the FCC lists and the Radio Browser directory
    build_stations.py candidates <city>     show proposed stream pairings for a city
    build_stations.py build [--no-verify]   check streams and write the station file

Corrections files (tools/corrections/<city>.json): {"pick": [call signs], "stations": {call:
{"name", "stream", "exclude", "note"}}}, every key optional. "note" is free text recording why a
pairing was chosen; the build ignores it.

Downloaded data is untrusted: it is only ever parsed, never executed.
"""
import json
import math
import re
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

USER_AGENT = "HingeRadioPrototype/0.1"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache"
CORRECTIONS = ROOT / "tools" / "corrections"
OUTPUT = ROOT / "App" / "Resources" / "Stations.json"
MAX_PER_CITY = 16
MIN_PER_CITY = 8
FCC_URL = "https://transition.fcc.gov/fcc-bin/fmq?state={ST}&serv=FM&list=4&size=9"
RB_SERVERS_URL = "https://all.api.radio-browser.info/json/servers"
RB_FALLBACK = "de1.api.radio-browser.info"
RB_SEARCH = "/json/stations/search?countrycode=US&hidebroken=true&limit=100000"

# "radius" is in kilometres; raise a city's to 80 if it cannot reach 8 working stations.
CITIES = {
    "seattle": {"name": "Seattle", "key": "SEA", "lat": 47.6062, "lon": -122.3321,
                "states": ["WA"], "radius": 60},
    "new-york": {"name": "New York", "key": "NYC", "lat": 40.7128, "lon": -74.0060,
                 "states": ["NY", "NJ", "CT"], "radius": 60},
    "chicago": {"name": "Chicago", "key": "CHI", "lat": 41.8781, "lon": -87.6298,
                "states": ["IL", "IN"], "radius": 60},
    "los-angeles": {"name": "Los Angeles", "key": "LA", "lat": 34.0522, "lon": -118.2437,
                    "states": ["CA"], "radius": 60},
}
ALL_STATES = sorted({s for c in CITIES.values() for s in c["states"]})


# ---------------------------------------------------------------- parsing

def parse_fcc(text):
    """Parses FCC `fmq` pipe-separated lines; keeps licensed FM stations only."""
    rows = []
    for line in text.splitlines():
        f = line.split("|")
        if len(f) < 27 or f[3].strip() != "FM" or f[9].strip() != "LIC":
            continue
        try:
            freq = float(f[2].split()[0])
            lat = _dms(f[20], f[21], f[22], f[19].strip() == "S")
            lon = _dms(f[24], f[25], f[26], f[23].strip() == "W")
        except (ValueError, IndexError):
            continue
        rows.append({"call": f[1].strip(), "frequency": freq, "service": "FM",
                     "status": "LIC", "city": f[10].strip(), "state": f[11].strip(),
                     "lat": lat, "lon": lon})
    return rows


def _dms(deg, minutes, seconds, negative):
    value = float(deg) + float(minutes) / 60 + float(seconds) / 3600
    return -value if negative else value


def distance_km(a, b):
    """Great-circle (haversine) distance between two (lat, lon) points."""
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = (math.sin((lat2 - lat1) / 2) ** 2
         + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2)
    return 2 * 6371.0088 * math.asin(math.sqrt(h))


def base_call(call):
    """KEXP-FM -> KEXP; drops a -FM, -LP, -HD1... suffix."""
    return call.split("-")[0].upper()


# ---------------------------------------------------------------- pairing

def _near(a, b):
    return abs(a - b) < 0.05


def _frequencies(name):
    """Returns (fm_freqs, am_freqs) mentioned in a directory name."""
    fm = [float(m) for m in re.findall(r"(?<![\d.])(\d{2,3}\.\d)(?![\d])", name)
          if 87.0 <= float(m) <= 109.0]
    am = [int(m) for m in re.findall(r"(?<![\d.])(\d{3,4})(?![\d.])", name)
          if 530 <= int(m) <= 1700]
    return fm, am


def stream_candidates(station, directory):
    """Directory entries that plausibly are this station, best first."""
    word = re.compile(r"(?<![A-Za-z0-9])" + re.escape(base_call(station["call"]))
                      + r"(?![A-Za-z0-9])", re.IGNORECASE)
    found = []
    for item in directory:
        name = item.get("name") or ""
        if not item.get("url_resolved") or not word.search(name):
            continue
        fm, am = _frequencies(name)
        matches_fm = any(_near(f, station["frequency"]) for f in fm)
        if any(not _near(f, station["frequency"]) for f in fm):
            continue
        if am and not matches_fm:
            continue
        found.append(item)
    found.sort(key=lambda i: (-int(bool(i.get("lastcheckok"))),
                              0 if i["url_resolved"].startswith("https") else 1,
                              -int(i.get("clickcount") or 0)))
    return found


def is_playable_type(content_type, url):
    mime = content_type.split(";")[0].strip().lower()
    path = url.split("?")[0].lower()
    if path.endswith((".pls", ".m3u")):
        return False
    if mime in ("application/vnd.apple.mpegurl", "application/x-mpegurl"):
        return True
    return mime.startswith("audio/") and mime not in ("audio/x-scpls", "audio/x-mpegurl")


# ---------------------------------------------------------------- selection

def apply_corrections(candidates, corrections):
    """Applies a corrections file to proposals; returns the chosen stations sorted by frequency."""
    overrides = corrections.get("stations", {})

    def override_for(cand):
        return overrides.get(cand["call"]) or overrides.get(base_call(cand["call"])) or {}

    adjusted = []
    for cand in candidates:
        o = override_for(cand)
        if o.get("exclude"):
            continue
        cand = dict(cand)
        if "name" in o:
            cand["name"] = o["name"]
        if "stream" in o:
            cand["stream"] = o["stream"]
            cand.pop("stationuuid", None)
            cand.pop("homepage", None)
        adjusted.append(cand)

    picks = corrections.get("pick")
    if picks is None:
        chosen, taken = [], set()
        for cand in sorted((c for c in adjusted if c.get("stream")),
                           key=lambda c: -int(c.get("clickcount") or 0)):
            if len(chosen) == MAX_PER_CITY or cand["frequency"] in taken:
                continue
            chosen.append(cand)
            taken.add(cand["frequency"])
    else:
        if len(picks) > MAX_PER_CITY:
            raise ValueError("%d stations picked; the limit is %d" % (len(picks), MAX_PER_CITY))
        chosen = []
        for call in picks:
            match = [c for c in adjusted if c["call"] == call or c["call"] == call + "-FM"
                     or base_call(c["call"]) == base_call(call)]
            if not match:
                raise ValueError("picked %s but no such station was proposed" % call)
            if not match[0].get("stream"):
                raise ValueError("picked %s but it has no stream" % call)
            chosen.append(match[0])
        seen = {}
        for c in chosen:
            if c["frequency"] in seen:
                raise ValueError("%s and %s share %.1f" % (seen[c["frequency"]], c["call"],
                                                           c["frequency"]))
            seen[c["frequency"]] = c["call"]
    return sorted(chosen, key=lambda c: c["frequency"])


# ---------------------------------------------------------------- network

def _open(url, timeout):
    return urllib.request.urlopen(
        urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "*/*"}),
        timeout=timeout)


def check_stream(url, timeout=10.0):
    """True when the URL answers 200 with a playable content type and at least one byte."""
    try:
        with _open(url, timeout) as resp:
            if resp.status != 200:
                return False
            if not is_playable_type(resp.headers.get("Content-Type", ""), url):
                return False
            return len(resp.read(1)) >= 1
    except Exception:
        return False


def _download(url, timeout=120):
    try:
        with _open(url, timeout) as resp:
            return resp.read()
    except urllib.error.HTTPError as err:
        raise RuntimeError("%s -> HTTP %d" % (url, err.code)) from err
    except urllib.error.URLError as err:
        raise RuntimeError("%s -> %s" % (url, err.reason)) from err


def fetch():
    CACHE.mkdir(parents=True, exist_ok=True)
    for st in ALL_STATES:
        print("FCC %s ..." % st)
        (CACHE / ("fcc-%s.txt" % st)).write_bytes(_download(FCC_URL.format(ST=st)))
    try:
        servers = [s["name"] for s in json.loads(_download(RB_SERVERS_URL))]
    except (RuntimeError, ValueError, KeyError, TypeError):
        servers = []
    servers = servers[:3] + [RB_FALLBACK]
    last = None
    for host in servers:
        print("Radio Browser %s ..." % host)
        try:
            data = _download("https://%s%s" % (host, RB_SEARCH), timeout=300)
            json.loads(data)
        except (RuntimeError, ValueError, OSError) as err:
            last = err
            continue
        (CACHE / "radiobrowser.json").write_bytes(data)
        print("saved %d bytes" % len(data))
        return
    raise RuntimeError("no Radio Browser server answered: %s" % last)


# ---------------------------------------------------------------- city lists

def _load_cache():
    fcc = []
    for st in ALL_STATES:
        path = CACHE / ("fcc-%s.txt" % st)
        if not path.exists():
            raise FileNotFoundError("%s is missing; run `fetch` first" % path)
        fcc += parse_fcc(path.read_text(errors="replace"))
    path = CACHE / "radiobrowser.json"
    if not path.exists():
        raise FileNotFoundError("%s is missing; run `fetch` first" % path)
    return fcc, json.loads(path.read_text())


def city_stations(city, fcc):
    centre = (city["lat"], city["lon"])
    seen, out = set(), []
    for row in fcc:
        if row["state"] not in city["states"] or row["call"] in seen:
            continue
        if distance_km(centre, (row["lat"], row["lon"])) <= city["radius"]:
            seen.add(row["call"])
            out.append(row)
    return out


def proposals(city, fcc, directory):
    """One proposal per FCC station, with its best stream when there is one."""
    out = []
    for row in city_stations(city, fcc):
        found = stream_candidates(row, directory)
        top = found[0] if found else {}
        out.append({"call": row["call"], "frequency": row["frequency"], "city": row["city"],
                    "state": row["state"], "name": base_call(row["call"]),
                    "stream": top.get("url_resolved"), "stationuuid": top.get("stationuuid"),
                    "homepage": top.get("homepage"), "clickcount": int(top.get("clickcount") or 0),
                    "candidates": found})
    return sorted(out, key=lambda p: p["frequency"])


def load_corrections(city_id):
    path = CORRECTIONS / ("%s.json" % city_id)
    return json.loads(path.read_text()) if path.exists() else {}


def _station_json(cand, directory):
    if not cand.get("stationuuid"):
        match = next((d for d in directory if d.get("url_resolved") == cand["stream"]), {})
        cand = dict(cand, stationuuid=match.get("stationuuid"), homepage=match.get("homepage"))
    out = {"callSign": cand["call"], "name": cand["name"], "licenceCity": cand["city"].title(),
           "frequency": cand["frequency"], "streamURL": cand["stream"]}
    homepage = cand.get("homepage") or ""
    if homepage.startswith(("http://", "https://")):
        out["homepage"] = homepage
    if cand.get("stationuuid"):
        out["radioBrowserID"] = cand["stationuuid"]
    return out


def cmd_candidates(city_id):
    fcc, directory = _load_cache()
    for p in proposals(CITIES[city_id], fcc, directory):
        print("%-8s %5.1f  %-18s" % (p["call"], p["frequency"], p["city"].title()))
        for i, c in enumerate(p["candidates"][:3]):
            print("    %s %s | %s | tags=%s | clicks=%s" % (
                "->" if i == 0 else "  ", c.get("name"), c["url_resolved"],
                c.get("tags") or "-", c.get("clickcount")))
    return 0


def cmd_build(verify):
    fcc, directory = _load_cache()
    cities, failed = [], []
    for city_id, city in CITIES.items():
        try:
            chosen = apply_corrections(proposals(city, fcc, directory), load_corrections(city_id))
        except ValueError as err:
            print("%s: %s" % (city["name"], err), file=sys.stderr)
            return 1
        if len(chosen) < MIN_PER_CITY:
            print("%s: only %d stations; need %d" % (city["name"], len(chosen), MIN_PER_CITY),
                  file=sys.stderr)
            return 1
        cities.append((city_id, city, chosen))
    all_chosen = [c for _, _, chosen in cities for c in chosen]
    if verify:
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda c: check_stream(c["stream"]), all_chosen))
        failed = [c["call"] for c, ok in zip(all_chosen, results) if not ok]
    if failed:
        print("failed stream check: %s" % ", ".join(failed), file=sys.stderr)
        print("%d cities, %d stations, %d failed" % (len(cities), len(all_chosen), len(failed)))
        return 1
    doc = {"generated": date.today().isoformat(),
           "cities": [{"id": cid, "name": c["name"], "key": c["key"],
                       "stations": [_station_json(s, directory) for s in chosen]}
                      for cid, c, chosen in cities]}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    for _, c, chosen in cities:
        print("%s: %d stations" % (c["name"], len(chosen)))
    print("%d cities, %d stations, 0 failed" % (len(cities), len(all_chosen)))
    return 0


def main(argv):
    usage = "usage: build_stations.py fetch | candidates <city> | build [--no-verify]"
    try:
        if argv[:1] == ["fetch"]:
            fetch()
            return 0
        if len(argv) == 2 and argv[0] == "candidates" and argv[1] in CITIES:
            return cmd_candidates(argv[1])
        if argv[:1] == ["build"] and set(argv[1:]) <= {"--no-verify"}:
            return cmd_build("--no-verify" not in argv)
    except (OSError, RuntimeError, ValueError) as err:
        print("error: %s" % err, file=sys.stderr)
        return 1
    print(usage, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
