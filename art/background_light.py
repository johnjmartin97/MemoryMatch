"""Light-mode backdrop: warm dawn wash, #FDF6EC at the top to #F0E2D2 at the
bottom, with a soft overhead glow, a gentle vignette and fine dithered grain so
the gradient never bands on an OLED phone screen."""

import os

import numpy as np
from PIL import Image

WIDTH, HEIGHT = 1179, 2556
OUT = os.path.join(
    "App", "Assets.xcassets", "Background.imageset", "background-light.png"
)

TOP = np.array([0xFD, 0xF6, 0xEC], dtype=np.float64)
BOTTOM = np.array([0xF0, 0xE2, 0xD2], dtype=np.float64)


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    ys = np.linspace(0.0, 1.0, HEIGHT)[:, None]
    xs = np.linspace(0.0, 1.0, WIDTH)[None, :]

    # Ease the ramp slightly so most of the change happens low on the screen,
    # which keeps the top bar sitting on near-flat paper.
    ramp = (ys ** 1.15)[..., None]
    rgb = TOP[None, None, :] + (BOTTOM - TOP)[None, None, :] * ramp
    rgb = np.repeat(rgb, WIDTH, axis=1)

    # Warm overhead glow, centred above the board.
    gx = (xs - 0.5) / 0.85
    gy = (ys - 0.24) / 0.62
    glow = np.exp(-(gx ** 2 + gy ** 2) * 1.9)
    rgb += glow[..., None] * np.array([7.0, 5.0, 2.0])[None, None, :]

    # Corner vignette: barely there, just enough to seat the board.
    vx = (xs - 0.5) * 2.0
    vy = (ys - 0.5) * 2.0
    vignette = np.clip((vx ** 2) * 0.55 + (vy ** 2) * 0.35, 0.0, 1.0)
    rgb -= vignette[..., None] * np.array([9.0, 8.0, 7.0])[None, None, :]

    # Paper grain: fixed seed so every build renders the identical file.
    rng = np.random.default_rng(20260813)
    grain = rng.normal(0.0, 1.15, size=(HEIGHT, WIDTH, 1))
    # A faint horizontal fibre, so the texture reads as pressed paper.
    fibre = np.sin(ys * HEIGHT * 0.9) * np.cos(xs * WIDTH * 0.037) * 0.6
    rgb += grain + fibre[..., None]

    # Ordered dither on top of the noise kills the last of the banding.
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
