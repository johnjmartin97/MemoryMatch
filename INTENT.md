# INTENT

## What this is

An iOS native memory match game. You see a grid of face-down cards. You tap one,
it flips over. You tap another. If the two faces match, they stay up and are out
of play. If they don't, they flip back down and you try again. You keep going
until every pair has been found. It runs as a real app on an iPhone, built with
Apple's own tools, not as a web page wrapped in an app shell.

## Who it is for

Someone with a few minutes to spare — waiting in line, sitting on a couch, riding
a bus — who opens the app wanting a small, calm game they can start instantly and
stop at any point without losing anything important. They are not looking to
learn rules, make an account, or commit to a long session. They have played
memory match somewhere before, or can figure it out in one tap. Assumed: a
general audience of all ages, playing alone, holding the phone in one hand.

## What good means

1. From tapping the app icon to being able to tap a card, nothing stands in the
   way — no menu to clear, no sign-in, no tutorial the player has to dismiss.
2. A card flips the moment it is tapped. There is no wait between the tap and
   the card starting to turn.
3. A player who has never seen the app can find their first pair without being
   told the rules.
4. When two cards don't match, they stay face up long enough to memorize but not
   so long that the player feels stuck waiting — and tapping ahead is never
   punished by a lost or ignored input.
5. Every card face is clearly different from every other at a glance, including
   for a player who cannot distinguish red from green.
6. The game says clearly when it is won, and starting a fresh game from there
   takes one tap.
7. The whole board is visible and tappable at once on a normal iPhone screen,
   without scrolling or pinching, and with no card too small to hit reliably
   with a thumb.
8. Leaving the app mid-game and coming back does not silently destroy progress
   or leave the board in a broken half-flipped state.

## Out of scope

- Player accounts, sign-in, or profiles.
- Playing against another person, whether on the same device or over a network.
- Online leaderboards or any server the app depends on to work.
- Ads, purchases, or anything that charges money.
- A settings screen full of options to configure.
- Android, web, or desktop versions.

## Assumptions

The request gave one line, so the following were invented and should be
challenged if wrong:

- **Platform.** iPhone, portrait orientation, current iOS. Not iPad-specific,
  not Apple Watch, not Apple TV.
- **Players.** One person playing alone.
- **Card faces.** The request does not say what is on the cards. Something
  simple and self-contained that ships inside the app — no downloading images.
- **Board size.** A single sensible grid of pairs that fits comfortably on a
  phone screen. Whether the player can choose a bigger or smaller board was not
  asked for and is not assumed.
- **Scoring.** Not requested. Some feedback on how the player did — moves taken
  or time elapsed — is assumed to be worth having, but a persistent score
  history is not.
- **Sound.** Not requested. Assumed that if sound exists it is optional and the
  game is fully playable silent.
- **"Finished" means** an app that builds and runs on an iPhone, playable start
  to finish, not a prototype or a design mockup.
- **Not shipping to the App Store.** Store listing, review, and distribution
  were not asked for and are not assumed to be part of this.
