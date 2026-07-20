import HanabiCore

/// A location fix with its accuracy figures.
public struct LocationSample: Sendable, Equatable {
    public var coordinate: GeodeticCoordinate
    public var horizontalAccuracy: Double
    public var verticalAccuracy: Double

    public init(coordinate: GeodeticCoordinate, horizontalAccuracy: Double, verticalAccuracy: Double) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
    }
}

/// A true-heading reading with its reported accuracy.
public struct HeadingSample: Sendable, Equatable {
    public var trueHeadingDegrees: Double
    public var accuracyDegrees: Double

    public init(trueHeadingDegrees: Double, accuracyDegrees: Double) {
        self.trueHeadingDegrees = trueHeadingDegrees
        self.accuracyDegrees = accuracyDegrees
    }
}

/// Per-frame camera metadata captured with each video frame.
public struct FrameMetadata: Sendable, Equatable {
    public var intrinsics: CameraIntrinsics
    public var lensIdentifier: String
    public var frameRate: Double

    public init(intrinsics: CameraIntrinsics, lensIdentifier: String, frameRate: Double) {
        self.intrinsics = intrinsics
        self.lensIdentifier = lensIdentifier
        self.frameRate = frameRate
    }
}
