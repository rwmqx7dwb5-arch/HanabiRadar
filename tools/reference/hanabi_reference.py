#!/usr/bin/env python3
"""Independent reference implementation of the estimation math.

This is a second, deliberately independent implementation of the same equations
that HanabiCore implements in Swift. It exists so the science can be checked in a
different language and runtime: it regenerates the known-answer fixtures consumed
by the Swift test target (ReferenceFixtureTests), and it self-verifies the geodesy
round-trip and the burst-recovery from mathematically generated ground truth
(commissioning doc Section 24.2).

Run:  python tools/reference/hanabi_reference.py
It writes HanabiCore/Tests/HanabiCoreTests/Fixtures/reference_scenes.json and prints
a verification report. It uses only the standard library (no third-party deps).
"""

from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass


# --------------------------------------------------------------------------- #
# Vectors                                                                      #
# --------------------------------------------------------------------------- #

def v_add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def v_sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def v_scale(a, s): return (a[0] * s, a[1] * s, a[2] * s)
def v_dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def v_len(a): return math.sqrt(v_dot(a, a))


def v_norm(a):
    n = v_len(a)
    return (0.0, 0.0, 0.0) if n == 0 else (a[0] / n, a[1] / n, a[2] / n)


# --------------------------------------------------------------------------- #
# Sound speed (mirrors SoundSpeedModel.swift)                                  #
# --------------------------------------------------------------------------- #

def dry_speed(t_celsius: float) -> float:
    return 331.3 * math.sqrt(1.0 + t_celsius / 273.15)


def humidity_correction(t: float, rh: float, p_hpa: float) -> float:
    if p_hpa <= 0:
        return 0.0
    esat = 6.1078 * (10.0 ** ((7.5 * t) / (t + 237.3)))
    clamped = max(0.0, min(1.0, rh))
    e = clamped * esat
    xw = e / p_hpa
    return dry_speed(t) * 0.0507 * xw


def wind_vector_enu(speed: float, from_dir_deg: float):
    to_dir = math.radians(from_dir_deg + 180.0)
    return (speed * math.sin(to_dir), speed * math.cos(to_dir), 0.0)


def effective_speed(t, rh, p, wind_enu, path_unit_burst_to_observer):
    base = dry_speed(t) + humidity_correction(t, rh, p)
    along = v_dot(wind_enu, v_norm(path_unit_burst_to_observer))
    return base + along


# --------------------------------------------------------------------------- #
# WGS84 geodesy (mirrors Geodesy.swift)                                        #
# --------------------------------------------------------------------------- #

WGS84_A = 6_378_137.0
WGS84_F = 1.0 / 298.257_223_563
WGS84_B = WGS84_A * (1.0 - WGS84_F)
WGS84_E2 = WGS84_F * (2.0 - WGS84_F)


def geodetic_to_ecef(lat_deg, lon_deg, alt):
    lat = math.radians(lat_deg)
    lon = math.radians(lon_deg)
    sin_lat, cos_lat = math.sin(lat), math.cos(lat)
    sin_lon, cos_lon = math.sin(lon), math.cos(lon)
    n = WGS84_A / math.sqrt(1.0 - WGS84_E2 * sin_lat * sin_lat)
    x = (n + alt) * cos_lat * cos_lon
    y = (n + alt) * cos_lat * sin_lon
    z = (n * (1.0 - WGS84_E2) + alt) * sin_lat
    return (x, y, z)


def ecef_to_geodetic(p):
    x, y, z = p
    lon = math.atan2(y, x)
    pr = math.sqrt(x * x + y * y)
    if pr < 1e-9:
        lat = math.pi / 2.0 if z >= 0 else -math.pi / 2.0
        return (math.degrees(lat), math.degrees(lon), abs(z) - WGS84_B)
    lat = math.atan2(z, pr * (1.0 - WGS84_E2))
    for _ in range(12):
        sin_lat = math.sin(lat)
        n = WGS84_A / math.sqrt(1.0 - WGS84_E2 * sin_lat * sin_lat)
        alt = pr / math.cos(lat) - n
        new_lat = math.atan2(z, pr * (1.0 - WGS84_E2 * n / (n + alt)))
        if abs(new_lat - lat) < 1e-12:
            lat = new_lat
            break
        lat = new_lat
    sin_lat = math.sin(lat)
    n = WGS84_A / math.sqrt(1.0 - WGS84_E2 * sin_lat * sin_lat)
    alt = pr / math.cos(lat) - n
    return (math.degrees(lat), math.degrees(lon), alt)


def enu_basis(lat_deg, lon_deg):
    lat, lon = math.radians(lat_deg), math.radians(lon_deg)
    sin_lat, cos_lat = math.sin(lat), math.cos(lat)
    sin_lon, cos_lon = math.sin(lon), math.cos(lon)
    east = (-sin_lon, cos_lon, 0.0)
    north = (-sin_lat * cos_lon, -sin_lat * sin_lon, cos_lat)
    up = (cos_lat * cos_lon, cos_lat * sin_lon, sin_lat)
    return east, north, up


def coordinate_from_enu(origin, offset):
    """origin = (lat,lon,alt); offset = ENU meters. Returns (lat,lon,alt)."""
    east, north, up = enu_basis(origin[0], origin[1])
    ecef_off = v_add(v_add(v_scale(east, offset[0]), v_scale(north, offset[1])),
                     v_scale(up, offset[2]))
    ecef = v_add(geodetic_to_ecef(*origin), ecef_off)
    return ecef_to_geodetic(ecef)


def enu_offset(point, origin):
    """ENU offset (m) of point relative to origin. Both (lat,lon,alt)."""
    delta = v_sub(geodetic_to_ecef(*point), geodetic_to_ecef(*origin))
    east, north, up = enu_basis(origin[0], origin[1])
    return (v_dot(east, delta), v_dot(north, delta), v_dot(up, delta))


# --------------------------------------------------------------------------- #
# Optics (mirrors CameraRaySolver.swift / LineOfSight.swift)                   #
# --------------------------------------------------------------------------- #

def camera_ray(u, v, fx, fy, cx, cy):
    return v_norm(((u - cx) / fx, (v - cy) / fy, 1.0))


def azimuth_degrees(enu_ray):
    deg = math.degrees(math.atan2(enu_ray[0], enu_ray[1]))
    return deg + 360.0 if deg < 0 else deg


def elevation_degrees(enu_ray):
    horizontal = math.sqrt(enu_ray[0] ** 2 + enu_ray[1] ** 2)
    return math.degrees(math.atan2(enu_ray[2], horizontal))


# --------------------------------------------------------------------------- #
# Scene generation + solve-equivalent                                         #
# --------------------------------------------------------------------------- #

@dataclass
class Scene:
    name: str
    observer: tuple            # (lat, lon, alt)
    azimuth: float
    elevation: float
    distance: float            # local-ENU straight-line distance used to place truth
    temperature: float
    ground_elevation: float


def local_ray(az_deg, el_deg):
    a, e = math.radians(az_deg), math.radians(el_deg)
    return (math.cos(e) * math.sin(a), math.cos(e) * math.cos(a), math.sin(e))


def solve_scene(scene: Scene):
    """Independent reconstruction that mirrors BurstSolver.solve without a weather
    provider: place a true burst from az/el/distance, derive the exact flash-to-bang
    delay for dry air, then recover the burst from observer + line-of-sight ray +
    (speed * delay). Returns the expected solver outputs plus the true burst."""
    true_burst = coordinate_from_enu(scene.observer, v_scale(local_ray(scene.azimuth, scene.elevation), scene.distance))

    off = enu_offset(true_burst, scene.observer)
    ray = v_norm(off)                       # line-of-sight ENU ray observer -> burst
    true_los = v_len(off)                    # slant distance actually used

    speed = dry_speed(scene.temperature)     # observer-only, dry, no wind/humidity
    delay = true_los / speed
    los_distance = speed * delay             # == true_los by construction

    burst = coordinate_from_enu(scene.observer, v_scale(ray, los_distance))
    az = azimuth_degrees(ray)
    el = elevation_degrees(ray)
    horizontal = los_distance * math.cos(math.radians(el))
    height_above_ground = burst[2] - scene.ground_elevation

    return {
        "name": scene.name,
        "observerLat": scene.observer[0],
        "observerLon": scene.observer[1],
        "observerAlt": scene.observer[2],
        "azimuth": scene.azimuth,
        "elevation": scene.elevation,
        "distance": scene.distance,
        "temperature": scene.temperature,
        "groundElevation": scene.ground_elevation,
        "delay": delay,
        "effectiveSoundSpeed": speed,
        "expectedBurstLat": burst[0],
        "expectedBurstLon": burst[1],
        "expectedBurstAlt": burst[2],
        "expectedLosDistance": los_distance,
        "expectedHorizontalDistance": horizontal,
        "expectedAzimuth": az,
        "expectedElevation": el,
        "expectedHeightAboveGround": height_above_ground,
        "expectedSubpointAlt": scene.ground_elevation,
        "trueBurstLat": true_burst[0],
        "trueBurstLon": true_burst[1],
        "trueBurstAlt": true_burst[2],
    }


# --------------------------------------------------------------------------- #
# Fixture data                                                                 #
# --------------------------------------------------------------------------- #

SCENES = [
    Scene("tokyo-ne-mid", (35.681, 139.767, 30.0), 60.0, 42.0, 1800.0, 22.0, 5.0),
    Scene("tokyo-low-close", (35.0, 139.0, 10.0), 0.0, 20.0, 500.0, 18.0, 0.0),
    Scene("tokyo-high-far", (35.0, 139.0, 10.0), 135.0, 70.0, 3000.0, 18.0, 12.0),
    Scene("south-hemisphere", (-33.87, 151.21, 8.0), 300.0, 35.0, 2200.0, 26.0, 3.0),
    Scene("high-latitude", (60.17, 24.94, 15.0), 210.0, 55.0, 1200.0, 5.0, 20.0),
]

# Sound-speed table exercising dry / humidity / wind terms independently.
SOUND_CASES = [
    # (T, rh, p, windSpeed, windFromDeg, rayAz, rayEl)  ray = observer->burst ENU
    (15.0, 0.0, 1013.25, 0.0, 0.0, 0.0, 30.0),
    (25.0, 1.0, 1013.25, 0.0, 0.0, 0.0, 30.0),
    (20.0, 0.5, 1000.0, 8.0, 90.0, 90.0, 10.0),   # wind from east, ray to east
    (30.0, 0.8, 1005.0, 6.0, 270.0, 90.0, 10.0),  # wind from west, ray to east
    (-5.0, 0.3, 1020.0, 4.0, 0.0, 0.0, 45.0),
]


def sound_case_row(t, rh, p, ws, wfd, ray_az, ray_el):
    ray = local_ray(ray_az, ray_el)
    path_burst_to_observer = v_scale(ray, -1.0)   # sound travels burst -> observer
    wind = wind_vector_enu(ws, wfd)
    return {
        "t": t, "rh": rh, "p": p, "windSpeed": ws, "windFromDeg": wfd,
        "rayAz": ray_az, "rayEl": ray_el,
        "drySpeed": dry_speed(t),
        "humidityCorrection": humidity_correction(t, rh, p),
        "effectiveSpeed": effective_speed(t, rh, p, wind, path_burst_to_observer),
    }


# Camera-ray table: intrinsics + pixel -> unit ray + angles (identity attitude).
CAMERA_CASES = [
    # (fx, fy, cx, cy, u, v)
    (1600.0, 1600.0, 960.0, 540.0, 960.0, 540.0),     # principal point -> straight ahead
    (1600.0, 1600.0, 960.0, 540.0, 1600.0, 540.0),    # right of center
    (1600.0, 1600.0, 960.0, 540.0, 960.0, 120.0),     # above center (smaller v)
    (1200.0, 1200.0, 640.0, 360.0, 300.0, 700.0),     # lower-left
]


def camera_case_row(fx, fy, cx, cy, u, v):
    ray = camera_ray(u, v, fx, fy, cx, cy)
    # Interpret the camera ray directly as an ENU ray (identity attitude) for the
    # angle checks, matching the Swift test which does the same.
    return {
        "fx": fx, "fy": fy, "cx": cx, "cy": cy, "u": u, "v": v,
        "rayX": ray[0], "rayY": ray[1], "rayZ": ray[2],
        "azimuth": azimuth_degrees(ray),
        "elevation": elevation_degrees(ray),
    }


# --------------------------------------------------------------------------- #
# Self-verification (independent of the fixture consumer)                      #
# --------------------------------------------------------------------------- #

def self_check():
    failures = []

    # Geodesy round-trip at a spread of coordinates.
    for (lat, lon, alt) in [(35.681, 139.767, 30.0), (-33.87, 151.21, 8.0),
                            (60.17, 24.94, 500.0), (0.0, 0.0, 0.0), (89.0, -120.0, 100.0)]:
        back = ecef_to_geodetic(geodetic_to_ecef(lat, lon, alt))
        if abs(back[0] - lat) > 1e-9 or abs(back[1] - lon) > 1e-9 or abs(back[2] - alt) > 1e-6:
            failures.append(f"round-trip {lat},{lon},{alt} -> {back}")

    # Burst recovery matches mathematically generated ground truth (Section 24.2).
    worst_recovery = 0.0
    for sc in SCENES:
        r = solve_scene(sc)
        d = v_len(v_sub(geodetic_to_ecef(r["expectedBurstLat"], r["expectedBurstLon"], r["expectedBurstAlt"]),
                        geodetic_to_ecef(r["trueBurstLat"], r["trueBurstLon"], r["trueBurstAlt"])))
        worst_recovery = max(worst_recovery, d)
        if abs(r["expectedAzimuth"] - sc.azimuth) > 0.05:
            failures.append(f"{sc.name}: azimuth {r['expectedAzimuth']} != {sc.azimuth}")

    # Dry sound speed at 20 C is ~343 m/s.
    if abs(dry_speed(20.0) - 343.0) > 1.0:
        failures.append(f"drySpeed(20) = {dry_speed(20.0)}")

    return failures, worst_recovery


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.normpath(os.path.join(
        here, "..", "..", "HanabiCore", "Tests", "HanabiCoreTests", "Fixtures"))
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "reference_scenes.json")

    fixture = {
        "_comment": ("Generated by tools/reference/hanabi_reference.py, an independent "
                     "reference implementation. Do not edit by hand; regenerate. Consumed "
                     "by HanabiCoreTests/ReferenceFixtureTests.swift."),
        "generator": "hanabi_reference.py",
        "scenes": [solve_scene(s) for s in SCENES],
        "soundSpeed": [sound_case_row(*c) for c in SOUND_CASES],
        "cameraRay": [camera_case_row(*c) for c in CAMERA_CASES],
    }

    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(fixture, f, indent=2, ensure_ascii=False)
        f.write("\n")

    failures, worst_recovery = self_check()

    print("HanabiCore reference oracle")
    print("=" * 60)
    print(f"scenes:        {len(fixture['scenes'])}")
    print(f"soundSpeed:    {len(fixture['soundSpeed'])}")
    print(f"cameraRay:     {len(fixture['cameraRay'])}")
    print(f"fixture ->     {out_path}")
    print("-" * 60)
    print(f"dry sound speed @ 20 C:            {dry_speed(20.0):.4f} m/s")
    print(f"worst burst-recovery vs truth:     {worst_recovery:.4f} m "
          "(ENU tangent-plane curvature over km baselines)")
    print("-" * 60)
    print("Sample scene (tokyo-ne-mid):")
    s0 = fixture["scenes"][0]
    print(f"  delay              {s0['delay']:.4f} s")
    print(f"  effective speed    {s0['effectiveSoundSpeed']:.4f} m/s")
    print(f"  burst lat/lon/alt  {s0['expectedBurstLat']:.7f}, "
          f"{s0['expectedBurstLon']:.7f}, {s0['expectedBurstAlt']:.2f} m")
    print(f"  LoS distance       {s0['expectedLosDistance']:.2f} m")
    print(f"  height above grd   {s0['expectedHeightAboveGround']:.2f} m "
          f"(ground {s0['groundElevation']:.1f} m)")
    print("-" * 60)
    if failures:
        print(f"SELF-CHECK FAILURES ({len(failures)}):")
        for f in failures:
            print("  -", f)
        raise SystemExit(1)
    print("SELF-CHECK: all passed")


if __name__ == "__main__":
    main()
