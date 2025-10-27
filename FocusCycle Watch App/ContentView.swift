import SwiftUI

struct ContentView: View {
    var body: some View {
        LandingView()
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
