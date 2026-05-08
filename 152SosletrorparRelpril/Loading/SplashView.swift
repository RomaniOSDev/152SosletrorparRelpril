import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            Image("mainlabel")
                .resizable()
                .scaledToFit()
                .padding(32)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    SplashView()
        .preferredColorScheme(.dark)
}
