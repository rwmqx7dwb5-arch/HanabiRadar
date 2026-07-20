/// A value tagged with its time on the common capture axis.
public struct Timed<Value: Sendable>: Sendable {
    public var time: CaptureTimestamp
    public var value: Value

    public init(time: CaptureTimestamp, value: Value) {
        self.time = time
        self.value = value
    }
}
