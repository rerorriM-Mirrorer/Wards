## Current Development Status — 2026-11-26 (America/Chicago)

- Repo/branch: \`rerorriM-Mirrorer/Wards\` \`development/protect-vfx-poc\`, source head before this docs update: \`acdfb2626e2e6166aaf49075a9482faa9bf40aec\`; CI-published DLL commit: \`4c7f36468c8cb2eb1fa113d0e316c32085aed98b\`. Branch base: installed Test3 \`abadbbb276132a7ae8210dd78b9ce52f3af51fed\` -> carried-forward Test4 source tree \`14858e288e69dfaf9811c185bc857c6f01171a68\`. \`main\` is unchanged.
- Version: Wards \`0.3.3-test6\`; native renderer \`0.16.0\`. The native API is guarded by an exact version check; Wards refuses older DLLs.
- Changes: \`wards_vfx.lua\` contains idle shimmer, Protect-loss glints, normalized impact intensity, and shield/ripple animation state. \`Wards.lua\` wires those to Protect status ID 40, incoming packet 0x028 categories 1/2, manual preview commands, and independent toggles. Native renderer adds one heading-oriented shield and up to eight camera-facing hex glints; honeycomb is bounded to 96 cells and shares the existing D3D8 alpha-blended triangle batch. No shaders or external particle system.
- Impact packet scope: incoming melee category 1 and ranged-finish category 2 only, local recipient ID only, positive Param when Message=1, with multi-action damage summed. Weapon skills, NPC TP, magic, and job abilities remain excluded pending a reliable physical/magical classifier. Full packet reasoning is in \`docs/PACKETS.md\`.
- Intensity: VFX state accepts integer 1-9999 independently of its source. Current packet proxy = \`clamp(round(total_landed_damage * 10),1,9999)\`; response curve = \`(intensity/9999)^1.6\`. This is landed-hit severity, **not damage prevented**. The incoming action packet does not expose the counterfactual without Protect or a prevented-damage field.
- Defaults: shimmer, expiry glints and impact on; shimmer core alpha 0.16, period 4.8 s, duration 0.75 s; glints 4 over 0.50 s; shield 0.48 s and ripple 0.32 s.
- Commands: \`//wards shimmer [on|off]\`; shimmer opacity/period/duration tuning; \`//wards glints [on|off]\`; \`//wards impact [on|off]\`; \`//wards test shimmer\`; \`//wards test expire\`; \`//wards test impact <1-9999>\`; \`//wards test off\`.
- Checks: GitHub Actions [45857011809](https://github.com/rerorriM-Mirrorer/Wards/actions/runs/45857011809) PASS on \`acdfb26\`: Lua 5.1 syntax parse, Wards host simulation **371 passed / 0 failed**, debuff host simulation PASS, native 0.16.0 i686 MinGW build PASS, property/stroke/thunk/shield-geometry tests PASS. The publish job PASS; the exact checked DLL was stripped and committed to \`libs/_Wards.dll\` at \`4c7f364\`. Static/host verification only.
- Live status: installed Test3 is the only in-game-confirmed baseline. Test4 and all Protect VFX POC work remain Pending in-game. No visual, timing, heading, or packet event has been tested in FFXI.
- Pending (A): install the POC package with every client closed before replacing the DLL; test \`//wards status\`, each preview, and real Protect. Inspect shimmer placement/body occlusion/opacity; expiry glints; circle forward-facing orientation and edge opacity; ripple clarity; manual 1/5000/9999 response; melee and ranged packet classification; multi-hit aggregation; no effects on spells/WS/other targets; TargetSC coexistence in both addon load orders; cutscene/zone/logout/unload cleanup. Report actual visual observations before tuning.
- Pending development: visual tuning after A's first in-game capture; broader WS/TP physical classifier only if damage type can be established; optional sparks/flex only after core stability. No prevented-damage formula is implemented.
- Next: verify this docs update, then deliver the POC package and in-game checklist.

## Test6 VFX checklist

- [ ] Close all game clients, install the complete package, and load Wards; \`//wards status\` must show version 0.3.3-test6 and native 0.16.0 running.
- [ ] \`//wards test shimmer\`: subtle narrow band sweeps smoothly; normally one band, never more than two.
- [ ] \`//wards test expire\`: four tiny hex glints disperse gently and fade; no lasting geometry.
- [ ] \`//wards test impact 1\`, \`5000\`, \`9999\`: circle faces the character's heading, center stays translucent, edges are brighter, flash is quick and fades rapidly; honeycomb traces over the face then disappears.
- [ ] Enable Protect and test incoming melee hits; if safe, verify ranged hits too. Compare one hit and multi-hit; effect must be on the recipient only.
- [ ] Confirm weapon skills, TP moves, magic, items, and unrelated targets do not trigger the current POC.
- [ ] Verify glints only on Protect removal, not on zoning/logout or cutscene reset.
- [ ] Run Wards alongside TargetSC; reload/unload both in both addon orders; no frozen effects, crashes, or lost TargetSC drawings.
- [ ] Capture \`//wards status\` and visuals for subsequent opacity, scale, heading, and timing adjustments. Do not mark these complete from host simulation.

---

## Current Development Status — 2026-11-26 (America/Chicago)

- Repo/branch: `rerorriM-Mirrorer/Wards` `development/protect-vfx-poc`, code head before this documentation update: `65764de57592bd5e2c910c37afb1106513250f48`. Stack: installed Test3 `abadbbb276132a7ae8210dd78b9ce52f3af51fed` -> Test4 source-tree snapshot `14858e288e69dfaf9811c185bc857c6f01171a68` -> Protect shimmer POC.
- installed_base: Test3 (`abadbbb`; Live, as recorded below). Test4 source and renderer 0.15.2 are carried forward from the current Wards tree, but remain Pending in-game. `main` is unchanged.
- Changes: Wards `0.3.2-test5`. New `wards_vfx.lua` contains an independent idle-shimmer state machine; `Wards.lua` connects it to Protect status ID 40, local-player rendering, toggle, tuning and preview; `tests/test_wards.lua` covers motion, first delay, single/double-band cap, reset and commands. The shimmer uses the current `native.ring` API. No native source, DLL, packet handler or damage calculation changed.
- Defaults: shimmer on while Protect is active; core opacity 0.16, period 4.8 s, pass duration 0.75 s. Commands: `//wards shimmer [on|off]`, `//wards shimmer opacity <0.01-0.40>`, `//wards shimmer period <2-12>`, `//wards shimmer duration <0.25-1.5>`, `//wards test shimmer`.
- Checks: GitHub Actions run [45853767535](https://github.com/rerorriM-Mirrorer/Wards/actions/runs/45853767535) PASS on `65764de`. Workflow ran `luac5.1 -p` over root/test Lua files; `lua5.1 tests/test_wards.lua` (339 passed, 0 failed); `lua5.1 tests/test_debuffs.lua` PASS; native 0.15.2 source build PASS; `test_property`, `test_stroke`, and `test_thunk` PASS. Static/host verification only.
- Live: installed base is Test3 only. No Protect shimmer visual/timing/placement has been tested in FFXI.
- Pending (A): install the POC branch package on a test client; inspect `//wards status`; run `//wards test shimmer`; observe it in third-person from near/far camera distance and with different character/body sizes; confirm it remains subtle, follows the body, and disappears on toggle, logout, cutscene and zone change. Then enable Protect and confirm normal ring behavior is unchanged. Report any visual or coexistence issue with TargetSC.
- Pending development: expiration glints; impact detection from incoming action packets; a native heading-oriented shield surface; a transient honeycomb ripple; a manually supplied 1-9999 intensity preview; then a damage-severity proxy. Actual damage prevented is not exposed by the verified action packet fields; received physical damage is only a proxy, not prevented damage.
- Next: verify this docs/help update, then continue with the next isolated visual step after the shimmer has an in-game observation.

## Test5 shimmer checklist

- [ ] Install the POC branch package on a test Wards install; keep the installed Test3 baseline available for rollback.
- [ ] `//wards status`: version 0.3.2-test5, renderer 0.15.2 running, shimmer enabled, opacity 0.16, period 4.8, duration 0.75.
- [ ] `//wards test shimmer`: one narrow blue band appears, travels smoothly, then disappears; most passes are single-band.
- [ ] Observe enough passes to confirm the occasional double pass never exceeds two bands and still feels quiet.
- [ ] `//wards shimmer off`: shimmer stops immediately while existing Protect ring toggles remain independent; `//wards shimmer on` restores it.
- [ ] With Protect active, confirm normal idle shimmer appears and stops after Protect wears off.
- [ ] Test cutscene, logout and zone-change cleanup; check that no frozen band remains.
- [ ] Test with TargetSC loaded and reloaded in both addon orders; check for rendering or unload regressions.
- [ ] Send `//wards status` and a short description or capture of placement, opacity and motion. Do not treat host simulation as visual confirmation.

---

# Wards TESTING

## Current Development Status — 2026-11-23 (America/Chicago)

- Repo/branch: `rerorriM-Mirrorer/Wards` `main`, on top of `069acfc`. Stack: `main@069acfc` -> this commit (one branch).
- installed_base: Test3 (`abadbbb`; A ran it 10:23, Live). Package `Wards-0.3.1-Test4.zip` = files changed since `abadbbb`: Wards.lua, libs/_Wards.dll (0.15.2: **close every client before replacing it**), README.md.
- Why: crash finding 2026-11-23 (project doc `ffxi-scenehook-unload-crash-finding-2026-11-23.md`). A's crash 18:33 on Myrr was `_TargetSC.dll_unloaded` at offset 0x23cf3 = the instruction right after SceneHook's `owner_stub` calls the original draw_scene (Verified by disassembly of the shipped TargetSC 0.16.0 DLL). An `unknown`-module crash at 06:13:30 is the same second Wards loaded (Verified from A's event export). Windower runs addon Lua inside draw_scene, so unloading the addon that drives the frame freed the DLL under its own return address (Inferred).
- Changes: Test4, native 0.15.2. New `native/SceneHook/SceneHookThunk.h`: 64 per-slot thunks + dispatch table in the unused part of the never-freed hook-block page. `owner_ptr` now points at the owner's thunk; the thunk calls the trampoline, then jumps to the module's client walk only if its dispatch pointer is still set; `scenehook_unregister` clears it first. Fallback if the page cannot be used: old stub + module pinned. Same bus ABI 2 (Broguypal TargetRing/Vanish still interoperate; their own stubs keep the old risk). `scenehook_describe` (end of `//wards status`) ends with `thunk`, `pinned` or `unregistered`. Wards refuses DLLs other than 0.15.2. Version `0.3.1-test4`. No visual change; no new tunables.
- Checks: `luac5.1 -p` all .lua PASS; `lua5.1 tests/test_wards.lua` 313/313 (new: 0.15.1 DLL refused); `lua5.1 tests/test_debuffs.lua` 37/37; native/ builds -Werror clean (i686-w64-mingw32-g++ 13-win32); test_property + test_stroke PASS; new `native/tests/test_thunk.cpp` (g++ -m32) 27/27 PASS: runs the thunk bytes for slots 0/1/17/63, checks esp and callee-saved registers, owner unregistering inside draw_scene (thunk returns without calling into the module), slot reused inside draw_scene (new module's walk runs); a mutated thunk without the null check segfaults, so the test can fail. Disassembly of the built DLL: `owner_dispatch` makes no trampoline call and ends in plain `ret`. Shipped DLL sha256 `e5c03f0f3b79f59dba0a928a98ccdd369acb963546465a23dbd3a8a99cc2162e`, 219,150 bytes. Host only.
- TargetSC needs the same header (DLL 0.16.1) or it can still crash when TargetSC itself is unloaded while it drives the frame: patch for Skillchains `development/targetsc-lit-disc` delivered separately (not pushed there: attach with push denied).
- Pending (A): everything in game. Test3's front-arc direction and Slow's turning direction still unreported.
- Next: A's Test3 next steps (fixed debuff order, anatomical anchors per race).

## Test4 checklist

- [ ] Close every client, unzip Test4 into addons (replaces `libs/_Wards.dll`), start the game. `//wards status`: does the last line say `TargetSC 0.15.2 running` and end with `thunk`?
- [ ] Debuff previews look exactly as in Test3 (`//wards preview debuff all`)?
- [ ] Unload stress (only after TargetSC is also on 0.16.1, or with TargetSC not loaded): `//lua unload wards`, `//lua load wards`, `//lua reload wards` a few times each. Any crash? If yes, send the Event Viewer entry (module name + fault offset).
- [ ] With both Wards and TargetSC loaded: reload each a few times in different orders. Both keep drawing afterwards?

---

## Current Development Status — 2026-11-23 (America/Chicago)

- Repo/branch: `rerorriM-Mirrorer/Wards` `main` (new repository). Docs/structure only; no addon code change since Test3.
- installed_base: Test3 (Skillchains-branch SHA `d11d6b5`, here `abadbbb` after the history move; A ran it 10:23, Live: "such cool effects", especially Paralysis's buzz and Stun's tilting orbit).
- Changes: Wards history moved here from `rerorriM-Mirrorer/Skillchains` `development/wards-protect-shell` with `git subtree split --prefix=Wards` (that branch was never pushed). Added canon `AGENTS.md` (shared 2026-11-21.3 + REPO block) and `WORKFLOW.md` (2026-11-20.1) from ffxi-NPCmirror main `45ae2eb`; `native/` = renderer source 0.15.1 (TargetSC + SceneHook); tests run from the repo root; CI `.github/workflows/wards-testing.yml`.
- Checks: `luac5.1 -p` all .lua PASS; `lua5.1 tests/test_wards.lua` 312/312; `lua5.1 tests/test_debuffs.lua` 37/37; native/ builds -Werror clean; test_property + test_stroke PASS. Host only.
- Pending (A): front arcs in front of the character? Slow counterclockwise?
- Next (A, 10:23): a fixed top-to-bottom debuff order; anatomical anchors per race (Blind at eye level, Silence at mouth level...). Then the remaining designs (see the Test3 block and the project handoff), party members, enemy HP ring.

---

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
