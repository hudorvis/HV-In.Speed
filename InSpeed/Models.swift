import Foundation

enum Activity: String, Codable, CaseIterable {
    case driving = "Driving", cycling = "Cycling", boating = "Boating", walking = "Walking"
    var scaleKMH: Double {
        switch self { case .driving: return 160; case .cycling: return 60; case .boating: return 80; case .walking: return 10 }
    }
    var stopSpeed: Double { self == .walking ? 0.28 : (self == .driving ? 0.9 : 0.5) }
}
enum Units: String, CaseIterable, Codable {
    case metric = "Metric", imperial = "Imperial", nautical = "Nautical"
    var divisor: Double { self == .metric ? 1000 : (self == .imperial ? 1609.344 : 1852) }
    var distanceUnit: String { self == .metric ? "km" : (self == .imperial ? "mi" : "nm") }
    var speedUnit: String { self == .nautical ? "kn" : (self == .metric ? "km/h" : "mph") }
    func speed(_ value: Double) -> Double { value * 3600 / divisor }
}
struct Trip: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var activity: Activity
    var metres = 0.0, seconds = 0.0, peak = 0.0
    var low: Double?, high: Double?
    var average: Double { seconds > 0 ? metres / seconds : 0 }
    mutating func include(altitude: Double) {
        low = min(low ?? altitude, altitude)
        high = max(high ?? altitude, altitude)
    }
}
func clock(_ interval: Double) -> String {
    let s = Int(max(0, interval))
    return String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
}

// Driver-reported Doppler speed and a position interval are independent signals.
// Reject a solitary speed jump when the displacement cannot support it.
enum SpeedFilter {
    static func plausible(_ speed: Double, previous: Double?, seconds: Double,
                          distance: Double, uncertainty: Double, activity: Activity) -> Bool {
        guard speed.isFinite, speed >= 0 else { return false }
        let cap = activity == .walking ? 12.0 : (activity == .cycling ? 45.0 : 130.0)
        guard speed <= cap else { return false }
        guard let previous, seconds > 0, seconds <= 10 else { return true }
        let acceleration = activity == .walking ? 3.0 : (activity == .cycling ? 5.0 : 12.0)
        return speed <= previous + acceleration * seconds ||
            speed * seconds <= distance + max(3, uncertainty)
    }
}

enum AdaptiveLayout {
    /// The approved left-menu/right-clock split is retained on iPhone
    /// landscape and on sufficiently wide iPad windows. Narrow resizable iPad
    /// windows automatically fall back to the existing stacked arrangement.
    static func useSplitLayout(for size: CGSize) -> Bool {
        size.width > size.height &&
        size.width >= 500 &&
        size.height >= 300
    }

    /// Expanded metrics are based on the current app window, not the device
    /// model. An iPad in a narrow window therefore behaves like a compact app,
    /// while a full-size iPad gets appropriately larger instruments.
    static func isExpandedCanvas(_ size: CGSize) -> Bool {
        min(size.width, size.height) >= 600
    }

    static func sidebarWidth(for size: CGSize) -> CGFloat {
        guard useSplitLayout(for: size) else { return 0 }

        if size.width >= 1_000 && size.height >= 650 {
            return min(
                max(size.width * 0.28, 330),
                420
            )
        }

        return min(
            max(size.width * 0.30, 250),
            292
        )
    }
}


func headingLabel(_ angle: Double?) -> String {
    guard let angle, angle.isFinite, (0...360).contains(angle) else { return "—" }
    let degrees = Int(angle.rounded()) % 360
    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return String(format: "%03d° %@", degrees, directions[Int((angle / 45).rounded()) % 8])
}
