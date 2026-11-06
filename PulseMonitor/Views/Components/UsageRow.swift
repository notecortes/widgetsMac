import SwiftUI
// import PulseCore

public struct UsageRow: View {
    public let icon: String
    public let label: String
    public let value: String
    public let color: Color
    public var progress: Double? = nil
    public var sparklineData: [DataPoint]? = nil

    public init(
        icon: String,
        label: String,
        value: String,
        color: Color,
        progress: Double? = nil,
        sparklineData: [DataPoint]? = nil
    ) {
        self.icon = icon
        self.label = label
        self.value = value
        self.color = color
        self.progress = progress
        self.sparklineData = sparklineData
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20, alignment: .center)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)

            if let spark = sparklineData, !spark.isEmpty {
                SparklineChart(data: spark, color: color, height: 22, showArea: true)
                    .frame(width: 75)
            } else if let p = progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(color.opacity(0.18))
                            .frame(height: 6)

                        Capsule()
                            .fill(color)
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.0, max(0.0, p / 100.0)))), height: 6)
                    }
                }
                .frame(width: 75, height: 6)
            }
        }
        .padding(.vertical, 4)
    }
}
