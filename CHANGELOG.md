# Changelog

## 0.2.0

- Moon Patrol: a self-driving moon buggy jumps craters, blasts boulders and
  shoots down saucers on an endless A-to-Z course. Options for pace, arcade or
  theme colors, and Quattro (on by default): rally stages driven by a quattro,
  and a rare winged quattro worth 5000.
- Captain Omarchy: the intro of a 1985 spy caper on a loop. A title card, a
  helicopter landing by the field briefing sign, a run to the hut, and the
  mission briefing on a teletype. Options for 1985 or theme colors, the title
  card, and the briefing.
  Inspired by Captain Goodnight and the Islands of Fear (Broderbund, 1985).
- A delay set in After Dark now takes effect. Before, its idle monitor kept
  the delay it started with, so the screensaver waited for Omarchy's own
  delay instead (10 minutes by default).
- GAME OVER now shows in Asteroids and Invaders; a new game's first banner
  used to replace it in the same frame.
- The Invaders power-up is a root capsule now, and the Asteroids rocks no
  longer include the old privilege command.

## 0.1.0

First release.

- Nine screensavers: Flying Quattros (a winged quattro in six liveries),
  Matrix Operator (operator console, code rain, intrusion, trace), Omarchy
  Invaders, Pong Forever, Asteroids, Pipes, Starfield, Plasma, and Terminal
  Aquarium.
- Starts on idle on every screen, following Omarchy's `idle.screensaver` or
  its own delay; respects stay-awake and never draws under the lock screen.
- Asks on first run before replacing Omarchy's built-in screensaver; does it
  through Omarchy's own toggle, and gives it back when asked.
- Control panel with a live preview, per-screensaver options, favorites,
  exclusions, and Random mode by category and interval.
- Optional live system data for Matrix Operator and Terminal Aquarium.
- Community screensaver modules from `~/.config/mib-afterdark/screensavers/`.
