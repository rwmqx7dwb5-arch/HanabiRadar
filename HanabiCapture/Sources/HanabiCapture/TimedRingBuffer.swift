/// A fixed-capacity, time-ordered ring buffer. Appends are assumed to arrive in
/// non-decreasing time order (as sensor samples do per source). When full, the oldest
/// element is overwritten, so memory stays bounded (the app keeps ~30 s of history).
public struct TimedRingBuffer<Value: Sendable>: Sendable {
    private var storage: [Timed<Value>?]
    private var head: Int = 0
    public private(set) var count: Int = 0
    public let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public mutating func append(_ item: Timed<Value>) {
        if count < capacity {
            storage[(head + count) % capacity] = item
            count += 1
        } else {
            storage[head] = item
            head = (head + 1) % capacity
        }
    }

    /// Logical element at `index` in time order (0 == oldest).
    public func element(at index: Int) -> Timed<Value> {
        precondition(index >= 0 && index < count, "index out of range")
        return storage[(head + index) % capacity]!
    }

    public var orderedItems: [Timed<Value>] {
        (0..<count).map { element(at: $0) }
    }

    public var oldest: Timed<Value>? { count > 0 ? element(at: 0) : nil }
    public var newest: Timed<Value>? { count > 0 ? element(at: count - 1) : nil }

    /// The samples immediately at-or-before and at-or-after `t`.
    public func bracketing(_ t: CaptureTimestamp) -> (before: Timed<Value>?, after: Timed<Value>?) {
        guard count > 0 else { return (nil, nil) }
        let firstGE = firstIndex { !($0 < t) }   // first time >= t
        let firstGT = firstIndex { t < $0 }       // first time  > t
        let after = firstGE < count ? element(at: firstGE) : nil
        let beforeIndex = firstGT - 1
        let before = beforeIndex >= 0 ? element(at: beforeIndex) : nil
        return (before, after)
    }

    /// Drops elements older than `t` (time < t).
    public mutating func prune(olderThan t: CaptureTimestamp) {
        while let oldest = oldest, oldest.time < t {
            head = (head + 1) % capacity
            count -= 1
        }
    }

    // First logical index whose timestamp satisfies the monotonic predicate
    // (false...false, true...true).
    private func firstIndex(_ predicate: (CaptureTimestamp) -> Bool) -> Int {
        var low = 0
        var high = count
        while low < high {
            let mid = (low + high) / 2
            if predicate(element(at: mid).time) {
                high = mid
            } else {
                low = mid + 1
            }
        }
        return low
    }
}
