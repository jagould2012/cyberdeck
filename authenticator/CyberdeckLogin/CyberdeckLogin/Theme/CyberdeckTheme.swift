import SwiftUI

/// Cyberdeck theme colors and styling
enum CyberdeckTheme {
    // MARK: - Colors
    
    /// Matrix green - primary accent color
    static let matrixGreen = Color(red: 0.0, green: 0.85, blue: 0.3)
    
    /// Darker green for secondary elements
    static let darkGreen = Color(red: 0.0, green: 0.5, blue: 0.2)
    
    /// Glow green for highlights
    static let glowGreen = Color(red: 0.4, green: 1.0, blue: 0.4)
    
    /// Background dark
    static let backgroundDark = Color(red: 0.02, green: 0.02, blue: 0.02)
    
    /// Card/surface background with transparency
    static let cardBackground = Color.black.opacity(0.7)
    
    /// Text colors
    static let primaryText = Color.white
    static let secondaryText = Color.gray
    
    // MARK: - Gradients
    
    static let greenGradient = LinearGradient(
        colors: [darkGreen, matrixGreen],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let glowGradient = LinearGradient(
        colors: [matrixGreen, glowGreen],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - View Modifiers

struct MatrixBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Background image
            Image("Background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Dark overlay for readability
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            content
        }
    }
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(CyberdeckTheme.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(CyberdeckTheme.matrixGreen.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

struct MatrixButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPrimary ? CyberdeckTheme.matrixGreen : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CyberdeckTheme.matrixGreen, lineWidth: isPrimary ? 0 : 2)
                    )
            )
            .foregroundColor(isPrimary ? .black : CyberdeckTheme.matrixGreen)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func matrixBackground() -> some View {
        modifier(MatrixBackgroundModifier())
    }
    
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
    
    func matrixButtonStyle(isPrimary: Bool = true) -> some View {
        buttonStyle(MatrixButtonStyle(isPrimary: isPrimary))
    }
}
