import SwiftUI

struct DrEliasAvatarView: View {
    let isThinking: Bool
    let size: AvatarSize
    let showName: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    enum AvatarSize {
        case small, medium, large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 60
            case .large: return 80
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .subheadline
            case .large: return .headline
            }
        }
    }
    
    init(isThinking: Bool = false, size: AvatarSize = .medium, showName: Bool = true) {
        self.isThinking = isThinking
        self.size = size
        self.showName = showName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with thinking animation
            ZStack {
                // Glow effect when thinking
                if isThinking {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(glowOpacity),
                                    Color.blue.opacity(0.1),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: size.dimension * 0.3,
                                endRadius: size.dimension * 0.8
                            )
                        )
                        .frame(width: size.dimension * 1.4, height: size.dimension * 1.4)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: glowOpacity
                        )
                }
                
                // Main avatar circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                    
                    Circle()
                        .stroke(
                            isThinking ? 
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                gradient: Gradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                    
                    // Dr. Elias image
                    if let drEliasImage = UIImage(named: "dr_elias") {
                        Image(uiImage: drEliasImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.dimension - 6, height: size.dimension - 6)
                            .clipShape(Circle())
                    } else {
                        // Fallback icon
                        Text("🧑‍⚕️")
                            .font(.system(size: size.dimension * 0.5))
                    }
                    
                    // Thinking overlay with dots
                    if isThinking {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                ThinkingDotsView()
                            )
                    }
                }
                .frame(width: size.dimension, height: size.dimension)
                .scaleEffect(pulseScale)
                .animation(
                    isThinking ? 
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : 
                        .easeInOut(duration: 0.3),
                    value: pulseScale
                )
            }
            
            // Name and status
            if showName {
                VStack(alignment: .leading, spacing: 2) {
                    Text("dr.dr_elias".localized)
                        .font(size.fontSize)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if isThinking {
                        HStack(spacing: 4) {
                            Text("dr.analyzing".localized)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .italic()
                            
                            ThinkingDotsView(size: .mini)
                        }
                        .transition(.opacity)
                    } else {
                        Text("dr.ai_expert".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isThinking)
            }
        }
        .onAppear {
            if isThinking {
                pulseScale = 1.05
                glowOpacity = 0.6
            }
        }
        .onChange(of: isThinking) { newValue in
            if newValue {
                pulseScale = 1.05
                glowOpacity = 0.6
            } else {
                pulseScale = 1.0
                glowOpacity = 0.3
            }
        }
    }
}

struct ThinkingDotsView: View {
    let size: DotSize
    @State private var animationPhase: Int = 0
    
    enum DotSize {
        case normal, mini
        
        var dotSize: CGFloat {
            switch self {
            case .normal: return 4
            case .mini: return 2
            }
        }
        
        var spacing: CGFloat {
            switch self {
            case .normal: return 2
            case .mini: return 1
            }
        }
    }
    
    init(size: DotSize = .normal) {
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: size.spacing) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: size.dotSize, height: size.dotSize)
                    .scaleEffect(animationPhase == index ? 1.5 : 0.8)
                    .opacity(animationPhase == index ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: false),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}

// MARK: - Convenience Views

struct DrEliasThinkingView: View {
    let message: String
    
    init(_ message: String = "Analyzing patterns...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            DrEliasAvatarView(isThinking: true, size: .large, showName: false)
            
            VStack(spacing: 8) {
                Text("dr.dr_elias".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
}

struct DrEliasResultHeaderView: View {
    let showProfileStyle: Bool
    
    init(profileStyle: Bool = false) {
        self.showProfileStyle = profileStyle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            DrEliasAvatarView(isThinking: false, size: .medium, showName: !showProfileStyle)
            
            if showProfileStyle {
                VStack(alignment: .leading, spacing: 4) {
                    Text("dr.dr_elias".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("dr.ai_dog_behaviorist".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("dr.expert_analysis_complete".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview

struct DrEliasAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Normal state
            DrEliasAvatarView(isThinking: false, size: .large, showName: true)
            
            // Thinking state
            DrEliasAvatarView(isThinking: true, size: .large, showName: true)
            
            // Thinking view
            DrEliasThinkingView("ai.analyzing".localized)
            
            // Result header
            DrEliasResultHeaderView(profileStyle: true)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}