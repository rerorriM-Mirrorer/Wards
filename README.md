# Wards

Wards draws a ring in the 3D scene around your own character while Protect or Shell is on you. A blue Protect ring sits where TargetSC's sky ring rests, and a green Shell ring sits just below it. Each ring fades in when the buff lands and fades out when it wears off. This is the first test of a larger idea: status visuals drawn on characters with TargetSC's ring renderer.

## Install

Copy the `Wards` folder into `Windower/addons/`, so you have `addons/Wards/Wards.lua`, `addons/Wards/wards_model.lua` and `addons/Wards/libs/_Wards.dll`. Then type `//lua load Wards` in game.

`libs/_Wards.dll` is TargetSC's renderer (native 0.15.0), copied byte for byte and renamed. The renderer draws one character per frame, so Wards needs its own copy. If both addons shared one copy, each would erase the other's rings. Like TargetSC's DLL, it can only be replaced while every game client is closed.

## Commands

| Command | What it does |
| --- | --- |
| `//wards` or `//wards help` | Lists the commands. |
| `//wards status` | Version, renderer, whether Protect/Shell are seen, every setting. |
| `//wards on` / `off` | Turns all drawing on or off. |
| `//wards protect [on\|off]` | Shows or hides the Protect ring (bare = toggle). |
| `//wards shell [on\|off]` | Shows or hides the Shell ring (bare = toggle). |
| `//wards test protect\|shell\|both\|off` | Shows rings without the buff, for tuning. `protect` / `shell` toggle. |
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
| `//wards defaults` | Restores every setting. |
| `//wards restart` / `unload` | Reloads or unloads Wards. |

Settings are saved in `Wards/data/settings.xml`.

## Colors

| Choice | Protect | Shell | Where it comes from |
| --- | --- | --- | --- |
| `element` (default) | 65,130,255 | 115,245,145 | TargetSC's Water / Wind element colors, the ones its Reverberation and Detonation rings use |
| `icon` | 0,0,255 | 0,128,0 | the solid color of TargetSC's `images/skillchain/reverberation.png` / `detonation.png` |
| `iconlight` | 127,127,255 | 127,191,127 | the lighter edge tint in those same icons (halfway to white) |
| `R,G,B` | any | any | your own color, e.g. `//wards color shell 90,255,160` |

## How it decides where to draw

Sizes come from the same formula as TargetSC (`resonance.dimensions`): your model's size sets the ring radius and the height span, multiplied by `scale` and `height`. Protect sits at `ground + level x span` above your feet. That is exactly where TargetSC's sky ring rests in the grounded layout, so the defaults line up with what you already know. Shell sits `gap x span` below it. Like TargetSC's rings, each one is a soft glow line (width + 4 px, 24% alpha) under a thin bright core line.

Wards hides itself while you're logged out, in cutscenes and events, and while zoning.

## Changelog

- **0.1.0-test1** (2026-11-23): First test. Protect and Shell rings on your own character, fades, color choices (element / icon / iconlight / R,G,B), placement and look tunables, test mode.
