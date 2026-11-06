import SwiftUI

public enum Theme {
    // Brand Metric Colors (refined, vibrant yet subtle)
    public static let cpu = Color(red: 0.18, green: 0.52, blue: 0.98)       // Vivid Blue
    public static let gpu = Color(red: 0.45, green: 0.35, blue: 0.92)       // Indigo / Violet
    public static let memory = Color(red: 0.68, green: 0.32, blue: 0.88)    // Purple
    public static let disk = Color(red: 0.98, green: 0.56, blue: 0.18)      // Warm Orange
    public static let network = Color(red: 0.20, green: 0.78, blue: 0.45)   // Emerald Green
    public static let networkUpload = Color(red: 0.15, green: 0.70, blue: 0.85) // Cyan
    
    public static func battery(percentage: Double, isCharging: Bool) -> Color {
        if isCharging {
            return Color.green
        }
        if percentage <= 15.0 {
            return Color.red
        } else if percentage <= 30.0 {
            return Color.orange
        } else {
            return Color.green
        }
    }

    public static func thermal(temperature: Double?) -> Color {
        guard let t = temperature else { return Color.green }
        if t >= 85.0 {
            return Color.red
        } else if t >= 70.0 {
            return Color.orange
        } else {
            return Color.green
        }
    }

    // Liquid Glass Container styling
    public static let cornerRadius: CGFloat = 16.0
}

public struct LiquidGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = Theme.cornerRadius
    @Environment(\.colorScheme) var colorScheme

    public func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.45),
                                        Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 8, x: 0, y: 4)
            )
    }
}

public extension View {
    func liquidGlassCard(cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }
}
