import SwiftUI

struct RootFlowView: View {
    @StateObject private var coordinator = WebCoordinator()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            WebContainerView()

            if coordinator.appState == .idle {
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        Task { await coordinator.start() }
                    }
            }
            if coordinator.appState == .loading {
                LoadingView()
                    .transition(.opacity)
            }
            if coordinator.appState == .showGame {
                GameView()
                    .transition(.opacity)
            }
            // .showWeb: только WebContainerView, без оверлеев
        }
        .animation(.easeInOut(duration: 0.22), value: coordinator.appState)
        .environmentObject(coordinator)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootFlowView()
}
