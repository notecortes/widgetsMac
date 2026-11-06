import SwiftUI

public struct CircularGaugeView: View {
    public let value: Double
    public let maxValue: Double
    public let title: String
    public let subtitle: String
    public let color: Color
    public var size: CGFloat = 84

    public init(
        value: Double,
        maxValue: Double = 100.0,
        title: String,
        subtitle: String,
        color: Color,
        size: CGFloat = 84
    ) {
        self.value = value
        self.maxValue = maxValue
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.size = size
    }

    private var progress: Double {
        guard maxValue > 0 else { return 0.0 }
        return min(1.0, max(0.0, value / maxValue))
    }

    public var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 7)

                // Fill Track
                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.7), color],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

                VStack(spacing: 1) {
                    Text(title)
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: size * 0.12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)
        }
    }
}
