# Brief

## What we are building

A native iPhone memory match game: a grid of face-down cards, tap two, matched
pairs stay up, find them all. It is for someone with three spare minutes who
wants a calm game that starts instantly and can be abandoned at any moment. The
good ones win on feel — the card turns the instant your thumb lands, the board
fits the screen with no scrolling, and nothing (no ad, no timer, no sign-in, no
"rate us" popup) ever gets between the player and the next tap.

## Core behaviour

**Board setup.** A new game deals 16 cards in a 4x4 grid: 8 distinct symbols,
each appearing exactly twice. The deal order is shuffled uniformly at random.
Every card starts face down.

**Card states.** Each card is in exactly one of three states: `faceDown`,
`faceUp`, `matched`. A tap is accepted only on a `faceDown` card. Taps on
`faceUp`, on `matched`, or on any card while two cards are already face up and
resolving are ignored — ignored silently, with no error state and no visual
punishment.

**The turn.**
1. Tapping the first face-down card flips it to `faceUp`. The flip animation
   begins on the same frame as the touch-up, not after any delay. Nothing else
   happens; the player may sit here as long as they like.
2. Tapping a second face-down card flips it to `faceUp`. The board immediately
   locks against further input.
3. **Match** (both cards carry the same symbol): after the second card's flip
   completes (300 ms), both cards move to `matched`, play a short match
   animation, and the board unlocks. Matched cards remain visible on the board
   in a dimmed, non-interactive style — they do not disappear, because a hole
   in the grid destroys the spatial memory the game runs on.
4. **No match**: both cards stay `faceUp` for 900 ms after the second flip
   completes, then flip back to `faceDown` together, and the board unlocks.
5. The move counter increments once per completed pair-reveal, match or not.

**Tap-ahead.** If the player taps a third, face-down card during the 900 ms
no-match window, that tap is not discarded. The mismatched pair immediately
flips down (cancelling the remainder of the wait), the tapped card flips up as
the new first card of the next turn, and the move counter increments for the
turn that just resolved. A tap during the *match* resolution is ignored, since
that window is short and no card is leaving the board.

**Winning.** The game is won the instant the last pair moves to `matched` —
that is, when all 16 cards are `matched`. A win overlay appears after the match
animation finishes (~600 ms), showing move count and elapsed time, and a single
"Play Again" button that deals a fresh shuffled board. No other terminal
condition exists: there is no timer, no move limit, no losing, no score
threshold, no life or energy system. The game cannot end any other way.

**Timing.** Elapsed time starts on the first card tap of a game, not on deal.
It pauses when the app leaves the foreground and resumes on return. It stops at
the win.

**Backgrounding and restore.** On moving to the background the full game state
(card layout, each card's state, move count, accumulated elapsed time) is saved.
On relaunch, an unfinished game is restored exactly as left, with one
normalisation: any card in `faceUp` at save time is restored as `faceDown`. This
guarantees the board can never restore mid-turn or half-flipped. A won game is
not restored; relaunch after a win deals a fresh board.

**Cold start.** Launching with no saved game deals a board and shows it. There
is no menu, splash screen, sign-in, tutorial, or dismissable overlay of any
kind between launch and the first tappable card.

**Restart.** A single restart control is always available on the game screen. It
asks for confirmation only if at least one pair has been matched; otherwise it
reshuffles immediately.

**Rotation.** Portrait only. The grid is square and centred; locking orientation
avoids a landscape layout that adds nothing.

## Frameworks

| Surface | Choice | Why |
| --- | --- | --- |
| App shell & UI framework | SwiftUI (iOS 18 minimum, built against the current SDK) | Native, declarative, the default for new iOS apps; a 16-cell grid with flip animations is squarely in its comfort zone and needs no UIKit escape hatch. |
| State management | A single `@Observable` `GameModel` class, held by the root view in `@State` | The modern Swift Observation macro replaces `ObservableObject`/`@Published`, gives per-property view updates so flipping one card does not redraw the board, and keeps all rules in one testable, UI-free type. |
| Layout | `Grid` with fixed 4x4 rows inside a `GeometryReader`-sized square container | The grid is a known 4x4 — `Grid` states that structurally, and sizing from the container guarantees the whole board fits any iPhone screen without scrolling, with cells at least 64 pt. |
| Iconography | SF Symbols, multicolor rendering mode, one distinct symbol per pair | Ships with the system, scales crisply at any size, needs no asset production, and gives each face a distinct *shape* — so the faces stay distinguishable without relying on colour. |
| Animation | SwiftUI's built-in animation with `rotation3DEffect` around the Y axis for the flip, and `.spring` for the match pop | The standard, well-trodden SwiftUI card-flip; state-driven so animations follow directly from the model and cannot desynchronise from it. |
| Audio & haptics | `AVAudioPlayer` for the three short bundled sound effects; `.sensoryFeedback` for haptics | `AVAudioPlayer` is the lightest correct way to play short one-shot clips with an ambient audio session that respects the silent switch and never interrupts the player's music. `.sensoryFeedback` is the SwiftUI-native haptic path and needs no Core Haptics engine management. |
| Persistence | `@AppStorage`-backed JSON of a `Codable` `GameState` struct in `UserDefaults` | The saved state is a few hundred bytes with no queries, no relations, and no history. SwiftData would be real overhead — a schema, a container, a migration story — for one small blob. |

## Quality bar

1. From tapping the app icon on a cold launch, the first card can be tapped
   with no intervening screen, overlay, or dismissal, and the board is visible
   in under one second on an iPhone 13 or newer.
2. A card visibly begins its flip within 100 ms of the finger lifting; measured
   across 20 taps, none stalls longer.
3. The entire 4x4 board is fully visible and reachable on the smallest
   supported screen (iPhone SE, 4.7") with no scrolling or pinching, and every
   card's tappable area is at least 44x44 pt.
4. All 8 card faces remain distinguishable from one another when the screen is
   viewed in greyscale — that is, each pair is identified by shape, not colour.
5. Tapping a third card during the 900 ms no-match window always starts a new
   turn with that card face up; no tap is dropped, and the board never ends up
   with three cards face up.
6. Playing a full game to completion produces a win overlay showing the move
   count and elapsed time, and its "Play Again" button deals a fresh, differently
   shuffled board in one tap.
7. Force-quitting mid-game and relaunching restores the same board with the same
   matched pairs and move count, and with zero cards face up.
8. Across a full game there is no ad, no purchase prompt, no rating prompt, no
   sign-in, and no timer or countdown that can cause a loss.
9. VoiceOver announces each card as its position, its state, and — when face up
   or matched — its symbol name; the win overlay is announced when it appears.
10. With "Reduce Motion" enabled, the 3D flip is replaced by a cross-fade and
    the match animation drops its spring bounce, while all timings and rules
    stay identical.

## Assets needed

- **App icon** — a single 1024x1024 source image: two overlapping rounded cards
  on a calm gradient, one face down showing the card-back pattern, one face up
  showing a symbol. Appears on the Home Screen and in the App Store listing.
- **Card back design** — a repeating geometric pattern (concentric rounded
  shapes or a subtle diagonal weave) in the app's primary colour, drawn in
  SwiftUI shapes rather than a bitmap so it scales to any card size. Appears on
  every face-down card.
- **Card face symbol set** — 8 SF Symbols chosen for maximally distinct
  silhouettes (e.g. star, heart, bolt, leaf, moon, umbrella, anchor, bell), each
  with a distinct tint that is redundant with its shape. Appears on card faces.
- **Background** — a soft vertical gradient behind the grid, with light and dark
  mode variants defined in the asset catalogue. Appears on the game screen.
- **Match celebration effect** — a brief scale-up-and-settle spring on the two
  matched cards plus a short particle sparkle. Appears on every successful pair.
- **Win celebration effect** — a confetti burst behind the win overlay, running
  for about two seconds then settling. Appears once per completed game.
- **Sound effects** — three short clips: card flip (a soft paper snap, ~120 ms),
  match (a rising two-note chime, ~400 ms), win (a short major arpeggio,
  ~1.2 s). All respect the silent switch and duck nothing.

## Risks

- **The tap-ahead rule is the likeliest thing to be got wrong.** It is the one
  place where an animation, a timer, and an input all overlap. A naive
  implementation either drops the third tap or leaves three cards face up. It
  needs an explicitly cancellable delay tied to the turn, not a fire-and-forget
  `DispatchQueue.asyncAfter`.
- **Animation state drifting from model state.** If flip progress is stored in
  the view rather than derived from the model, backgrounding mid-animation can
  restore a card that looks face up but is modelled as face down. Every visual
  state must be a pure function of the model.
- **The 900 ms no-match delay is a guess.** It is the single number most likely
  to feel wrong on a real device — too short to memorise, or long enough to feel
  like waiting. Expect to tune it by hand.
- **Colour-only differentiation creeping in.** It is easy to pick eight pretty
  symbols and let colour do the distinguishing work. The greyscale check must be
  run against the real render, not assumed from the symbol names.
- **Scope creep toward the crowded end of the market.** Difficulty levels, card
  packs, Game Center leaderboards, and themes are what most competitors ship and
  what reviews ask for — and every one of them is out of scope here. The
  temptation to add "just a difficulty picker" is the main way this brief gets
  violated.
- **Small-screen layout.** The iPhone SE is the binding constraint on card size;
  a design tuned on a Pro Max can produce cards that are cramped or clipped
  there.

Sources consulted: [Memory King](https://apps.apple.com/us/app/memory-king-the-memory-cards-matching-game/id457508586),
[Matching Card Pairs](https://apps.apple.com/us/app/matching-card-pairs/id1255931987),
[Memory • Classic](https://apps.apple.com/us/app/memory-classic/id502626661),
[Pairs Memory Games for Adults](https://apps.apple.com/us/app/pairs-memory-games-for-adults/id1478716061),
[@Observable state management](https://medium.com/@chandra.welim/observable-the-future-of-swiftui-state-management-0ce176d25f88),
[SwiftUI card-flip pattern](https://swdevnotes.com/swift/2021/flip-card-in-swiftui/).
