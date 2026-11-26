# Wards combat packet notes

This document records the deliberately narrow packet classifier used by the Protect VFX proof of concept. It is not a general combat parser.

## Source packet

Windower's packet definitions identify incoming packet `0x028` as the action packet. The `Category` enumeration defines:

| Value | Meaning | POC handling |
| ---: | --- | --- |
| 1 | Melee attack | Included |
| 2 | Ranged attack finish | Included |
| 3 | Weapon skill finish | Excluded pending separate physical/magical classification |
| 4 | Casting finish | Excluded |
| 5 | Item finish | Excluded |
| 6 | Job ability | Excluded |
| 11 | NPC TP finish | Excluded pending separate physical/magical classification |
| 13 | Avatar TP finish | Excluded |

The packet contains a target count, target entity IDs, per-target action counts, and per-action `Param` and `Message` fields. For a local recipient, Wards matches `Target N ID` against `get_mob_by_target('me').id`. It sums `Target N Action M Param` only when the corresponding `Message` equals `1` and the damage parameter is positive. This covers multi-hit melee/ranged packet completions without responding to actions on other targets or to zero-damage/miss messages.

Windower's `actions.lua` documentation includes an example that treats action `message == 1` as a hit and `action.param` as its damage amount. The POC uses the lower-level `packets.parse('incoming', modified or data)` interface and the packet's named fields. The event handler ignores packets whose `blocked` flag is true, so it does not animate for a packet another addon prevented from reaching the game.

## Intensity

The VFX state machine accepts a normalized integer intensity independently of packet parsing:

`vfx.trigger_impact(state, intensity, now)`

Values outside 1-9999 are rejected. The packet adapter currently maps total positive landed damage to:

`intensity = clamp(round(total_damage * 10), 1, 9999)`

The renderer response uses a power curve:

`strength = (intensity / 9999) ^ 1.6`

This is a tunable visual-severity mapping only. It is not a game-mechanics estimate of prevented damage.

## What the packet cannot tell us

The action packet reports the damage result that landed. It does not provide the counterfactual amount that the same hit would have dealt if Protect had not been active, nor a field containing damage prevented by Protect. We therefore cannot calculate actual prevented damage from these events alone. A proper counterfactual would need a reliable reconstruction of attack/defense, level correction, attack type, and other active modifiers; the POC does not attempt that.

Do not label the current mapping "damage prevented." It is only a proxy for the severity of the observed hit.

## Exclusions and next verification

The first adapter includes only categories 1 and 2. Weapon skills, monster TP moves, spells, items, and job abilities remain excluded even if an individual move may deal physical damage. A later classifier should identify the actual damage type for each ability rather than assuming every TP move is physical.

The packet event and field names are based on Windower's current source:

- [Windower packet fields: incoming action packet 0x028](https://github.com/Windower/Lua/blob/dev/addons/libs/packets/fields.lua)
- [Windower actions helper and category strings](https://github.com/Windower/Lua/blob/dev/addons/libs/actions.lua)
- [Windower packet parser](https://github.com/Windower/Lua/blob/dev/addons/libs/packets.lua)

In-game verification remains required for the observed categories, timing relative to buff removal, multi-hit behavior, and whether the recipient entity ID always identifies the expected character on this client.
