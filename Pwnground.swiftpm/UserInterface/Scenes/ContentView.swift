import SwiftUI

struct ContentView: View {
    @State private var contentDidLoad = false

    var body: some View {
        NavigationView {
            ZStack {
                Content()
                SplashScreen()
            }.colorScheme(.light)
        }.showNotification(NotificationSubject())
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear(perform: hideSplashScreen)
    }
    
    @ViewBuilder
    private func Content() -> some View {
        if contentDidLoad {
            WelcomeScreen()
        }
    }
    
    @ViewBuilder
    private func SplashScreen() -> some View {
        if !contentDidLoad {
            Color.black
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
                .ignoresSafeArea()
        }
    }
    
    private func hideSplashScreen() {
        DispatchQueue.main.async {
            withAnimation { contentDidLoad = true }
        }
    }
}
