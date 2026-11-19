import CoreLocation
import SwiftUI

// The manager is constructed on the main thread. Delegate callbacks, view actions
// and ledger transactions all execute on that same run loop.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let store = TripStore()
    @Published private(set) var ledger = Ledger()
    @Published var issue: String?
    @Published private(set) var speed: Double?
    @Published private(set) var altitude: Double?
    @Published private(set) var bearing: Double?
    @Published private(set) var quality = "Acquiring GPS"
    @Published private(set) var authorization = CLAuthorizationStatus.notDetermined
    @Published private(set) var paused = false
    @Published var activity: Activity { didSet { defaults.set(activity.rawValue, forKey: "activity"); configure() } }
    @Published var units: Units { didSet { defaults.set(units.rawValue, forKey: "units") } }
    @Published var smoothing: Bool { didSet { defaults.set(smoothing, forKey: "smooth") } }
    @Published var autoPause: Bool { didSet { defaults.set(autoPause, forKey: "pause"); if !autoPause { paused = false } } }
    @Published var heightUnit: String { didSet { defaults.set(heightUnit, forKey: "height") } }
    @Published var background: Bool { didSet { defaults.set(background, forKey: "background"); configure() } }
    private let defaults = UserDefaults.standard
    private var previous: CLLocation?, anchor: CLLocation?, compass: CLHeading?
    private var lastTick = ContinuousClock.now
    private var lastSave = Date(), foreground = true, loaded = false
    private var newestFix = Date.distantPast
    private var startAfterPermission = false
    private var slowSince: Date?
    private var timer: Timer?
    var active: Trip? { ledger.active }
    var authorised: Bool { authorization == .authorizedAlways || authorization == .authorizedWhenInUse }
    override init() {
        let d = UserDefaults.standard
        activity = Activity(rawValue: d.string(forKey: "activity") ?? "") ?? .driving
        units = Units(rawValue: d.string(forKey: "units") ?? "") ?? .metric
        smoothing = d.object(forKey: "smooth") as? Bool ?? true
        autoPause = d.bool(forKey: "pause")
        background = d.object(forKey: "background") as? Bool ?? true
        heightUnit = d.string(forKey: "height") ?? "Automatic"
        super.init()
        do { ledger = try store.load(); loaded = true } catch { issue = error.localizedDescription }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
        configure()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }
    func request() { manager.requestWhenInUseAuthorization() }
    func orientation(_ orientation: CLDeviceOrientation) { manager.headingOrientation = orientation }
    func scene(active visible: Bool) {
        tick()
        foreground = visible
        configure()
        if !visible { checkpoint() }
    }
    func configure() {
        manager.activityType = activity == .driving ? .automotiveNavigation : (activity == .boating ? .otherNavigation : .fitness)
        manager.allowsBackgroundLocationUpdates = background && active != nil && authorised
        manager.showsBackgroundLocationIndicator = manager.allowsBackgroundLocationUpdates
        if authorised && (foreground || manager.allowsBackgroundLocationUpdates) {
            manager.startUpdatingLocation()
            if foreground && CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
            else { manager.stopUpdatingHeading() }
        } else {
            manager.stopUpdatingLocation(); manager.stopUpdatingHeading(); invalidate()
        }
    }
    func toggle() {
        guard loaded else { issue = "Trip storage is unavailable. Reopen In.Speed to retry."; return }
        if active != nil {
            tick()
            var next = ledger
            if let trip = next.active { next.trips.insert(trip, at: 0) }
            next.active = nil
            guard commit(next) else { return }
        } else {
            guard authorised else {
                if authorization == .notDetermined {
                    startAfterPermission = true
                    request()
                } else {
                    issue = "Enable location in iOS Settings to start a trip."
                }
                return
            }
            var next = ledger
            next.active = Trip(start: Date(), activity: activity)
            guard commit(next) else { return }
        }
        anchor = nil; lastTick = .now; paused = false; slowSince = nil; configure()
    }
    func clear() { var next = ledger; next.trips.removeAll(); _ = commit(next) }
    private func commit(_ next: Ledger) -> Bool {
        guard loaded else { return false }
        do { try store.save(next); ledger = next; lastSave = Date(); return true }
        catch { issue = error.localizedDescription; return false }
    }
    private func checkpoint() { if active != nil { _ = commit(ledger) } }
    private func tick() {
        let now = Date()
        if now.timeIntervalSince(previous?.timestamp ?? .distantPast) > 10 && previous != nil { invalidate(); quality = "GPS unavailable" }
        let instant = ContinuousClock.now
        if active != nil && !paused && (foreground || background) {
            let elapsed = lastTick.duration(to: instant).components
            ledger.active?.seconds += Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        }
        lastTick = instant
        if now.timeIntervalSince(lastSave) >= 10 { checkpoint() }
    }
    private func invalidate() {
        previous = nil; anchor = nil; speed = nil; altitude = nil; bearing = nil; compass = nil; slowSince = nil; paused = false
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        quality = authorised ? "Acquiring GPS" : "Location access required"
        configure()
        if startAfterPermission && authorization != .notDetermined {
            startAfterPermission = false
            if authorised && active == nil { toggle() }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        invalidate(); quality = "GPS unavailable"
    }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard foreground, authorised, newHeading.headingAccuracy >= 0,
              abs(newHeading.timestamp.timeIntervalSinceNow) < 15 else { return }
        compass = newHeading
        if (speed ?? 0) < 1.5 || (previous?.course ?? -1) < 0 {
            bearing = headingDegrees(newHeading)
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard authorised && (foreground || (background && active != nil)) else { return }
        for fix in locations {
            guard abs(fix.timestamp.timeIntervalSinceNow) < 15, fix.timestamp > newestFix else { continue }
            guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= 50 else {
                newestFix = fix.timestamp
                invalidate()
                quality = "Poor accuracy"
                continue
            }
            let dt = previous.map { fix.timestamp.timeIntervalSince($0.timestamp) } ?? 0
            if dt > 10 { anchor = nil; speed = nil }
            let delta = previous.map { fix.distance(from: $0) } ?? 0
            let cap = activity == .walking ? 12.0 : (activity == .cycling ? 45.0 : 130.0)
            if dt > 0 && dt <= 10 && delta > cap * dt + fix.horizontalAccuracy + (previous?.horizontalAccuracy ?? 0) { continue }
            let measured: Double?
            if fix.speed >= 0 && (fix.speedAccuracy < 0 || fix.speedAccuracy <= 5) { measured = fix.speed }
            else if dt > 0 && dt <= 10 { measured = delta > max(3, fix.horizontalAccuracy * 0.7) ? delta / dt : 0 }
            else { measured = nil }
            if let measured, !SpeedFilter.plausible(measured, previous: speed, seconds: dt, distance: delta, uncertainty: fix.horizontalAccuracy, activity: activity) { continue }
            newestFix = fix.timestamp
            previous = fix
            quality = fix.horizontalAccuracy <= 15 ? "GPS accurate" : "GPS fair"
            let threshold = activity.stopSpeed
            if let raw = measured {
                let alpha = smoothing ? 1 - exp(-max(0.5, dt) / 1.2) : 1
                speed = raw < threshold ? 0 : (speed.map { $0 + alpha * (raw - $0) } ?? raw)
            } else { speed = nil }
            altitude = fix.altitude.isFinite && fix.verticalAccuracy >= 0 && fix.verticalAccuracy <= 30 ? fix.altitude : nil
            if (speed ?? 0) >= 1.5 && (0..<360).contains(fix.course) { bearing = fix.course }
            else if let c = compass, abs(c.timestamp.timeIntervalSinceNow) < 15 { bearing = headingDegrees(c) }
            else { bearing = nil }
            guard let trip = active, fix.timestamp >= trip.start else { continue }
            if let altitude { ledger.active?.include(altitude: altitude) }
            if autoPause && measured != nil && (speed ?? 0) < threshold {
                let start = slowSince ?? fix.timestamp
                slowSince = start
                paused = fix.timestamp.timeIntervalSince(start) >= 4
            } else { slowSince = nil; paused = false }
            guard !paused, let speed, speed >= threshold else { anchor = fix; continue }
            ledger.active?.peak = max(trip.peak, speed)
            if let origin = anchor {
                let distance = fix.distance(from: origin)
                guard distance >= max(2, min(12, fix.horizontalAccuracy * 0.65)) else { continue }
                ledger.active?.metres += distance
            }
            anchor = fix
        }
    }
    private func headingDegrees(_ heading: CLHeading) -> Double? {
        let value = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        return (0..<360).contains(value) ? value : nil
    }
    func height(_ metres: Double?) -> String {
        guard let metres else { return "—" }
        let feet = heightUnit == "Feet" || (heightUnit == "Automatic" && units != .metric)
        return String(format: "%.0f %@", feet ? metres / 0.3048 : metres, feet ? "ft" : "m")
    }
}
