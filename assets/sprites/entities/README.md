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

**Player** — `player.png` (used by all classes), or override per class:
`player_char_warrior.png`, `player_char_hunter.png`, … (ids in `content/characters.json`).

## Sizes
- Normal mobs / player: **32×32 px** (auto-scaled to the entity's radius).
- Minibosses: ~48×48. Bosses: ~64×64.
The sprite is scaled to ~2.2× the entity radius, so exact px isn't critical, but
keep a **consistent style** across all six pantheons (same line weight / shading).
Differentiate realms by palette, not by art style.
