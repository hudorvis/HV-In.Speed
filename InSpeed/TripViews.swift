import SwiftUI

struct OperatingSettings: View {
    @EnvironmentObject var model: LocationService
    var body: some View {
        Form {
            Section {
                Picker("Activity",selection:$model.activity) {
                    ForEach(Activity.allCases,id:\.self) { Text($0.rawValue).tag($0) }
                }.disabled(model.active != nil)
                Picker("Altitude",selection:$model.heightUnit) {
                    ForEach(["Automatic","Metres","Feet"],id:\.self) { Text($0).tag($0) }
                }
                Toggle("Smooth speed",isOn:$model.smoothing)
            } footer: { Text("Automatic altitude uses metres in Metric and feet in Imperial and Nautical.") }
            Section("Trip recording") {
                Toggle("Auto-pause when stationary",isOn:$model.autoPause)
                Toggle("Record in background",isOn:$model.background)
            }
        }.scrollContentBackground(.hidden).tint(.green)
    }
}
struct TripViews: View {
    @EnvironmentObject var model: LocationService
    var section: String
    @State private var detail: Trip?
    @State private var confirm = false
    var trips: [Trip] { model.ledger.trips }
    var body: some View {
        Group {
            if section == "History" && trips.isEmpty {
                ContentUnavailableView("No trips yet",systemImage:"location",description:Text("Start a trip from Speed or Compass. Completed trips appear here."))
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                List {
                    if section == "History" {
                        ForEach(trips) { t in
                            Button { detail = t } label: {
                                HStack { VStack(alignment:.leading,spacing:4) {
                                    Text(t.activity.rawValue)
                                    Text(t.start.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                                }; Spacer(); Text(distance(t.metres)); Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary) }
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    } else if section == "Totals" {
                        let seconds = trips.reduce(0) { $0 + $1.seconds }
                        let metres = trips.reduce(0) { $0 + $1.metres }
                        LabeledContent("Total trips",value:String(trips.count))
                        metrics(metres,seconds,seconds > 0 ? metres/seconds : 0,trips.map(\.peak).max() ?? 0,trips.compactMap(\.high).max(),trips.compactMap(\.low).min())
                    } else {
                        Section {
                            LabeledContent("Saved trips",value:String(trips.count))
                            LabeledContent("Storage",value:"On this device")
                        } footer: { Text("In.Speed saves trip summaries locally. GPS coordinates are used during recording and are never written to trip history.") }
                        Button("Clear trip history",role:.destructive) { confirm = true }.disabled(trips.isEmpty)
                        LabeledContent("Revision",value:"In.Speed v26.11.26.01")
                    }
                }.scrollContentBackground(.hidden)
            }
        }.confirmationDialog("Clear all completed trips?",isPresented:$confirm,titleVisibility:.visible) {
            Button("Clear trip history",role:.destructive,action:model.clear)
        }.sheet(item:$detail) { t in
            NavigationStack {
                List {
                    LabeledContent("Activity",value:t.activity.rawValue)
                    LabeledContent("Started",value:t.start.formatted(date:.abbreviated,time:.shortened))
                    metrics(t.metres,t.seconds,t.average,t.peak,t.high,t.low)
                }.navigationTitle("Trip details").toolbar { Button("Done") { detail = nil } }
            }.preferredColorScheme(.dark)
        }
    }
    func distance(_ m:Double) -> String { String(format:"%.2f %@",m/model.units.divisor,model.units.distanceUnit) }
    @ViewBuilder func metrics(_ metres:Double,_ seconds:Double,_ avg:Double,_ peak:Double,_ high:Double?,_ low:Double?) -> some View {
        LabeledContent("Distance",value:distance(metres))
        LabeledContent("Duration",value:clock(seconds))
        LabeledContent("Average speed",value:String(format:"%.1f %@",model.units.speed(avg),model.units.speedUnit))
        LabeledContent("Maximum speed",value:String(format:"%.1f %@",model.units.speed(peak),model.units.speedUnit))
        LabeledContent("Highest altitude",value:model.height(high))
        LabeledContent("Lowest altitude",value:model.height(low))
    }
}
