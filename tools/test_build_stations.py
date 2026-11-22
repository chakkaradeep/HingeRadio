import os
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

    def test_default_selection_skips_shared_frequency(self):
        cands = [cand("KAAA-FM", 89.9, clicks=9), cand("KBBB-FM", 89.9, clicks=5),
                 cand("KCCC-FM", 91.1, clicks=1)]
        out = bs.apply_corrections(cands, {})
        self.assertEqual([c["call"] for c in out], ["KAAA-FM", "KCCC-FM"])


if __name__ == "__main__":
    unittest.main()
