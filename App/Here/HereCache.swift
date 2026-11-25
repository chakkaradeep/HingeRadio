#if HERE
import Foundation
import os
import RadioCore

/// Keeps each place's dial in the caches folder, one file per 0.1 degree square, for no longer
/// than it may be shown.
struct HereCache {
    private let folder = URL.cachesDirectory.appending(path: "here", directoryHint: .isDirectory)
    private let log = Logger(subsystem: "HingeRadio", category: "here")

    /// The dial saved for `place`, or nil when there is none or it cannot be read. Whether it is
    /// young enough to show is `HerePlan`'s to say.
    func load(_ place: Place) -> HereDial? {
        guard let data = try? Data(contentsOf: file(for: place)) else { return nil }
        return try? JSONDecoder().decode(HereDial.self, from: data)
    }

    func save(_ dial: HereDial, for place: Place) {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(dial).write(to: file(for: place), options: .atomic)
        } catch {
            log.notice("HERE CACHE not saved")     // the error holds the file name, which holds the place
        }
        removeExpired()
    }

    /// Removes the files nothing has written to for as long as a dial may be shown.
    private func removeExpired() {
        let key = URLResourceKey.contentModificationDateKey
        let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [key])
        for file in files ?? [] {
            guard let modified = try? file.resourceValues(forKeys: [key]).contentModificationDate,
                  Date.now.timeIntervalSince(modified) > HereDial.lifetime else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func file(for place: Place) -> URL {
        folder.appending(path: place.cacheKey + ".json", directoryHint: .notDirectory)
    }
}
#endif
