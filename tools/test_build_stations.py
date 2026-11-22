import contextlib
import io
import json
import os
import plistlib
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_stations as bs

FIXTURE = (
    "|KUCC        |88.1  MHz |FM |201 |ND  |                    |A  |-  |LIC    "
    "|CLARKSTON                |WA |US |BLED-20131119BDR    |0.46   kW |0.46   kW "
    "|138.0   |138.0   |88292      |N |46 |27 |46.5  |W |116 |54 |28.5  "
    "|UPPER COLUMBIA MEDIA ASSOCIATION |"
)


def entry(name, url="http://example.com/a", ok=1, clicks=0):
    return {"name": name, "url_resolved": url, "lastcheckok": ok, "clickcount": clicks}


def cand(call, freq, clicks=0, stream="http://example.com/s"):
    return {"call": call, "frequency": freq, "city": "X", "state": "WA",
            "name": call, "stream": stream, "clickcount": clicks}


class BuildStationsTests(unittest.TestCase):
    def test_parse_fcc_line(self):
        rows = bs.parse_fcc(FIXTURE + "\n")
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row["call"], "KUCC")
        self.assertEqual(row["frequency"], 88.1)
        self.assertEqual(row["service"], "FM")
        self.assertEqual(row["status"], "LIC")
        self.assertEqual(row["city"], "CLARKSTON")
        self.assertEqual(row["state"], "WA")
        self.assertAlmostEqual(row["lat"], 46.4629, places=3)
        self.assertAlmostEqual(row["lon"], -116.9079, places=3)

    def test_distance(self):
        d = bs.distance_km((47.6062, -122.3321), (47.2529, -122.4443))
        self.assertTrue(39 < d < 41, d)

    def test_base_call(self):
        self.assertEqual(bs.base_call("KEXP-FM"), "KEXP")
        self.assertEqual(bs.base_call("KING-FM"), "KING")
        self.assertEqual(bs.base_call("KNKX"), "KNKX")
        self.assertEqual(bs.base_call("KMGP-LP"), "KMGP")

    def test_am_namesake_rejected(self):
        station = {"call": "KJR-FM", "frequency": 93.3}
        directory = [entry("1090 KJR"), entry("KJR-FM 93.3 Seattle")]
        found = bs.stream_candidates(station, directory)
        self.assertEqual([c["name"] for c in found], ["KJR-FM 93.3 Seattle"])

    def test_whole_word_match(self):
        station = {"call": "KEXP-FM", "frequency": 90.3}
        found = bs.stream_candidates(station, [entry("KEXP"), entry("KEXPX radio")])
        self.assertEqual([c["name"] for c in found], ["KEXP"])

    def test_playlist_types_rejected(self):
        self.assertFalse(bs.is_playable_type("audio/x-scpls", "http://a/b"))
        self.assertFalse(bs.is_playable_type("audio/mpeg", "http://a/b.pls"))
        self.assertFalse(bs.is_playable_type("audio/mpeg", "http://a/b.m3u"))
        self.assertTrue(bs.is_playable_type("audio/mpeg", "http://a/b"))
        self.assertTrue(bs.is_playable_type("audio/aac", "http://a/b"))
        self.assertTrue(bs.is_playable_type("application/vnd.apple.mpegurl", "http://a/b.m3u8"))

    def test_same_frequency_rejected(self):
        cands = [cand("KAAA-FM", 89.9), cand("KBBB-FM", 89.9)]
        with self.assertRaises(ValueError) as ctx:
            bs.apply_corrections(cands, {"pick": ["KAAA-FM", "KBBB-FM"]})
        self.assertIn("89.9", str(ctx.exception))

    def test_seventeen_picks_rejected(self):
        cands = [cand("K%03d-FM" % i, 88.0 + i * 0.2) for i in range(17)]
        picks = [c["call"] for c in cands]
        with self.assertRaises(ValueError) as ctx:
            bs.apply_corrections(cands, {"pick": picks})
        self.assertIn("17", str(ctx.exception))

    def test_corrections_apply(self):
        cands = [cand("KAAA-FM", 99.9, clicks=5), cand("KBBB-FM", 88.1, clicks=3),
                 cand("KCCC-FM", 95.5, clicks=1), cand("KDDD-FM", 92.5, clicks=9)]
        corrections = {"stations": {
            "KDDD-FM": {"exclude": True},
            "KBBB-FM": {"name": "Bee", "stream": "http://example.com/new"},
        }}
        out = bs.apply_corrections(cands, corrections)
        self.assertEqual([c["call"] for c in out], ["KBBB-FM", "KCCC-FM", "KAAA-FM"])
        self.assertEqual(out[0]["name"], "Bee")
        self.assertEqual(out[0]["stream"], "http://example.com/new")

    def test_note_key_is_ignored(self):
        cands = [cand("KAAA-FM", 99.9, clicks=5), cand("KBBB-FM", 88.1, clicks=3)]
        plain = bs.apply_corrections(cands, {"pick": ["KAAA-FM", "KBBB-FM"]})
        noted = bs.apply_corrections(
            cands, {"pick": ["KAAA-FM", "KBBB-FM"],
                    "stations": {"KAAA-FM": {"note": "checked by hand"}}})
        self.assertEqual(noted, plain)

    def test_default_selection_skips_shared_frequency(self):
        cands = [cand("KAAA-FM", 89.9, clicks=9), cand("KBBB-FM", 89.9, clicks=5),
                 cand("KCCC-FM", 91.1, clicks=1)]
        out = bs.apply_corrections(cands, {})
        self.assertEqual([c["call"] for c in out], ["KAAA-FM", "KCCC-FM"])

    def _z100(self):
        c = cand("WHTZ", 100.3, clicks=5, stream="http://stream.example.com/z100")
        c["homepage"] = "https://z100.iheart.com/"
        c["stationuuid"] = "35d36481-own"
        return c

    def test_stream_override_keeps_matched_metadata(self):
        corrections = {"stations": {"WHTZ": {"stream": "https://stream.example.com/z100"}}}
        chosen = bs.apply_corrections([self._z100()], corrections)
        out = bs._station_json(chosen[0])
        self.assertEqual(out["streamURL"], "https://stream.example.com/z100")
        self.assertEqual(out["homepage"], "https://z100.iheart.com/")
        self.assertEqual(out["radioBrowserID"], "35d36481-own")

    def test_override_ignores_other_entry_with_same_address(self):
        corrections = {"stations": {"WHTZ": {"stream": "https://stream.example.com/z100"}}}
        other = {"name": "The Blaze", "url_resolved": "https://stream.example.com/z100",
                 "homepage": "https://www.kibz.com/", "stationuuid": "dbaa5a33-other"}
        chosen = bs.apply_corrections([self._z100()], corrections)
        out = bs._station_json(chosen[0])
        self.assertEqual(out["homepage"], "https://z100.iheart.com/")
        self.assertEqual(out["radioBrowserID"], "35d36481-own")
        self.assertNotIn(other["stationuuid"], out.values())

    # ------------------------------------------------ stream schemes

    def test_only_http_and_https_streams_are_used(self):
        station = {"call": "KAAA-FM", "frequency": 99.9}
        directory = [entry("KAAA-FM 99.9", url="rtsp://example.com/a", clicks=9),
                     entry("KAAA-FM 99.9", url="ftp://example.com/b", clicks=8),
                     entry("KAAA-FM 99.9", url="https://example.com/c", clicks=1)]
        found = bs.stream_candidates(station, directory)
        self.assertEqual([c["url_resolved"] for c in found], ["https://example.com/c"])

        cands = [cand("KAAA-FM", 99.9, stream="https://example.com/c")]
        with contextlib.redirect_stderr(io.StringIO()) as err:
            out = bs.apply_corrections(cands, {"stations": {"KAAA-FM": {"stream": "file:///etc/x"}}})
        self.assertEqual(out[0]["stream"], "https://example.com/c")
        self.assertIn("file:///etc/x", err.getvalue())

        bare = [cand("KBBB-FM", 88.1, stream=None)]
        with contextlib.redirect_stderr(io.StringIO()):
            out = bs.apply_corrections(bare, {"stations": {"KBBB-FM": {"stream": "mms://example.com/x"}}})
        self.assertEqual(out, [])   # no usable stream, so the station is not chosen

    # ------------------------------------------------ corrections keys

    def test_unknown_corrections_keys_warn(self):
        corrections = {"pick": [], "picks": [], "stations": {
            "KAAA-FM": {"name": "A", "steam": "https://example.com/a", "note": "n"},
            "KBBB-FM": {"exclude": True}}}
        with contextlib.redirect_stderr(io.StringIO()) as err:
            warnings = bs.warn_unknown_keys(corrections, "seattle.json")
        text = err.getvalue()
        self.assertEqual(len(warnings), 2)
        self.assertIn("seattle.json", text)
        self.assertIn('"picks"', text)
        self.assertIn("top level", text)
        self.assertIn('"steam"', text)
        self.assertIn("KAAA-FM", text)
        self.assertNotIn("KBBB-FM", text)

    def test_known_corrections_keys_are_quiet(self):
        corrections = {"pick": ["KAAA-FM"], "stations": {
            "KAAA-FM": {"name": "A", "stream": "https://e/a", "exclude": False, "note": "n"}}}
        with contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(bs.warn_unknown_keys(corrections, "x.json"), [])
        self.assertEqual(err.getvalue(), "")

    # ------------------------------------------------ plain-http hosts

    def test_http_host_differences(self):
        doc = {"cities": [{"stations": [
            {"streamURL": "http://a.example.com/s"},
            {"streamURL": "https://b.example.com/s"},
            {"streamURL": "http://c.example.com:8000/s"}]}]}
        to_add, to_remove = bs.http_host_differences(doc, {"a.example.com", "old.example.com"})
        self.assertEqual(to_add, ["c.example.com"])
        self.assertEqual(to_remove, ["old.example.com"])
        self.assertEqual(bs.http_host_differences(doc, {"a.example.com", "c.example.com"}), ([], []))

    def test_http_host_advice(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            bs.print_http_host_advice(["c.example.com"], ["old.example.com"])
        text = out.getvalue()
        self.assertIn("add", text)
        self.assertIn("c.example.com", text)
        self.assertIn("remove", text)
        self.assertIn("old.example.com", text)
        self.assertIn("then run xcodegen generate and rebuild the app", text)
        with contextlib.redirect_stdout(io.StringIO()) as out:
            bs.print_http_host_advice([], [])
        self.assertEqual(out.getvalue(), "")

    def test_bundled_plain_http_hosts_match_the_app(self):
        doc = json.loads(bs.OUTPUT.read_text())
        with open(bs.INFO_PLIST, "rb") as f:
            plist = plistlib.load(f)
        ats = plist.get("NSAppTransportSecurity", {})
        for key in ("NSAllowsArbitraryLoads", "NSAllowsArbitraryLoadsForMedia",
                    "NSAllowsArbitraryLoadsInWebContent"):
            self.assertNotIn(key, ats, "App/Info.plist must not set %s" % key)
        allowed = set(ats.get("NSExceptionDomains", {}))
        to_add, to_remove = bs.http_host_differences(doc, allowed)
        self.assertEqual(to_add, [], "plain-http hosts missing from App/Info.plist: %s" % to_add)
        self.assertEqual(to_remove, [], "App/Info.plist allows unused hosts: %s" % to_remove)
        project = (bs.ROOT / "project.yml").read_text()
        missing = sorted(h for h in allowed if (h + ":") not in project)
        self.assertEqual(missing, [], "hosts missing from project.yml: %s" % missing)


if __name__ == "__main__":
    unittest.main()
