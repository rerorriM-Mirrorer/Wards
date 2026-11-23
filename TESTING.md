# Wards TESTING

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
