import SwiftUI

struct ContentView: View {
    @StateObject private var router = SessionRouter.shared

    var body: some View {
        // The active session is swapped in at the root (not presented as a
        // sheet) so landing-page re-renders can never tear it down.
        switch router.active {
        case .yoga:
            YogaTimerView()
        case .pranayama(let type):
            PranayamaTimerView(pattern: PranayamaSettingsManager.shared.getPattern(for: type))
                .id(type)
        case .meditation(let minutes):
            MeditationTimerView(duration: minutes)
                .id(minutes)
        case nil:
            LandingView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            ContentView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
            ContentView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Ultra 2 (49mm)"))
        }
    }
}
