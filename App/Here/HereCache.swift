#if HERE
import Foundation
import os
import RadioCore

/// Keeps each place's dial in the caches folder, one file per 0.1 degree square.
struct HereCache {
    private let folder = URL.cachesDirectory.appending(path: "here", directoryHint: .isDirectory)
    private let log = Logger(subsystem: "HingeRadio", category: "here")

    /// The dial saved for `place`, or nil when there is none, it cannot be read, or it is too old.
    func load(_ place: Place) -> HereDial? {
        guard let data = try? Data(contentsOf: file(for: place)),
              let dial = try? JSONDecoder().decode(HereDial.self, from: data),
              dial.isUsable(at: .now) else { return nil }
        return dial
    }

    func save(_ dial: HereDial, for place: Place) {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(dial).write(to: file(for: place), options: .atomic)
        } catch {
            log.notice("HERE CACHE not saved")     // the error holds the file name, which holds the place
        }
    }

    private func file(for place: Place) -> URL {
        folder.appending(path: place.cacheKey + ".json", directoryHint: .notDirectory)
    }
}
#endif
