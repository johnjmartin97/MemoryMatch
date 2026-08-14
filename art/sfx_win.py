"""Win: a short major arpeggio, C5-E5-G5-C6 at 140 ms spacing, in the same soft
bell voice as the match chime, with the top note ringing out to silence. Warm
and brief -- you can put the phone down mid-tail and miss nothing. ~1.2 s,
44.1 kHz, mono, 16-bit."""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
DURATION = 1.20
PEAK = 0.32
OUT = os.path.join("App", "Resources", "win.wav")

# (frequency in Hz, start time in seconds, level, decay rate)
NOTES = [
    (523.3, 0.000, 0.85, 4.2),   # C5
    (659.3, 0.140, 0.85, 4.0),   # E5
    (784.0, 0.280, 0.85, 3.8),   # G5
    (1046.5, 0.420, 1.00, 2.6),  # C6, rings out
]


def bell(freq: float, t: float, decay: float) -> float:
    body = math.sin(2.0 * math.pi * freq * t) * math.exp(-t * decay)
    shimmer = 0.16 * math.sin(4.0 * math.pi * freq * t) * math.exp(-t * decay * 2.4)
    third = 0.07 * math.sin(6.0 * math.pi * freq * t) * math.exp(-t * decay * 3.6)
    return body + shimmer + third


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    n = int(SAMPLE_RATE * DURATION)
    frames = bytearray()

    for i in range(n):
        t = i / SAMPLE_RATE
        value = 0.0
        for freq, start, level, decay in NOTES:
            if t < start:
                continue
            local = t - start
            attack = min(1.0, local / 0.005)
            value += level * attack * bell(freq, local, decay)

        value *= PEAK / 2.6
        # Long fade so the tail lands on true silence rather than a click.
        if t > DURATION - 0.120:
            value *= (DURATION - t) / 0.120

        frames += struct.pack("<h", int(max(-1.0, min(1.0, value)) * 32767))

    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(bytes(frames))


if __name__ == "__main__":
    main()
