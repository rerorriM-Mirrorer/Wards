# Wards

Wards draws status visuals in the 3D scene around your own character. Since Test3 that means **debuffs**: each debuff has its own look (color, glow and motion), and they stack upward above the HP ring's position in the order they landed. The Protect/Shell rings and the enemybar2-style HP ring are still there, but they're **off by default** (`//wards protect on`, `//wards shell on`, `//wards hp on`). A blue Protect ring sits where TargetSC's sky ring rests, and a green Shell ring sits just below it. Each ring fades in when the buff lands and fades out when it wears off. The `development/protect-vfx-poc` branch adds a separate, faint idle shimmer while Protect is active; it is an experiment, not a replacement for the existing ring.

## Install

Copy the `Wards` folder into `Windower/addons/` (or download this repository and name its folder `Wards`), so you have `addons/Wards/Wards.lua`, `addons/Wards/wards_model.lua`, `addons/Wards/wards_debuffs.lua`, `addons/Wards/wards_vfx.lua` and `addons/Wards/libs/_Wards.dll`. Then type `//lua load Wards` in game.

`libs/_Wards.dll` is Wards' private copy of TargetSC's D3D8 renderer, built from the source in `native/`. Renderer 0.16.0 retains the 0.15.2 SceneHook unload-safety thunks and adds the heading-oriented shield and camera-facing hex geometry. The renderer draws one character per frame, so Wards needs its own copy; both addons can run together through SceneHook. Like TargetSC's DLL, it can only be replaced while every game client is closed. This POC requires 0.16.0; with an older `_Wards.dll`, `//wards status` tells you to replace it.

## Commands

| Command | What it does |
| --- | --- |
| `//wards` or `//wards help` | Lists the commands. |
| `//wards status` | Version, renderer, whether Protect/Shell are seen, every setting. |
| `//wards on` / `off` | Turns all drawing on or off. |
| `//wards protect [on\|off]` | Shows or hides the Protect ring (bare = toggle). |
| `//wards shimmer [on\|off]` | Toggles the Protect idle shimmer independently of the Protect ring (default on). |
| `//wards shimmer opacity <0.01-0.40>` | Maximum shimmer core alpha (default 0.16). |
| `//wards shimmer period <2-12>` | Seconds between passes (default 4.8). |
| `//wards shimmer duration <0.25-1.5>` | Seconds per pass (default 0.75). |
| `//wards impact [on\|off]` | Enables the brief Protect shield on incoming melee/ranged hits (default on). |
| `//wards glints [on\|off]` | Enables tiny hex glints when Protect wears off (default on). |
| `//wards shell [on\|off]` | Shows or hides the Shell ring (bare = toggle). |
| `//wards test protect\|shell\|hp\|shimmer\|expire\|impact <1-9999>\|both\|off` | Previews looks; `expire` plays glints and `impact <1-9999>` previews a manually supplied intensity. |
| `//wards color protect\|shell <choice>` | Ring color, see below. |
| `//wards height <0.25-3>` | Height span, same meaning as TargetSC `height` (default 0.66). |
| `//wards scale <0.25-3>` | Ring size, same meaning as TargetSC `scale` (default 2). |
| `//wards level <0-1.5>` | Protect ring position in the span (default 0.90 = where TargetSC's sky ring rests). |
| `//wards gap <0-0.5>` | Shell ring distance below Protect, as a fraction of the span (default 0.08). |
| `//wards ground <0-1>` | Yalms above your feet where the span starts (default 0.3, TargetSC's ground height). |
| `//wards opacity <0-1>` | Core line opacity (default 1). |
| `//wards glow <0-3>` | Glow strength, 0 = no glow (default 1). |
| `//wards width <1-8>` | Core line width in pixels (default 2). |
| `//wards fade in\|out <0.05-3>` | Fade seconds (defaults: in 0.3, out 0.6). |
| `//wards hp [on\|off]` | Shows or hides the HP ring (bare = toggle). |
| `//wards hp <setting> <value>` | Tunes the HP ring (see below). `//wards hp settings` lists them. |
| `//wards test hp` | Shows the HP ring out of combat (toggle). `test off` clears every test. |
| `//wards preview hp <0-100>` | Shows the HP ring at that HP%, even out of combat. Lower it again to watch the trail. `//wards preview off` ends it. |
| `//wards debuffs [on\|off]` | Debuff looks on or off (bare = toggle). |
| `//wards debuff list` | Each look: on/off, showing now, status IDs. |
| `//wards debuff <name> [on\|off]` | One look on or off (bare = toggle). |
| `//wards debuff <name> settings` | That look's settings and current values. |
| `//wards debuff <name> <setting> <value>` | Tunes one look, e.g. `//wards debuff paralysis flash_every 2`. |
| `//wards debuff layout <setting> <value>` | `gap`, `spacing`, `max`, `slide`, `fade_in`, `fade_out`, `front` (see below). |
| `//wards preview debuff <name\|all>` | Shows a look without having the debuff (toggle). `//wards preview off` ends every preview. |
| `//wards defaults` | Restores every setting. |
| `//wards restart` / `unload` | Reloads or unloads Wards. |

## Protect idle shimmer (POC)

This experiment is on `development/protect-vfx-poc`; it is not part of `main` and has not yet been visually tested in FFXI. While Protect is present, a narrow blue band occasionally travels up or down the character. Most passes use one band; every fourth pass may use a second band moving the other way. Each band is a very faint core with a softer halo. It uses the existing ring geometry and depth testing, not a permanent aura or a particle system. The Protect ring remains independently controlled by `//wards protect`.

`//wards shimmer on|off` controls the shimmer without changing the Protect ring. `//wards test shimmer` previews it without the buff. Defaults: opacity 0.16, period 4.8 seconds, duration 0.75 seconds.

When Protect disappears, `//wards glints on|off` controls four tiny hex glints dispersing over 0.5 seconds. `//wards impact on|off` controls a heading-oriented translucent shield and radial honeycomb ripple (0.48-second shield, 0.32-second ripple). `//wards test expire` previews the glints; `//wards test impact 1` through `9999` previews a chosen intensity without combat. A nonlinear `x^1.6` response keeps low values restrained. The packet path accepts completed melee and ranged hits on the local recipient while Protect is active. The packet only gives landed damage, used as an impact-severity proxy; it is not damage prevented. `//wards status` reports these settings.

Settings are saved in `Wards/data/settings.xml`.

## Colors

| Choice | Protect | Shell | Where it comes from |
| --- | --- | --- | --- |
| `element` (default) | 65,130,255 | 115,245,145 | TargetSC's Water / Wind element colors, the ones its Reverberation and Detonation rings use |
| `icon` | 0,0,255 | 0,128,0 | the solid color of TargetSC's `images/skillchain/reverberation.png` / `detonation.png` |
| `iconlight` | 127,127,255 | 127,191,127 | the lighter edge tint in those same icons (halfway to white) |
| `R,G,B` | any | any | your own color, e.g. `//wards color shell 90,255,160` |

## Debuffs

Each debuff is drawn as a ring (or arc) at its own height. The first one sits a little above where the HP ring would be, and each new debuff stacks above the last in the order it landed. When one wears off, it fades out in place, and then the ones above it glide down to close the gap. Silence and Blind are arcs in **front of your character** (the way you face, not the camera).

| Look | Status | What it does |
| --- | --- | --- |
| `paralysis` | Paralysis (4) | Bright yellow ring that buzzes (tiny size jitter). Its yellow glow flashes ice blue (TargetSC's Ice color) at irregular moments, sometimes twice, like electricity. |
| `silence` | Silence (6) | Near-white green half arc in front of you. Its glow is white in the middle and red at both ends, and it sways gently back and forth. |
| `curse` | Curse (9, 20) | Purple ring. Its glow is a white-to-purple gradient that turns around the ring like a shimmer and breathes slightly. |
| `blind` | Blindness (5) | Murky black, like TargetSC's Darkness rings: a black core under layers of dark violet haze that slowly breathe. An arc in front by default; `//wards debuff blind shape ring` for the full ring. |
| `sleep` | Sleep (2, 19) | Lavender ring with a pale-blue glow, breathing slowly. |
| `stun` | Stun (10) | Placeholder look until you design one: three short bright arcs orbiting fast, bobbing a little. |
| `slow` | Slow (13) | Comet arcs turning counterclockwise. Each cycle flashes bright orange, fades through Scission earth-amber to deep blue, turning fast at the flash and slowing as it fades. |

Layout settings (`//wards debuff layout <setting> <value>`):

| Setting | Default | Meaning |
| --- | --- | --- |
| `gap` | 0.10 | First debuff's distance above the HP ring position (fraction of the height span) |
| `spacing` | 0.08 | Distance between stacked debuffs |
| `max` | 8 | Most looks drawn at once (oldest first) |
| `slide` | 0.25 | Seconds to glide to a new slot |
| `fade_in` / `fade_out` | 0.3 / 0.6 | Seconds to appear / disappear |
| `front` | 0 | Degrees added to your facing for the front arcs (try 180 if they appear behind you) |

Every look's own settings are listed by `//wards debuff <name> settings` and can be changed the same way. Colors take `R,G,B` or a name: `black`, `white`, `earth`, `ice`, `light`, `darkness`, `red`, `yellow`. Some examples:
- `//wards debuff curse spin 60`
- `//wards debuff silence sway 4`
- `//wards debuff slow cycle 4`
- `//wards debuff sleep glow 200,220,255`

## HP ring

The HP ring (off by default since Test3; `//wards hp on`) sits above the Protect ring and appears only in combat (engaged, or Windower's in-combat flag), fading in and out. A semi-opaque black circle runs all the way around. On top of it, a pink arc (enemybar2's main-bar pink) with a pink-white glow shows your HP%: the whole circle at 100%, a thin sliver at 2-3%. The arc is centered on the side of the circle facing the camera and shrinks evenly from both ends, so the last sliver is always the part you see.

When you lose HP, the lost part turns red (enemybar2's trail color). It holds for 2 seconds, then drains into the pink over half a second. Below 50%, a red glow pulses on the circle, getting stronger as HP falls. At 10% and below, the pink arc flashes toward white. Ghost hits, healing and death effects come later.

| `//wards hp ...` | Default | Meaning |
| --- | --- | --- |
| `gap` | 0.08 | Distance above the Protect ring, as a fraction of the height span |
| `color` / `glow color` | pink / pinkwhite | Pink core (255,149,151) and its glow (255,215,218) |
| `opacity` / `width` | 1 / 2 | Pink core opacity and pixel width |
| `glow` / `glow opacity` | 1 / 0.35 | Glow strength (width +4 px x glow) and opacity |
| `back opacity` / `back width` | 0.45 / 8 | The black circle |
| `motion` | 0.18 | Seconds for the pink arc to follow a new HP% |
| `trail` | on | Red trail over just-lost HP |
| `trail color` / `trail opacity` / `trail width` | trail / 1 / 4 | Trail look (trail = 167,57,96) |
| `trail hold` / `trail slide` | 2 / 0.5 | Seconds before the trail drains, and how long it drains |
| `pulse` | on | Low-HP red pulse below 50% |
| `pulse color` / `pulse opacity` / `pulse period` | red / 0.5 / 0.5 | Pulse look (red = 220,40,60; enemybar2's main bar pulses every 0.1 s) |
| `flash` / `flash period` | on / 0.25 | Flash toward white at 10% and below |
| `fade in` / `fade out` | 0.3 / 0.8 | Seconds to appear when combat starts and to fade out when it ends |

Colors take `pink`, `pinkwhite`, `trail`, `red`, `black`, `white` or `R,G,B`. Examples: `//wards hp trail hold 3`, `//wards hp glow color 255,230,235`, `//wards hp pulse off`.

## How it decides where to draw

Sizes come from the same formula as TargetSC (`resonance.dimensions`): your model's size sets the ring radius and the height span, multiplied by `scale` and `height`. Protect sits at `ground + level x span` above your feet. That is exactly where TargetSC's sky ring rests in the grounded layout, so the defaults line up with what you already know. Shell sits `gap x span` below it. Like TargetSC's rings, each one is a soft glow line (width + 4 px, 24% alpha) under a thin bright core line.

The HP ring sits `hp gap x span` above Protect.

Wards hides itself while you're logged out, in cutscenes and events, and while zoning.

## Changelog

- **0.3.3-test6** (2026-11-26, POC branch): Adds Protect expiry hex glints, a heading-oriented translucent shield with a honeycomb ripple, manual intensity preview (`1-9999`), and a restricted incoming melee/ranged hit listener. Renderer 0.16.0 adds native shield/hex geometry; CI strips and publishes its DLL. Landed damage is a severity proxy, not prevented damage. Host-verified; in-game appearance pending.

- **0.3.2-test5** (2026-11-26, POC branch): Adds a faint Protect idle shimmer and `//wards test shimmer`, with independent toggle and opacity/period/duration controls. Reuses the existing native ring renderer; host-verified only; in-game appearance pending.

- **0.3.1-test4** (2026-11-23): Crash fix, no visual change. Renderer 0.15.2: the shared scene hook no longer leaves renderer code on the stack while the game's frame runs, so `//lua unload`, `//lua reload` or `//wards restart` can't crash the client any more (it used to crash with `_Wards.dll_unloaded` or an unknown module). `//wards status` ends with `thunk` when the fix is active.

- **0.3.0-test3** (2026-11-23): Debuff looks on yourself: Paralysis, Silence, Curse, Blind, Sleep, Stun (placeholder look) and Slow, stacked above the HP ring position in landing order with fades and gliding slots; Silence and Blind face your character's front. `//wards debuffs`, `debuff ...`, `preview debuff`. Protect, Shell and the HP ring are now off by default (a one-time settings upgrade turns them off in an existing settings file). Same renderer as Test2.

- **0.2.0-test2** (2026-11-23): HP ring above Protect, shown in combat only: black circle, pink arc with pink-white glow centered toward the camera, red trail (2 s hold, 0.5 s drain), low-HP pulse, 10% flash, `//wards hp ...` tuning, `test hp`, `preview hp`. Renderer 0.15.1 (camera-facing arcs).

- **0.1.0-test1** (2026-11-23): First test. Protect and Shell rings on your own character, fades, color choices (element / icon / iconlight / R,G,B), placement and look tunables, test mode.
