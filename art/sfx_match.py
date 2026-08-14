"""Match: a rising two-note chime. Sine bells at E5 then B5, 60 ms apart, each
with a little second-harmonic shimmer and an exponential decay. ~400 ms,
44.1 kHz, mono, 16-bit."""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
DURATION = 0.40
PEAK = 0.30
OUT = os.path.join("App", "Resources", "match.wav")

# (frequency in Hz, start time in seconds, level, decay rate)
NOTES = [
    (659.3, 0.000, 1.00, 9.0),   # E5
    (987.8, 0.060, 0.95, 7.5),   # B5
]


def bell(freq: float, t: float, decay: float) -> float:
    """A sine fundamental with a quieter, faster-fading octave above it."""
    body = math.sin(2.0 * math.pi * freq * t) * math.exp(-t * decay)
    shimmer = 0.18 * math.sin(4.0 * math.pi * freq * t) * math.exp(-t * decay * 2.4)
    return body + shimmer


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
            attack = min(1.0, local / 0.004)
            value += level * attack * bell(freq, local, decay)

        value *= PEAK / 1.9
        if t > DURATION - 0.020:
            value *= (DURATION - t) / 0.020

        frames += struct.pack("<h", int(max(-1.0, min(1.0, value)) * 32767))

    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(bytes(frames))


if __name__ == "__main__":
    main()
