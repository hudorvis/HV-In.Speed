import SwiftUI

struct Instrument: View {
    @EnvironmentObject var model: LocationService
    var compass: Bool
    var full = false
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let reading = model.speed.map(model.units.speed)
            let base = model.units.speed(model.activity.scaleKMH / 3.6)
            let step = base < 15 ? 2.0 : (base < 100 ? 10.0 : 20.0)
            let scale = max(step, ceil(base / step) * step)
            let limit = scale * max(1, ceil(max(reading ?? 0, model.units.speed(model.active?.peak ?? 0)) / scale))
            let fraction = compass ? model.bearing.map { $0 / 360 } : reading.map { min(1, $0 / limit) }
            ZStack {
                Canvas { context, size in
                    let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                    func point(_ fraction: Double, _ radius: CGFloat) -> CGPoint {
                        let angle = (compass ? fraction * 360 - 90 : fraction * 300 + 120) * .pi / 180
                        return CGPoint(x: centre.x + cos(angle) * side * radius, y: centre.y + sin(angle) * side * radius)
                    }
                    func dot(_ point: CGPoint, _ diameter: CGFloat, _ colour: Color) {
                        context.fill(Path(ellipseIn: CGRect(x: point.x-diameter/2, y: point.y-diameter/2, width: diameter, height: diameter)), with: .color(colour))
                    }
                    let count = compass ? 96 : 100
                    for i in 0..<(compass ? count : count + 1) {
                        let f = Double(i) / Double(count)
                        let major = i % (compass ? 12 : 10) == 0
                        dot(point(f, 0.405), side * (major ? 0.020 : 0.012), (compass ? f < 0.5 : f <= (fraction ?? -1)) ? .green : .yellow)
                    }
                    let divisions = compass ? 8 : 5
                    for i in 0..<(compass ? divisions : divisions + 1) {
                        let f = Double(i) / Double(divisions)
                        let label = compass ? ["N","NE","E","SE","S","SW","W","NW"][i] : String(format: "%.0f", limit*f)
                        context.draw(Text(label).font(.system(size: min(18, max(10,side*0.030)), weight: .semibold)).foregroundColor(.white.opacity(0.76)), at: point(f,0.466))
                    }
                    if let fraction {
                        var marker = context
                        marker.addFilter(.shadow(color: .white.opacity(0.85), radius: side * 0.018))
                        let position = point(fraction, 0.405)
                        let radius = side * 0.019
                        marker.fill(Path(ellipseIn: CGRect(x: position.x - radius, y: position.y - radius,
                                                           width: 2 * radius, height: 2 * radius)), with: .color(.white))
                    }
                }
                if full {
                    VStack(spacing: 0) {
                        Text(reading.map { String(format: "%.1f", $0) } ?? "—")
                            .font(.system(size: side*0.19, weight: .light, design: .rounded))
                            .minimumScaleFactor(0.65).lineLimit(1)
                        Text(model.units.speedUnit).foregroundStyle(.secondary)
                        Text(headingLabel(model.bearing)).font(.headline).padding(.top,5)
                    }.frame(width: side*0.65)
                } else {
                    Button(action: model.toggle) {
                        Text(model.active == nil ? "START" : "STOP")
                            .font(.system(size: min(31, max(17,side*0.065)),weight: .semibold))
                            .frame(width: side*0.32,height:side*0.32)
                            .background(Circle().fill(.white.opacity(0.08)))
                            .overlay(Circle().stroke(model.active == nil ? .white.opacity(0.34) : .green, lineWidth: 1.5))
                    }.buttonStyle(.plain).accessibilityIdentifier("tripControl")
                }
            }.frame(width: side,height: side).position(x: geometry.size.width/2,y:geometry.size.height/2)
        }
    }
}
