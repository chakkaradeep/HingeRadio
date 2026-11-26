import Foundation
import Testing
@testable import RadioCore

private func fixture(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name)")
    return try Data(contentsOf: url)
}

private func licence(_ call: String, frequency: Double) -> Licence {
    Licence(callSign: call, city: "Seattle", stationClass: "C", frequency: frequency,
            kilowatts: 50, distance: 10)
}

private func data(_ text: String) -> Data { Data(text.utf8) }

// MARK: - Addresses

@Test func lookupAddressesUseTheBaseCall() {
    let kexp = licence("KEXP-FM", frequency: 90.3)
    #expect(lookupURL(.npr, for: kexp, radioBrowserHost: "de1.api.radio-browser.info").absoluteString
            == "https://station.api.npr.org/v3/stations?q=KEXP")
    #expect(lookupURL(.radioBrowser, for: kexp, radioBrowserHost: "de1.api.radio-browser.info").absoluteString
            == "https://de1.api.radio-browser.info/json/stations/search?countrycode=US&hidebroken=true&limit=50&name=KEXP")
}

@Test func lookupValuesArePercentEncoded() {
    let odd = licence("K&X=1 +", frequency: 90.3)
    let url = lookupURL(.radioBrowser, for: odd, radioBrowserHost: "host.example").absoluteString
    #expect(url.hasSuffix("name=K%26X%3D1%20%2B"))
}

@Test func sourcesAreTriedInOrder() {
    #expect(StreamSource.allCases == [.npr, .radioBrowser])
}

@Test(arguments: StreamSource.allCases)
func noSourceAsksIHeart(source: StreamSource) {
    let kexp = licence("KEXP-FM", frequency: 90.3)
    #expect(lookupURL(source, for: kexp, radioBrowserHost: "de1.api.radio-browser.info").host?
            .contains("iheart") == false)
}

// MARK: - NPR

@Test func nprGivesPrimaryHTTPSAudioFirst() throws {
    let choice = try #require(streamChoice(.npr, from: fixture("npr-kuow.json"),
                                           for: licence("KUOW-FM", frequency: 94.9)))
    #expect(choice.name == "KUOW")
    #expect(choice.radioBrowserID == nil)
    #expect(choice.urls.map(\.absoluteString) == [
        "https://playerservices.streamtheworld.com/api/livestream-redirect/KUOWFM_HIGH_MP3.mp3?dist=NPR",
        "https://playerservices.streamtheworld.com/api/livestream-redirect/KUOWFM_AAC.aac?dist=NPR",
        "https://playerservices.streamtheworld.com/api/livestream-redirect/KUOWFM_LOW_MP3.mp3?dist=NPR"
    ])
}

@Test func nprPutsThePrimaryStreamFirstWhereverItSits() {
    let reordered = data(#"{"items":[{"attributes":{"brand":{"call":"KUOW","frequency":"94.9","name":"KUOW"},"streamsV2":[{"primary":false,"urls":[{"content-type":"audio/mp3","href":"https://a.example/low"}]},{"primary":true,"urls":[{"content-type":"audio/mp3","href":"https://a.example/high"}]}]}}]}"#)
    let choice = streamChoice(.npr, from: reordered, for: licence("KUOW-FM", frequency: 94.9))
    #expect(choice?.urls.map(\.absoluteString) == ["https://a.example/high", "https://a.example/low"])
}

@Test func nprWithAnotherFrequencyOrOnlyHTTPGivesNothing() throws {
    let kuow = try fixture("npr-kuow.json")
    #expect(streamChoice(.npr, from: kuow, for: licence("KUOW-FM", frequency: 97.3)) == nil)
    let plain = data(#"{"items":[{"attributes":{"brand":{"call":"KUOW","frequency":"94.9","name":"KUOW"},"streamsV2":[{"primary":true,"urls":[{"content-type":"audio/mp3","href":"http://a.example/s"}]}]}}]}"#)
    #expect(streamChoice(.npr, from: plain, for: licence("KUOW-FM", frequency: 94.9)) == nil)
}

// MARK: - Radio Browser

private let uuid = "399ca326-0f67-4015-a51b-d7ba2bd4ebbe"

private func entry(name: String, ok: Int = 1, ssl: Int = 0, url: String = "https://a.example/kexp") -> Data {
    data(#"[{"stationuuid":"\#(uuid)","name":"\#(name)","url_resolved":"\#(url)","lastcheckok":\#(ok),"ssl_error":\#(ssl)}]"#)
}

private let kexp = licence("KEXP-FM", frequency: 90.3)

@Test func radioBrowserNeedsCallSignAndFrequencyInTheName() throws {
    let choice = try #require(streamChoice(.radioBrowser, from: entry(name: "KEXP 90.3 FM Seattle"), for: kexp))
    #expect(choice.name == "KEXP")
    #expect(choice.radioBrowserID == uuid)
    #expect(choice.urls.map(\.absoluteString) == ["https://a.example/kexp"])
    #expect(streamChoice(.radioBrowser, from: entry(name: "kexp 90.3"), for: kexp) != nil)
}

@Test func radioBrowserRefusesHalfAMatchAndUnhealthyEntries() {
    #expect(streamChoice(.radioBrowser, from: entry(name: "KEXP"), for: kexp) == nil)
    #expect(streamChoice(.radioBrowser, from: entry(name: "Seattle 90.3"), for: kexp) == nil)
    #expect(streamChoice(.radioBrowser, from: entry(name: "KEXP 90.3", ok: 0), for: kexp) == nil)
    #expect(streamChoice(.radioBrowser, from: entry(name: "KEXP 90.3", ssl: 1), for: kexp) == nil)
    #expect(streamChoice(.radioBrowser, from: entry(name: "KEXP 90.3", url: "http://a.example/kexp"), for: kexp) == nil)
}

@Test func radioBrowserMatchesWholeWordsAndNumbersOnly() {
    #expect(streamChoice(.radioBrowser, from: entry(name: "WKEXP 90.3"), for: kexp) == nil)
    #expect(streamChoice(.radioBrowser, from: entry(name: "KEXP 190.3"), for: kexp) == nil)
    #expect(streamChoice(.radioBrowser, from: entry(name: "KEXP 90.35"), for: kexp) == nil)
}

@Test func radioBrowserRealAnswerHasNoHTTPSMatchForKEXP() throws {
    // Today's real answer names KEXP 90.3 only on http streams.
    #expect(try streamChoice(.radioBrowser, from: fixture("rb-kexp.json"), for: kexp) == nil)
}

@Test func radioBrowserKeepsGoodNeighboursOfABadEntry() {
    let mixed = data(#"[{"name":5,"lastcheckok":"yes"},{"stationuuid":"u1","name":"KEXP 90.3","url_resolved":"https://a.example/k","lastcheckok":1,"ssl_error":0}]"#)
    #expect(streamChoice(.radioBrowser, from: mixed, for: kexp)?.radioBrowserID == "u1")
}

// MARK: - Not an answer

@Test(arguments: StreamSource.allCases)
func eachSourceSkipsAnEmptyHTMLOrBareAnswer(source: StreamSource) {
    for body in [Data(), data("<html>Bad gateway</html>"), data("{}"), data("[]"), data(#"{"hits":"#)] {
        #expect(streamChoice(source, from: body, for: kexp) == nil)
    }
}

// MARK: - Playable

private let https = URL(string: "https://a.example/live")!

@Test(arguments: ["audio/mpeg", "audio/aac", "audio/aacp", "application/vnd.apple.mpegurl",
                  "application/x-mpegurl", "audio/mpeg; charset=utf-8", "Audio/MPEG"])
func playableTypesPlay(type: String) {
    #expect(isPlayable(status: 200, contentType: type, finalURL: https))
}

@Test(arguments: ["audio/x-scpls", "audio/x-mpegurl", "text/html"])
func playlistsAndPagesDoNotPlay(type: String) {
    #expect(!isPlayable(status: 200, contentType: type, finalURL: https))
}

@Test func otherAnswersDoNotPlay() throws {
    #expect(!isPlayable(status: 200, contentType: nil, finalURL: https))
    #expect(!isPlayable(status: 404, contentType: "audio/mpeg", finalURL: https))
    #expect(try !isPlayable(status: 200, contentType: "audio/mpeg", finalURL: #require(URL(string: "http://a.example/live"))))
    #expect(try !isPlayable(status: 200, contentType: "audio/mpeg", finalURL: #require(URL(string: "https://a.example/live.pls"))))
    #expect(try !isPlayable(status: 200, contentType: "audio/mpeg", finalURL: #require(URL(string: "https://a.example/live.M3U"))))
}
