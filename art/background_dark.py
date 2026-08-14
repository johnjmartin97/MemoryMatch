"""Dark-mode backdrop: #1A1F26 at the top down to #0F1318, with a cool overhead
glow, a soft vignette and fine dithered grain. Dark gradients band worst, so the
noise here is slightly stronger than in the light variant."""

import os

import numpy as np
from PIL import Image

WIDTH, HEIGHT = 1179, 2556
OUT = os.path.join(
    "App", "Assets.xcassets", "Background.imageset", "background-dark.png"
)

TOP = np.array([0x1A, 0x1F, 0x26], dtype=np.float64)
BOTTOM = np.array([0x0F, 0x13, 0x18], dtype=np.float64)


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    ys = np.linspace(0.0, 1.0, HEIGHT)[:, None]
    xs = np.linspace(0.0, 1.0, WIDTH)[None, :]

    ramp = (ys ** 1.15)[..., None]
    rgb = TOP[None, None, :] + (BOTTOM - TOP)[None, None, :] * ramp
    rgb = np.repeat(rgb, WIDTH, axis=1)

    # Cool glow where the board sits, so the cards have something to lift off.
    gx = (xs - 0.5) / 0.85
    gy = (ys - 0.24) / 0.62
    glow = np.exp(-(gx ** 2 + gy ** 2) * 1.9)
    rgb += glow[..., None] * np.array([5.0, 6.5, 8.0])[None, None, :]

    vx = (xs - 0.5) * 2.0
    vy = (ys - 0.5) * 2.0
    vignette = np.clip((vx ** 2) * 0.55 + (vy ** 2) * 0.35, 0.0, 1.0)
    rgb -= vignette[..., None] * np.array([4.0, 4.5, 5.0])[None, None, :]

    rng = np.random.default_rng(20260814)
    grain = rng.normal(0.0, 1.45, size=(HEIGHT, WIDTH, 1))
    fibre = np.sin(ys * HEIGHT * 0.9) * np.cos(xs * WIDTH * 0.037) * 0.5
    rgb += grain + fibre[..., None]

    bayer = np.array(
        [
            [0, 8, 2, 10],
            [12, 4, 14, 6],
            [3, 11, 1, 9],
            [15, 7, 13, 5],
        ],
        dtype=np.float64,
    )
    bayer = (bayer / 16.0) - 0.5
    tile = np.tile(bayer, (HEIGHT // 4 + 1, WIDTH // 4 + 1))[:HEIGHT, :WIDTH]
    rgb += tile[..., None]

    out = np.clip(np.rint(rgb), 0, 255).astype(np.uint8)
    Image.fromarray(out, mode="RGB").save(OUT, format="PNG", optimize=True)


if __name__ == "__main__":
    main()
