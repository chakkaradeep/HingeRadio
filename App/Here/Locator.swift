#if HERE
import CoreLocation
import MapKit
import RadioCore

enum LocatorError: Error { case refused, unavailable }

/// Finds roughly where the phone is, and the name of the town there. Location is asked for the
/// first time `place()` is called, never before, and only roughly. The position is never logged.
@MainActor final class Locator: NSObject, @MainActor CLLocationManagerDelegate {
    /// Made when first needed: until HERE is chosen the app has nothing to do with location.
    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        manager.delegate = self
        return manager
    }()
    /// The one `place()` call waiting for an answer.
    private var waiting: (id: UUID, answer: CheckedContinuation<Result<Place, LocatorError>, Never>)?
    private var timeLimit: Task<Void, Never>?

    private static let fixLimit = Duration.seconds(10)

    /// Where the phone is, from one fix. The time limit starts once location is allowed, so the
    /// prompt may be answered late. Cancelled, it throws `.unavailable`. A call still waiting when
    /// another begins gets `.unavailable` too.
    func place() async throws(LocatorError) -> Place {
        guard await Self.servicesAreOn() else { throw .refused }
        let id = UUID()
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { answer in
                finish(.failure(.unavailable))
                waiting = (id, answer)
                // Cancelled already, it must not ask for anything.
                if Task.isCancelled { finish(.failure(.unavailable)) } else { proceed() }
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
        return try result.get()
    }

    /// The town at `place`, or nil when Apple's reverse geocoder has no name or no answer.
    func town(for place: Place) async -> String? {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        return (try? await request.mapItems)?.first?.addressRepresentations?.cityName
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Undecided, the prompt is already up.
        if manager.authorizationStatus != .notDetermined { proceed() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else {
            finish(.failure(.unavailable))
            return
        }
        finish(.success(Place(latitude: location.coordinate.latitude,
                              longitude: location.coordinate.longitude)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        finish(.failure((error as? CLError)?.code == .denied ? .refused : .unavailable))
    }

    // MARK: - Private

    /// Takes the waiting call as far as the permission allows: the prompt, a fix, or the end.
    private func proceed() {
        guard waiting != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            guard timeLimit == nil else { return }       // the fix is already on its way
            timeLimit = Task { [weak self] in
                try? await Task.sleep(for: Self.fixLimit)
                if !Task.isCancelled { self?.finish(.failure(.unavailable)) }
            }
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(.refused))
        @unknown default:
            finish(.failure(.refused))
        }
    }

    private func cancel(_ id: UUID) {
        if waiting?.id == id { finish(.failure(.unavailable)) }
    }

    /// Answers the waiting call, once, and stops looking.
    private func finish(_ result: Result<Place, LocatorError>) {
        guard let waiting else { return }
        self.waiting = nil
        timeLimit?.cancel()
        timeLimit = nil
        manager.stopUpdatingLocation()
        waiting.answer.resume(returning: result)
    }

    /// Asked off the main thread, as it may wait for the location service.
    @concurrent private nonisolated static func servicesAreOn() async -> Bool {
        CLLocationManager.locationServicesEnabled()
    }
}
#endif
