import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Image("mainlabel")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .accessibilityHidden(true)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)
            }
            .padding(32)
        }
    }
}

#Preview {
    LoadingView()
        .preferredColorScheme(.dark)
}
