import Foundation

/// A generic timestamped point for Swift Charts and sparklines
public struct DataPoint: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let value: Double

    public init(id: UUID = UUID(), timestamp: Date = Date(), value: Double) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
    }
}
