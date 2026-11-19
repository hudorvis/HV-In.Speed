import SwiftUI

@main
struct InSpeedApp: App {
    @StateObject private var model = LocationService()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model).preferredColorScheme(.dark)
                .onChange(of: phase) { _, phase in
                    if phase != .inactive { model.scene(active: phase == .active) }
                }
        }
    }
}
