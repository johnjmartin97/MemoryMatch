"""Card flip: a soft paper snap. Filtered noise with a very fast decay and no
tonal pitch, so it can fire sixty times in a game without becoming a tune.
~120 ms, 44.1 kHz, mono, 16-bit."""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
DURATION = 0.12
PEAK = 0.22  # quiet on purpose; this plays constantly
OUT = os.path.join("App", "Resources", "flip.wav")


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    n = int(SAMPLE_RATE * DURATION)
    rng = random.Random(4711)

    # One-pole high-pass then one-pole low-pass over white noise gives the dry
    # mid-band rustle of card stock; the band moves down as the sound decays.
    hp_prev_in = 0.0
    hp_prev_out = 0.0
    lp_prev = 0.0
    frames = bytearray()

    for i in range(n):
        t = i / SAMPLE_RATE
        x = rng.uniform(-1.0, 1.0)

        # High-pass at ~900 Hz: strips the thud.
        a = math.exp(-2.0 * math.pi * 900.0 / SAMPLE_RATE)
        hp = a * (hp_prev_out + x - hp_prev_in)
        hp_prev_in, hp_prev_out = x, hp

        # Low-pass sweeping 6.5 kHz down to 1.8 kHz across the burst.
        cutoff = 6500.0 * math.exp(-t * 11.0) + 1800.0
        b = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
        lp_prev += b * (hp - lp_prev)

        # 2 ms attack, then a sharp exponential tail.
        attack = min(1.0, t / 0.002)
        env = attack * math.exp(-t * 46.0)
        # Short fade at the very end so the file ends at true zero.
        if t > DURATION - 0.006:
            env *= (DURATION - t) / 0.006

        sample = lp_prev * env * PEAK
        frames += struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767))

    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(bytes(frames))


if __name__ == "__main__":
    main()
