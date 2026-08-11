"""Convert the first seconds of a video into 320x200 VGA boot frames."""
import argparse
import subprocess
from pathlib import Path

PALETTE = (
    (0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170),
    (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
    (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255),
    (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255),
)


def nearest_colour(r: int, g: int, b: int) -> int:
    return min(range(16), key=lambda i: sum((v - p) ** 2 for v, p in zip((r, g, b), PALETTE[i])))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--seconds", type=float, default=4.0)
    parser.add_argument("--fps", type=int, default=10)
    args = parser.parse_args()

    frame_count = round(args.seconds * args.fps)
    command = [
        "ffmpeg", "-v", "error", "-ss", "0", "-t", str(args.seconds),
        "-i", args.input, "-vf",
        f"fps={args.fps},scale=320:144:flags=lanczos,pad=320:200:0:28:black",
        "-frames:v", str(frame_count), "-f", "rawvideo", "-pix_fmt", "rgb24", "-",
    ]
    raw = subprocess.check_output(command)
    expected = frame_count * 320 * 200 * 3
    if len(raw) != expected:
        raise SystemExit(f"expected {expected} RGB bytes, received {len(raw)}")

    converted = bytearray()
    for offset in range(0, len(raw), 3):
        converted.append(nearest_colour(raw[offset], raw[offset + 1], raw[offset + 2]))
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_bytes(converted)
    print(f"wrote {frame_count} VGA frames ({len(converted)} bytes)")


if __name__ == "__main__":
    main()
