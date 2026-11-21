import SwiftUI

@main
struct LeseteppichApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            CarpetMapView()
                .environmentObject(store)
        }
    }
}
