import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var model: LocationService
    @State private var page = "Live"
    @State private var live = "Speed"
    @State private var trips = "History"
    @State private var full = false
    @State private var controls = false
    @Environment(\.openURL) var openURL
    var body: some View {
        GeometryReader { g in
            let split = AdaptiveLayout.useSplitLayout(for: g.size)
            ZStack {
                LinearGradient(colors: [Color(red:0.055,green:0.062,blue:0.060),.black,.black],startPoint:.top,endPoint:.bottom).ignoresSafeArea()
                if full {
                    VStack(spacing: 4) {
                        Instrument(compass:false, full:true)
                        stats.padding(.horizontal,16)
                    }.padding(.vertical,8).contentShape(Rectangle()).onTapGesture { controls.toggle() }
                    if controls {
                        VStack { HStack {
                            Button("Done") { full = false; controls = false }
                            Spacer()
                            Button(model.active == nil ? "Start trip" : "Stop trip", action:model.toggle)
                        }.buttonStyle(.borderedProminent).tint(.gray.opacity(0.6)); Spacer() }.padding(8)
                    }
                } else if split {
                    HStack(spacing:0) {
                        VStack(spacing:8) {
                            header
                            status
                            Spacer(minLength:0)
                            if page == "Live" && live == "Speed" && g.size.height >= 380 {
                                HStack { number; Spacer() }
                                stats
                            }
                            bottom
                        }
                            .padding(.horizontal,12).padding(.vertical,4)
                            .frame(width:AdaptiveLayout.sidebarWidth(for:g.size))
                        Divider()
                        if page == "Live" && live == "Speed" && g.size.height >= 380 {
                            Instrument(compass:false)
                        } else { content }
                    }
                } else {
                    VStack(spacing:8) {
                        header.frame(maxWidth: 620).padding(.horizontal,24)
                        status.padding(.horizontal,18)
                        content
                        bottom.frame(maxWidth: 620).padding(.horizontal,18)
                    }.padding(.bottom,8)
                }
            }
            .onAppear { updateHeading() }
            .onChange(of: g.size) { _,_ in updateHeading() }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in updateHeading() }
        }
        .statusBarHidden(full)
        .alert("In.Speed", isPresented: Binding(get:{ model.issue != nil }, set:{ if !$0 { model.issue = nil } })) {
            Button("OK") { model.issue = nil }
        } message: { Text(model.issue ?? "") }
    }
    func updateHeading() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }) else { return }
        switch scene.interfaceOrientation {
        case .landscapeLeft: model.orientation(.landscapeRight)
        case .landscapeRight: model.orientation(.landscapeLeft)
        case .portraitUpsideDown: model.orientation(.portraitUpsideDown)
        default: model.orientation(.portrait)
        }
    }
    var header: some View {
        VStack(spacing:8) {
            brandHeading
            pill(["Live","Trips"], selection:$page, primary:true)
            if page == "Live" { pill(["Speed","Compass","Settings"],selection:$live) }
            else { pill(["History","Totals","Settings"],selection:$trips) }
        }
    }
    func pill(_ items:[String], selection: Binding<String>, primary:Bool = false) -> some View {
        HStack(spacing:0) {
            ForEach(items,id:\.self) { item in
                Button { selection.wrappedValue = item } label: {
                    Text(item).font(.system(size: primary ? 15 : 14,weight: selection.wrappedValue == item ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(selection.wrappedValue == item ? 1 : 0.62))
                        .frame(maxWidth:.infinity).frame(height:primary ? 38 : 34)
                        .background { if selection.wrappedValue == item { Capsule().fill(.white.opacity(0.14)) } }
                        .contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(selection.wrappedValue == item ? .isSelected : [])
            }
        }.padding(3).background(Capsule().fill(.white.opacity(0.05))).overlay(Capsule().stroke(.white.opacity(0.12)))
    }
    var status: some View {
        VStack(alignment:.leading,spacing:4) {
            HStack {
                Text(model.active == nil ? "LIVE" : (model.paused ? "PAUSED" : "REC")).foregroundStyle(model.active == nil ? Color.secondary : .green)
                Text("• " + model.activity.rawValue)
                Spacer()
                Text(clock(model.active?.seconds ?? 0)).monospacedDigit()
            }
            if model.authorised { Text(model.quality).foregroundStyle(.secondary) }
            else {
                Button(model.authorization == .notDetermined ? "Enable location" : "Location settings") {
                    if model.authorization == .notDetermined { model.request() }
                    else if let url = URL(string:UIApplication.openSettingsURLString) { openURL(url) }
                }.foregroundStyle(.yellow)
            }
        }.font(.caption)
    }
    var bottom: some View {
        HStack(spacing:0) {
            Menu {
                ForEach(Units.allCases,id:\.self) { unit in
                    Button { model.units = unit } label: {
                        if model.units == unit { Label(unit.rawValue,systemImage:"checkmark") } else { Text(unit.rawValue) }
                    }
                }
            } label: { Label(model.units.rawValue,systemImage:"ruler").frame(maxWidth:.infinity) }
            Divider().frame(height:24)
            Button { controls = false; full = true } label: { Label("Full Screen",systemImage:"arrow.up.left.and.arrow.down.right").frame(maxWidth:.infinity) }
        }.font(.system(size:14,weight:.medium)).frame(height:54).background(Capsule().fill(.white.opacity(0.05))).overlay(Capsule().stroke(.white.opacity(0.12))).buttonStyle(.plain)
    }
    @ViewBuilder var content: some View {
        if page == "Trips" { TripViews(section:trips) }
        else if live == "Settings" { OperatingSettings() }
        else {
            VStack(spacing:2) {
                Instrument(compass:live == "Compass")
                if live == "Compass" {
                    Text(headingLabel(model.bearing)).font(.system(size:37,weight:.light,design:.rounded))
                    Text("Altitude  " + model.height(model.altitude)).foregroundStyle(.secondary)
                } else {
                    number
                    stats
                }
            }.monospacedDigit().padding(.horizontal,8).padding(.bottom,5)
        }
    }
    var number: some View {
HStack(alignment:.firstTextBaseline,spacing:5) {
                        Text(model.speed.map { String(format:"%.1f",model.units.speed($0)) } ?? "—").font(.system(size:34,weight:.light,design:.rounded))
                        Text(model.units.speedUnit).foregroundStyle(.secondary)
                    }
    }
    var stats: some View {
        HStack(spacing:3) {
            ForEach(statItems,id:\.0) { item in
                VStack(spacing:3) { Text(item.0).font(.caption2).foregroundStyle(.secondary); Text(item.1).font(.subheadline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.65) }.frame(maxWidth:.infinity)
            }
        }
    }
    var statItems: [(String,String)] {
        let t = model.active
        return [("Average",String(format:"%.1f",model.units.speed(t?.average ?? 0))),("Maximum",String(format:"%.1f",model.units.speed(t?.peak ?? 0))),("Distance",String(format:"%.2f %@",(t?.metres ?? 0)/model.units.divisor,model.units.distanceUnit)),("Duration",clock(t?.seconds ?? 0))]
    }
    private var brandHeading: some View {
        VStack(spacing: 4) {
            HStack(
                alignment: .firstTextBaseline,
                spacing: -1
            ) {
                Text("In")
                    .font(
                        .system(
                            size: 35,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .tracking(-0.8)

                Text(".")
                    .font(
                        .system(
                            size: 35,
                            weight: .heavy,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.yellow
                    )
                    .shadow(
                        color:
                            Color.yellow
                                .opacity(0.72),
                        radius: 5
                    )

                Text("Speed")
                    .font(
                        .system(
                            size: 35,
                            weight: .light,
                            design: .rounded
                        )
                    )
                    .tracking(-0.9)
            }
            .foregroundStyle(.white)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.yellow,
                            Color.green
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: 56,
                    height: 2
                )
                .opacity(0.88)
                .shadow(
                    color:
                        Color.green
                            .opacity(0.30),
                    radius: 3
                )
        }
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel("In.Speed")
        .padding(.top, 7)
        .padding(.bottom, 11)
    }

}
