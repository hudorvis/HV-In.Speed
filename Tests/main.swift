import Foundation

func check(_ condition: Bool, _ name: String) {
    precondition(condition, name)
    print("PASS", name)
}
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: directory) }
let store = TripStore(file: directory.appendingPathComponent("summary.json"))
let empty = try store.load()
check(empty.active == nil && empty.trips.isEmpty, "First launch")
var trip = Trip(start: Date(),activity:.cycling)
trip.metres = 1852
trip.seconds = 600
trip.peak = 9
trip.include(altitude: -3)
trip.include(altitude: 15)
try store.save(Ledger(active:trip))
let resumed = try store.load()
check(resumed.active?.id == trip.id, "Recover a checkpoint")
try store.save(Ledger(trips:[trip]))
let history = try store.load()
check(history.active == nil && history.trips.count == 1, "Stop and save exactly once")
check(history.trips[0].low == -3 && history.trips[0].high == 15, "Altitude extrema")
check(abs(Units.nautical.speed(trip.average)-6) < 0.000001, "Weighted speed in knots")
check(abs(Units.imperial.speed(Units.imperial.divisor/3600)-1) < 0.00001, "Miles per hour")
check(clock(3610) == "01:00:10", "Duration")
check(!SpeedFilter.plausible(80,previous:3,seconds:1,distance:4,uncertainty:5,activity:.driving), "Isolated Doppler spike")
check(SpeedFilter.plausible(4,previous:3,seconds:1,distance:4,uncertainty:5,activity:.driving), "Genuine acceleration")
check(!SpeedFilter.plausible(30,previous:nil,seconds:0,distance:0,uncertainty:3,activity:.walking), "Activity cap")
try Data([0xFF]).write(to: store.file)
do { _ = try store.load(); fatalError("Corrupt history accepted") }
catch { print("PASS Corrupt history reported") }
let windows: [(CGFloat,CGFloat,Bool)] = [
    (375,647,false),(393,759,false),(667,354,true),(759,372,true),
    (744,1070,false),(1024,724,true),(1194,790,true),(320,748,false),
    (540,780,false),(720,500,true),(480,350,false)
]
for (width,height,split) in windows {
    let size = CGSize(width:width,height:height)
    check(AdaptiveLayout.useSplitLayout(for:size) == split,"Layout at \(size)")
    if split {
        let rail = AdaptiveLayout.sidebarWidth(for:size)
        check(width-rail >= 250 && rail >= 250,"Rail and instrument fit")
    }
}

check(headingLabel(-45) == "—" && headingLabel(.infinity) == "—", "Invalid headings")
check(headingLabel(359.9) == "000° N" && headingLabel(47) == "047° NE", "Heading wrap and rounding")
