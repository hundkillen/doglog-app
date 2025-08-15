import SwiftUI
import SwiftData

@main
struct DogLogApp: App {
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else {
                ContentView()
            }
        }
        .modelContainer(for: [Dog.self, Activity.self, CustomActivity.self, DailyRating.self])
    }
}