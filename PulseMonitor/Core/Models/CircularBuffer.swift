import Foundation

/// A fixed-capacity ring buffer for real-time metric sparklines and history
public struct CircularBuffer<Element: Sendable>: Sendable {
    private var elements: [Element]
    private var writeIndex: Int = 0
    public let capacity: Int
    private var isFull: Bool = false

    public init(capacity: Int = 60) {
        self.capacity = max(1, capacity)
        self.elements = []
        self.elements.reserveCapacity(capacity)
    }

    public mutating func append(_ element: Element) {
        if elements.count < capacity {
            elements.append(element)
        } else {
            elements[writeIndex] = element
            writeIndex = (writeIndex + 1) % capacity
            isFull = true
        }
    }

    /// Returns values in chronological order (oldest to newest)
    public var values: [Element] {
        if !isFull {
            return elements
        }
        let tail = elements[writeIndex..<elements.count]
        let head = elements[0..<writeIndex]
        return Array(tail + head)
    }

    public var count: Int {
        elements.count
    }

    public var isEmpty: Bool {
        elements.isEmpty
    }

    public var last: Element? {
        if elements.isEmpty { return nil }
        if !isFull { return elements.last }
        let idx = (writeIndex - 1 + capacity) % capacity
        return elements[idx]
    }

    public mutating func clear() {
        elements.removeAll(keepingCapacity: true)
        writeIndex = 0
        isFull = false
    }
}

extension CircularBuffer: Codable where Element: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let array = try container.decode([Element].self)
        self.init(capacity: max(60, array.count))
        for item in array {
            self.append(item)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}
