/// Turns a pixel-buffer point into a unit ray in CAMERA coordinates.
public enum CameraRaySolver {

    /// Unit ray in camera coordinates for a pixel-buffer point.
    ///
    /// Camera convention: +x right, +y down, +z forward (into the scene). The ray is
    /// `normalize( K^-1 [u, v, 1]^T ) = normalize( ((u - cx) / fx, (v - cy) / fy, 1) )`.
    public static func cameraRay(from point: ImagePoint, intrinsics k: CameraIntrinsics) -> Vector3 {
        let dx = (point.u - k.cx) / k.fx
        let dy = (point.v - k.cy) / k.fy
        return Vector3(dx, dy, 1.0).normalized()
    }
}
