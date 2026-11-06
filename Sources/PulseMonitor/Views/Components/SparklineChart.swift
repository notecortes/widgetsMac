import SwiftUI
import Charts
import PulseCore

public struct SparklineChart: View {
    public let data: [DataPoint]
    public let color: Color
    public var height: CGFloat = 32
    public var showArea: Bool = true

    public init(data: [DataPoint], color: Color, height: CGFloat = 32, showArea: Bool = true) {
        self.data = data
        self.color = color
        self.height = height
        self.showArea = showArea
    }

    public var body: some View {
        if data.isEmpty {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.1))
                .frame(height: height)
        } else {
            Chart {
                ForEach(data) { point in
                    if showArea {
                        AreaMark(
                            x: .value("Hora", point.timestamp),
                            y: .value("Valor", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color.opacity(0.35), color.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                    }

                    LineMark(
                        x: .value("Hora", point.timestamp),
                        y: .value("Valor", point.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: height)
            .drawingGroup()
        }
    }
}
