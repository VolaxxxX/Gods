# Entity sprites (mobs + player)

Drop PNGs here; the game auto-shows them, else uses the greybox circle.
Filename = the entity id. Top-down, centered, transparent background.

**Mobs** — `<entity_id>.png`. Ids come from `content/<pantheon>/enemies.json`, e.g.:
- Greece: `greece_shade.png`, `greece_skeleton.png`, `greece_harpy.png`,
  `greece_cyclops.png` (miniboss), `greece_hydra.png` (boss), `greece_hydra_head.png`
- Bali: `bali_leyak.png`, `bali_bhuta.png`, `bali_celuluk.png`,
  `bali_bhuta_lord.png`, `bali_rangda.png`
- Egypt: `egypt_scarab.png`, `egypt_shabti.png`, `egypt_mummy.png`,
  `egypt_sphinx.png`, `egypt_apophis.png`
- Norse: `norse_helhound.png`, `norse_draugr.png`, `norse_jotunn.png`,
  `norse_troll.png`, `norse_fenrir.png`
- Japan: `japan_onibi.png`, `japan_kappa.png`, `japan_oni.png`,
  `japan_tengu.png`, `japan_orochi.png`
- Aztec: `aztec_obsidian.png`, `aztec_jaguar.png`, `aztec_tzitzimitl.png`,
  `aztec_jaguar_lord.png`, `aztec_cipactli.png`

**Generic monster (least work)** — `enemy.png`: used for ANY mob without its own
file, auto-tinted by that enemy's colour. So one sprite can stand in for all
enemies until you make bespoke ones (per-id files take priority).

**Player** — `player.png` (used by all classes), or override per class:
`player_char_warrior.png`, `player_char_hunter.png`, … (ids in `content/characters.json`).

## Animations (optional, auto-detected)
Drop per-animation **horizontal spritesheets of square frames** and the entity
animates automatically (walk when moving, attack when firing, death on kill):
- `<id>_idle.png`, `<id>_walk.png`, `<id>_attack.png`, `<id>_death.png`
- Player: `player_idle.png` … (or `player_<character_id>_idle.png` per class)
- Frame count is inferred as **width ÷ height** (e.g. 8 frames of 64px → 512×64).
- idle/walk loop; attack/death play once (the entity waits for `death` before
  despawning). The sprite flips horizontally with facing.
- If animation sheets exist they take priority over the static `<id>.png`.
- Missing animations are fine (it falls back to idle, then to static/greybox).

### Bespoke boss attacks (per-ability animations)
Bosses/minibosses can play a different animation per signature attack. Each
ability in `content/<pantheon>/enemies.json` carries an `anim` name; drop a sheet
`<boss_id>_<anim>.png` and that attack uses it (else it falls back to `attack`).
Plays once, like `attack`. e.g. `greece_hydra_venom_spray.png`,
`egypt_sphinx_sand_veil_dash.png`. Full attack→sheet list is in the design log.

## Sizes
- Normal mobs / player: **32×32 px** (auto-scaled to the entity's radius).
- Minibosses: ~48×48. Bosses: ~64×64.
The sprite is scaled to ~2.2× the entity radius, so exact px isn't critical, but
keep a **consistent style** across all six pantheons (same line weight / shading).
Differentiate realms by palette, not by art style.
