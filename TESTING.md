# Wards TESTING

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
