# Art direction

## Idea

Pressed paper tiles laid on a warm dawn wash — matte cards with soft ink
symbols, nothing glossy, nothing loud. It suits the product because the game is
for three quiet minutes: the visual language has to be calm enough to sit still
while the player thinks, and every card must read as a physical object worth
turning over.

## Palette

### Light

| Role | Hex | Used for |
|---|---|---|
| Background (top) | `#FDF6EC` | Screen gradient start |
| Background (bottom) | `#F0E2D2` | Screen gradient end |
| Surface | `#FFFFFF` | Card face, win overlay panel |
| Primary | `#2E6F7E` | Card back field, restart control, overlay button |
| Primary deep | `#22545F` | Card back pattern strokes, pressed states |
| Secondary | `#E0A32E` | Move counter accent, confetti |
| Accent | `#E0714F` | Win overlay headline, confetti |
| Success | `#4C9A6A` | Match sparkle particles |
| Danger | `#C7523F` | Restart confirmation destructive action |
| Text primary | `#23282D` | Counters, overlay body |
| Text muted | `#6E7780` | Labels, elapsed-time unit text |
| Card stroke | `#00000014` | 1.5 pt hairline around every card |
| Matched veil | `#FFFFFF99` | Overlay on matched cards (60% white) |

### Dark

| Role | Hex | Used for |
|---|---|---|
| Background (top) | `#1A1F26` | Screen gradient start |
| Background (bottom) | `#0F1318` | Screen gradient end |
| Surface | `#242B33` | Card face, win overlay panel |
| Primary | `#3E8C9E` | Card back field, restart control, overlay button |
| Primary deep | `#2A6572` | Card back pattern strokes, pressed states |
| Secondary | `#E8B858` | Move counter accent, confetti |
| Accent | `#F08A6C` | Win overlay headline, confetti |
| Success | `#63B383` | Match sparkle particles |
| Danger | `#D9695A` | Restart confirmation destructive action |
| Text primary | `#EDEFF2` | Counters, overlay body |
| Text muted | `#98A1AC` | Labels, elapsed-time unit text |
| Card stroke | `#FFFFFF1A` | 1.5 pt hairline around every card |
| Matched veil | `#0F131899` | Overlay on matched cards (60% background) |

### The eight card faces

Each pair is identified by silhouette first. Colour is redundant, never
load-bearing — the shapes stay distinct in greyscale.

| # | SF Symbol | Tint (light) | Tint (dark) |
|---|---|---|---|
| 1 | `star.fill` | `#E0A32E` | `#EFBA55` |
| 2 | `heart.fill` | `#D2566B` | `#E4788B` |
| 3 | `bolt.fill` | `#7B5EA7` | `#9C81C4` |
| 4 | `leaf.fill` | `#4C9A6A` | `#6FBA8B` |
| 5 | `moon.fill` | `#5B7FB9` | `#7D9FD4` |
| 6 | `umbrella.fill` | `#E0714F` | `#F08A6C` |
| 7 | `anchor` | `#2E6F7E` | `#4E9CAD` |
| 8 | `bell.fill` | `#8C7A6B` | `#AD9B8B` |

Symbol rendering: hierarchical, single tint per symbol. Symbol glyph occupies
52% of the card's shorter side, optically centred.

## Type

Family: **SF Rounded** (`.system(size:weight:design: .rounded)`) throughout.
Numerals are monospaced-digit everywhere a number changes (move count, timer)
so the layout never jitters.

| Style | Size | Weight | Used for |
|---|---|---|---|
| Display | 40 pt | Bold | Win overlay headline ("Solved") |
| Title | 26 pt | Semibold | Win overlay stat values |
| Body | 17 pt | Medium | Buttons, top-bar counters |
| Caption | 13 pt | Semibold | Stat labels ("Moves", "Time"), uppercase, 0.6 pt tracking |

## Motion

| Interaction | Duration | Curve | What moves |
|---|---|---|---|
| Card flip (up or down) | 300 ms | `.easeInOut` | `rotation3DEffect` 0°→180° about Y, perspective 0.35; face swaps at 90° |
| Card flip, Reduce Motion | 300 ms | `.easeInOut` | Cross-fade back→face, no rotation |
| Tap press-in | 90 ms | `.easeOut` | Scale 1.0 → 0.97 |
| Tap release | 140 ms | `.easeOut` | Scale 0.97 → 1.0 |
| Match pop | 380 ms | `.spring(response: 0.38, dampingFraction: 0.55)` | Scale 1.0 → 1.12 → 1.0 on both matched cards |
| Match pop, Reduce Motion | 240 ms | `.easeOut` | Opacity/veil only, no scale |
| Match sparkle | 520 ms | `.easeOut` | 8 particles, 3 pt dots, radius 0→46 pt, opacity 1→0 |
| Matched dim settle | 240 ms | `.easeOut` | Veil opacity 0 → 0.6, tint desaturates |
| Mismatch hold | 900 ms | — | Nothing moves; cancellable by a tap-ahead |
| Mismatch flip back | 300 ms | `.easeInOut` | Both cards rotate back together |
| Win overlay appear | 320 ms | `.spring(response: 0.32, dampingFraction: 0.8)` | Panel scale 0.92→1.0, opacity 0→1; backdrop blur 0→20 |
| Confetti burst | 2000 ms | `.easeOut` on fall, linear spin | 60 ribbons, 6×12 pt, gravity settle — the one deliberate exception over 400 ms |
| Confetti, Reduce Motion | 400 ms | `.easeOut` | Static fade-in of ribbons, no fall or spin |
| Deal / reshuffle | 260 ms | `.easeOut`, 12 ms stagger per card | Cards fade+scale 0.94→1.0 in reading order |

## Layout

- **Spacing scale:** 4 / 8 / 12 / 16 / 24 / 32 pt. Nothing off-scale.
- **Board:** square, centred, side = `min(width − 32, availableHeight)`.
- **Card gap:** 10 pt. **Board inset from screen edge:** 16 pt.
- **Card size:** board side minus 3 gaps, divided by 4. Floor of 64 pt; on
  iPhone SE (4.7", 375 pt wide) this yields ~78 pt cards — well clear of the
  44 pt minimum target.
- **Corner radii:** card 14 pt (continuous), win panel 24 pt, buttons 12 pt.
- **Stroke widths:** card hairline 1.5 pt, card-back pattern 2 pt, sparkle dot
  3 pt diameter.
- **Shadow:** cards `y: 2, blur: 6, #0000001F`; win panel `y: 8, blur: 28,
  #00000029`. Matched cards drop shadow to `y: 0, blur: 2`.
- **Top bar:** 44 pt tall, 16 pt side inset, moves left, time centre, restart
  right (44×44 pt hit target).
- **Card back pattern:** three concentric continuous-rounded-rectangle strokes
  inset 8 / 15 / 22 pt from the card edge, in Primary deep at 22% / 16% / 10%
  opacity, over a flat Primary field. Drawn in SwiftUI so it scales exactly.

## Feel

It should feel like turning over paper tiles on a table in morning light —
soft, matte, unhurried. The card answers your thumb instantly, so the game
feels responsive rather than eager; nothing flashes, nothing shouts, nothing
asks for attention that the board has not already earned. Getting a pair wrong
costs you a beat and no more, and the game never scolds — mismatched cards just
turn quietly back over. When you finish, the celebration is warm and brief:
enough to feel good, short enough that you can put the phone down mid-confetti
and not feel you missed anything.
