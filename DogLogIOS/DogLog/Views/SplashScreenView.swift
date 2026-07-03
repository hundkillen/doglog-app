import SwiftUI

// Adds a subtitle under DogLog on splash
struct SplashScreenView_PatchedSubtitle: View {
    let onTapToContinue: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            // Reuse original splash if available
            SplashScreenView(onTapToContinue: onTapToContinue)
                .overlay(alignment: .bottom) {
                    Text("The Barkley method")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 40)
                }
        }
    }
}

import SwiftUI

struct SplashScreenView: View {
    let onTapToContinue: () -> Void
    
    @State private var isAnimating = false
    @State private var logoOpacity: Double = 0.0
    @State private var showTapPrompt = false
    @State private var isFadingOut = false
    
    var body: some View {
        ZStack {
            // Full screen splash image
            Image("splash_logo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .opacity(logoOpacity)
                .animation(.easeIn(duration: 1.0), value: logoOpacity)
            
            // Optional overlay for text (with semi-transparent background)
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    // App name with background
                    Text("splash.doglog".localized)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.5), value: isAnimating)
                    
                    // Tagline with background
                    Text("splash.subtitle".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.8), value: isAnimating)
                    
                    // Tap to continue prompt
                    if showTapPrompt {
                        Text("splash.tap_continue".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .opacity(showTapPrompt ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showTapPrompt)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(isAnimating ? 0.8 : 0.0)
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimating)
                )
                
                Spacer().frame(height: 80)
            }
        }
        .opacity(isFadingOut ? 0.0 : 1.0)
        .animation(.easeOut(duration: 0.6), value: isFadingOut)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.6)) {
                isFadingOut = true
            }
            
            // Call the completion after fade animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onTapToContinue()
            }
        }
        .onAppear {
            withAnimation {
                logoOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isAnimating = true
                }
            }
            
            // Show tap prompt after all animations are done
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeIn(duration: 0.5)) {
                    showTapPrompt = true
                }
            }
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView(onTapToContinue: {})
    }
}