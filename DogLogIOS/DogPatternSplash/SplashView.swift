import SwiftUI

/// Post-launch splash (visas direkt efter statiska Launch Screen).
/// Kör denna som root view i din App och navigera vidare efter onAppear.
struct SplashView: View {
    @State private var fadeIn = false
    @State private var scale: CGFloat = 0.92
    @State private var showGlow = false
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.12, green: 0.15, blue: 0.22),
                                                       Color(red: 0.06, green: 0.09, blue: 0.16)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 18) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(radius: showGlow ? 24 : 0)
                    .scaleEffect(scale)
                    .opacity(fadeIn ? 1 : 0)
                    .accessibilityLabel("HundMönster AI logotyp")
                
                Text("HundMönster AI")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.96))
                    .opacity(fadeIn ? 1 : 0)
                
                Text("AI som ser mönstren i din hunds vardag")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(fadeIn ? 1 : 0)
            }
            .padding(32)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                fadeIn = true
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                showGlow = true
            }
        }
    }
}

#Preview {
    SplashView()
}
