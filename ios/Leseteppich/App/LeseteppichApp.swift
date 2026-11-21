import SwiftUI

@main
struct LeseteppichApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CarpetMapView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.synthesizer.refreshVoices()
                    }
                }
        }
    }
}
