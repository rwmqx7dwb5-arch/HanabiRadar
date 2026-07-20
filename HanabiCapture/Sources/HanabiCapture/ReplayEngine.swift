import HanabiCore

/// One recorded sensor sample.
public enum RecordedSample: Sendable {
    case attitude(Timed<Quaternion>)
    case location(Timed<LocationSample>)
    case heading(Timed<HeadingSample>)
    case audioLevel(Timed<Double>)
    case routeChange(CaptureTimestamp, AudioRouteChange)

    public var time: CaptureTimestamp {
        switch self {
        case .attitude(let timed): return timed.time
        case .location(let timed): return timed.time
        case .heading(let timed): return timed.time
        case .audioLevel(let timed): return timed.time
        case .routeChange(let time, _): return time
        }
    }
}

/// A recorded session: the samples needed to reproduce a measurement deterministically.
public struct RecordedSession: Sendable {
    public var samples: [RecordedSample]

    public init(samples: [RecordedSample]) {
        self.samples = samples
    }
}

/// Replays a recorded session through a sink in strict time order, so an algorithm can
/// be re-run against the same data for regression testing (Section 23).
public struct ReplayEngine: Sendable {
    public init() {}

    public func replay(_ session: RecordedSession, into sink: CaptureSink) {
        for sample in session.samples.sorted(by: { $0.time < $1.time }) {
            switch sample {
            case .attitude(let timed): sink.ingest(attitude: timed)
            case .location(let timed): sink.ingest(location: timed)
            case .heading(let timed): sink.ingest(heading: timed)
            case .audioLevel(let timed): sink.ingest(audioLevel: timed)
            case .routeChange(let time, let change): sink.ingest(routeChange: change, at: time)
            }
        }
    }
}
