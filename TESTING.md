# Wards TESTING

## Current Development Status — 2026-11-23 (America/Chicago)

- Repo/branch: `rerorriM-Mirrorer/Skillchains` `development/wards-protect-shell`. Stack: `master@9476226` -> `development/targetsc-mb-rise-gradient@8624248` -> `development/targetsc-level4-collapse@446362f` -> `development/targetsc-lit-disc@26438f2` -> `development/wards-protect-shell`. Not pushed (push access denied; patches delivered).
- installed_base: Test2 `2143cce` (A's word 08:08 after Test2: "really cool but not so useful yet"; Test1 Protect/Shell Live 07:13). Package `Wards-0.3.0-Test3.zip` = Wards.lua, wards_model.lua, wards_debuffs.lua (new), README.md. **DLL unchanged (0.15.1): no need to close the game**, `//lua reload wards` is enough.
- A's design (09:21, 09:31): WHM-curable debuffs first; Protect/Shell/HP off by default; stack starts right above the HP ring; first set Paralysis, Silence, Curse, Blind, Sleep, Stun, Slow; Silence (and Blind) are arcs in front of the character's facing, not the camera; one-ring-with-arcs idea kept for the Erase group later.
- Changes: Test3. New `wards_debuffs.lua`: recipe per debuff (ids, tunables saved flat as `<name>_<key>`, draw function using ring/arc helpers) plus the stack (landing order, fade in/out, a fading look keeps its slot, then the rest glide down over `debuff_slide`; cap `debuff_max`). Facing: front ring angle = -`mob.facing` (Verified from Windower InfoBar's compass table; DLL axis match Inferred). Looks: paralysis (buzz = per-frame radius jitter, ice flash at hashed irregular moments, sometimes double), silence (front half arc, two-arc red-white-red glow, sway), curse (rotating white/purple gradient glow, breathing), blind (black core + 3 dark-violet haze layers breathing; arc 220 deg in front or ring), sleep (breathing radius + glow), stun (placeholder: 3 orbiting arcs bobbing), slow (comet arcs CCW, bright orange flash -> earth -> deep blue, speed boost at flash integrated smoothly). One-time settings upgrade (`settings_version` 3) turns protect/shell/hp off once. Items capped at the DLL's 64 per frame. Version `0.3.0-test3`.
- Tunables (defaults). Layout: `debuffs` on, `debuff_gap` .10, `debuff_spacing` .08, `debuff_max` 8, `debuff_slide` .25, `debuff_fade_in` .3, `debuff_fade_out` .6, `debuff_front` 0.
  - paralysis: color 255,235,60, glow 255,215,40, flash ice (120,235,255), width 2, glow_width 8, glow_opacity .3, buzz .012, flash_every 1.6, flash_length .12, flash_opacity .75.
  - silence: color 210,255,210, glow_mid white, glow_edge red (255,60,60), span 180, width 3, glow_width 10, glow_opacity .4, sway 8, sway_period 3.
  - curse: color 150,60,220, glow 200,110,255, shimmer white, width 2, glow_width 8, glow_opacity .4, spin 40, pulse_period 2.5.
  - blind: shape arc, color black, murk darkness (25,14,52), span 220, width 4, opacity .85, murk_width 22, murk_opacity .35, breath_period 3.5.
  - sleep: color 190,160,255, glow 170,210,255, width 2, glow_width 10, glow_opacity .35, breath_period 4, breath_size .04.
  - stun: color 255,250,200, glow 255,230,120, count 3, arc 28, spin 320, width 3, glow_width 9, glow_opacity .45, wobble .05.
  - slow: bright 255,170,70, mid earth (176,114,48), deep 20,40,140, cycle 3.2, spin_base 12, spin_boost 70, count 3, arc 100, width 3, glow_width 9, glow_opacity .35.
- Checks: `luac5.1 -p` on Wards/*.lua and tests PASS (real Lua 5.1); `lua5.1 Wards/tests/test_wards.lua` 312/312 PASS; `lua5.1 Wards/tests/test_debuffs.lua` 37/37 PASS (IDs, DLL argument ranges for every look over 12 s, stack order/slide/cap, facing math, each look's motion). Host only.
- Pending: everything in game. Open risks: front arcs could face behind/sideways if the DLL's north axis differs from Windower's (fix: `//wards debuff layout front 180` or tell me the offset); counterclockwise for Slow is Inferred.
- Next: A tunes these; Stun gets A's own design; then Bio, Dia, Disease/Plague, Gravity/Bind at the feet, Charm, Doom (needs a countdown capture), the Erase ring with arcs; then party members (multi-anchor DLL).

## Test3 checklist

- [ ] Unzip Test3 into addons and `//lua reload wards` (no game restart needed). Do you see the one-time message that Protect, Shell and HP rings are now off by default?
- [ ] `//wards preview debuff all`: do all seven looks stack above you without overlapping? Send a screenshot if you can.
- [ ] Preview each look on its own (`//wards preview debuff paralysis`, then `silence`, `curse`, `blind`, `sleep`, `stun`, `slow`). Does each feel like your description? Note anything to change.
- [ ] Silence and Blind: turn your character around. Do the arcs stay in front of you? (If they sit behind or to the side, tell me which; `//wards debuff layout front 180` is a quick fix for "behind".)
- [ ] Slow: does it turn counterclockwise seen from above, speeding up at each orange flash?
- [ ] Real debuffs: when you get paralyzed, silenced or slowed, does the look appear, and fade out when it's cured or wears off? Do the rings above glide down?
- [ ] Tune with `//wards debuff <name> settings` / `//wards debuff <name> <setting> <value>`, and send the `//wards status` lines plus anything you changed.
- [ ] Stun: describe the look you'd like, and I'll replace the placeholder.

---

## Current Development Status — 2026-11-23 (America/Chicago)

- Repo/branch: `rerorriM-Mirrorer/Skillchains` `development/wards-protect-shell`. Stack: `master@9476226` -> `development/targetsc-mb-rise-gradient@8624248` -> `development/targetsc-level4-collapse@446362f` -> `development/targetsc-lit-disc@26438f2` -> `development/wards-protect-shell`. Not pushed (push access denied; patches delivered).
- installed_base: Test1 (`7a10dd8`; A at 07:13: `test both`, Protect and Shell appear, disappear and reappear as cast, Live). Package `Wards-0.2.0-Test2.zip` = files changed since `7a10dd8`: Wards.lua, wards_model.lua, libs/_Wards.dll (now 0.15.1: close every client before replacing it), README.md.
- A's choices (07:13): HP ring above the Protect ring; the pink arc shrinks evenly toward the camera-facing sliver; shown only in combat with fades; no ghost hits, healing or death animation yet.
- Changes: Test2. Native 0.15.1 (TargetSC/src): `native.arc` optional arg 14 camera (0/1) = start angle from the toward-camera direction at the entity (`targetsc::camera_position` from the D3D view matrix, `toward_camera`); `test_property.cpp` camera block. Lua: HP ring model (`hp_new/hp_update/hp_step/hp_items/hp_offset`): black full circle, pulse (<50%), trail arcs on both sides of the pink arc, pink-white glow, pink core (flash at 10% and below); pink follows HP with `hp_motion`; trail holds `hp_trail_hold` then drains over `hp_trail_slide`; a fresh ring or preview snaps without a trail. Combat = `status==1` or `in_combat==true` (field used by Windower's scoreboard addon, not in its definitions: Inferred). `//wards hp ...`, `test hp`, `preview hp <0-100>|off`. Wards refuses a DLL other than 0.15.1 with a message. Version `0.2.0-test2`.
- Tunables (defaults): `hp` on, `hp_gap` .08, `hp_color` pink (255,149,151), `hp_glow_color` pinkwhite (255,215,218), `hp_opacity` 1, `hp_width` 2, `hp_glow` 1, `hp_glow_opacity` .35, `hp_back_opacity` .45, `hp_back_width` 8, `hp_motion` .18, `hp_trail` on, `hp_trail_color` trail (167,57,96), `hp_trail_opacity` 1, `hp_trail_width` 4, `hp_trail_hold` 2, `hp_trail_slide` .5, `hp_pulse` on, `hp_pulse_color` red (220,40,60), `hp_pulse_opacity` .5, `hp_pulse_period` .5, `hp_flash` on, `hp_flash_period` .25, `hp_fade_in` .3, `hp_fade_out` .8.
- Checks: DLL built (`i686-w64-mingw32-g++-win32` 13.2.0, BUILD.md command, -Werror clean), objdump PE32 / sole `luaopen__TargetSC` / KERNEL32+msvcrt, `strip -s` (this toolchain left runtime debug sections), sha256 `595470c3…`, 216,590 bytes; `test_property.cpp` (with camera block) and `test_stroke.cpp` PASS; `luac5.1 -p` on Wards/*.lua and tests PASS; `lua5.1 Wards/tests/test_wards.lua` 154/154 PASS (real Lua 5.1 this time). Host only.
- Pending: everything in game, especially whether the arc really faces the camera (Inferred from the view-matrix math, tested only on synthetic matrices) and whether the HP ring looks right above Protect.
- Next: A tunes the HP ring; then ghost hits / healing / death; then remaining-time effects; then party/enemy rings (multi-anchor DLL).

## Test2 checklist

- [ ] Close every client, unzip Test2 into addons (it replaces `libs/_Wards.dll`), start the game. `//wards status`: does the last line say `TargetSC 0.15.1 running`?
- [ ] Protect/Shell still behave as in Test1?
- [ ] `//wards preview hp 100`: a black circle with a pink ring and pink-white glow above the Protect ring?
- [ ] `//wards preview hp 40`: does the pink shrink toward the side facing the camera, with red trail pieces on both sides that hold about 2 s and then drain?
- [ ] Swing the camera all the way around: does the pink part keep facing you? (If it faces away or lags 90 degrees, tell me which.)
- [ ] `//wards preview hp 20`, then `5`: red pulse under 50%? Pink flashing toward white at 5%?
- [ ] `//wards preview off`, then fight something: does the ring fade in when you engage, follow your real HP, and fade out after?
- [ ] Tune anything with `//wards hp ...` (`//wards hp settings` lists them) and send the `//wards status` lines.

---

## Current Development Status — 2026-11-23 (America/Chicago)

- Repo/branch: `rerorriM-Mirrorer/Skillchains` `development/wards-protect-shell`, branched from `development/targetsc-lit-disc@26438f2` (Test7.26, DLL 0.15.0). New addon in `Wards/`; no TargetSC file changed.
- installed_base: none (new addon). Package `Wards-0.1.0-Test1.zip` = the complete `Wards/` folder (Wards.lua, wards_model.lua, libs/_Wards.dll, README.md).
- Changes: Test1. Protect (buff 40) and Shell (buff 41) rings on your own character, from `get_player().buffs`. Native renderer = TargetSC `_TargetSC.dll` 0.15.0 copied byte for byte as `libs/_Wards.dll` (sha256 `8296e3ce…`), loaded with `package.loadlib(path,'luaopen__TargetSC')` so it gets its own frame (the DLL draws one entity per frame). Sizes = TargetSC `resonance.dimensions`; Protect at `ground + level x span` (TargetSC grounded sky rest = .3 + .90 x span), Shell `gap x span` below. Glow (width +4 px x glow, alpha .24 x glow) then core, like TargetSC's ring helper. Smoothstep fades. Hidden when logged out, status 4 (cutscene/event), zoning.
- Tunables (defaults): `protect` on, `shell` on, `protect_color` element (65,130,255), `shell_color` element (115,245,145), choices icon (0,0,255 / 0,128,0) and iconlight (127,127,255 / 127,191,127) from `TargetSC/images/skillchain/reverberation.png` / `detonation.png`, or R,G,B; `height` .66, `scale` 2, `ground` .3, `level` .90, `gap` .08, `opacity` 1, `glow` 1, `width` 2 px, `fade_in` .3 s, `fade_out` .6 s.
- Checks: `luac -p` (Lua 5.1 via lupa) on Wards/*.lua and tests: PASS. `lua5.1 Wards/tests/test_wards.lua`: 90/90 PASS (model math, buff detection, fades, colors, frame contents, commands, help, ASCII chat, stubbed native calls). New CI workflow `.github/workflows/wards-testing.yml` (also checks that the DLL equals TargetSC's). Host only.
- Live: none yet.
- Pending: everything in game. Inferred, not yet seen: Windower's Lua allows `package.loadlib`; two copies of the DLL draw side by side through SceneHook (SceneHook is built for many addons at once, Verified in its README); TargetSC keeps drawing normally while Wards runs.
- Next: A tunes the look; then remaining-time effects (packet 0x063 buff timers), then party members (needs a DLL change: several anchors per frame).

---

## Test1 checklist

- [ ] `//lua load Wards`. Any error in the chat log? `//wards status`: does the last line say `TargetSC 0.15.0 running`?
- [ ] `//wards test both`: a blue ring and a green ring just below it, around your character near head height?
- [ ] Cast Protect on yourself (or have someone cast it). Does the blue ring fade in? Cancel it or let it wear off. Does it fade out?
- [ ] Same with Shell for the green ring.
- [ ] With a target selected and TargetSC running (`//tsc preview mb`), do TargetSC's rings and Wards' rings both show at the same time?
- [ ] Try `//wards color protect icon` and `iconlight` (and the same for shell). Which look do you like?
- [ ] Tune with `level`, `gap`, `glow`, `width`, `opacity`, `scale`, `height` until it feels right, then send the `//wards status` lines.
- [ ] Cutscene or zoning: do the rings disappear and come back afterwards?
- [ ] First-person view: does a ring clip the camera or look wrong?
- [ ] Mounted (chocobo): where do the rings sit?
