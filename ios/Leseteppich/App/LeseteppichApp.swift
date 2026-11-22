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
                    } else if newPhase == .background {
                        // .background only, not .inactive: iOS permission prompts also make the scene inactive,
                        // and stopping then would abort the first mic start. Never keep mic/audio running here.
                        store.speechRecognizer.stopListening()
                        store.synthesizer.stop()
                        store.voiceRecorder.stopRecording()
                    }
                }
        }
    }
}
