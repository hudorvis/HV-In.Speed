import Foundation

struct Ledger: Codable {
    var trips: [Trip] = []
    var active: Trip?
}
struct TripStore {
    let file: URL
    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("InSpeed/trips.json")
    }
    func load() throws -> Ledger {
        do { return try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: file)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return Ledger() }
    }
    func save(_ ledger: Ledger) throws {
        var directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        var options: Data.WritingOptions = [.atomic]
        #if os(iOS)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try JSONEncoder().encode(ledger).write(to: file, options: options)
    }
}
