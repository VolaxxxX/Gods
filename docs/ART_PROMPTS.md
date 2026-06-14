# Art prompt bible (PixelLab)

Generate every sprite with the SAME settings for a coherent art direction.
Legend: 🟥 = FINAL BOSS (2 phases) · 🟧 = PALIER/MINI-BOSS · ▫️ = normal mob.

## PixelLab settings (keep identical for ALL)
- Generation Mode: **v3**
- Camera View: **Low Top-Down** (3/4 — readable, suits a top-down game)
- Sprite Size: **48×48** mobs · **64×64** minibosses & bosses · 16×16 projectiles
- Detail: **Highly detailed** · Outline: **Default**
- Export: front/down-facing frame, **transparent PNG**, named EXACTLY as the key
  (e.g. `greece_hydra.png`) into `assets/sprites/entities/` (tiles → `tiles/`,
  projectiles → `fx/`).
- For max consistency: make one you like, then "Use as style" for the rest.

Append the realm palette to each description.

| Realm | Palette to add |
|---|---|
| Greece | marble grey, gold, bronze |
| Bali | volcanic brown, gold, red and black |
| Egypt | sandstone, turquoise, gold |
| Norse | cold blue, ice white, dark red |
| Japan | red, black, white |
| Aztec | jade green, gold, blood red |

---

## Greece (palette: marble grey, gold, bronze)
- ▫️ `greece_shade` — ghostly grey wraith, tattered hooded cloak, glowing pale-blue eyes, floating
- ▫️ `greece_skeleton` — skeleton warrior with round bronze shield
- ▫️ `greece_harpy` — winged bird-woman harpy, brown feathers
- ▫️ `greece_hydra_head` — single green serpent head on a neck
- 🟧 `greece_cyclops` — one-eyed cyclops giant with a stone club
- 🟥 `greece_hydra` — Lernaean hydra, multi-headed green serpent dragon, menacing

## Bali (palette: volcanic brown, gold, red and black)
- ▫️ `bali_leyak` — flying demon head with trailing entrails, glowing eyes
- ▫️ `bali_bhuta` — small fanged demon spirit
- ▫️ `bali_celuluk` — bald long-fanged witch hag
- 🟧 `bali_bhuta_lord` — large horned demon brute
- 🟥 `bali_rangda` — Rangda demon queen, long fangs and tongue, fiery white hair, fearsome mask

## Egypt (palette: sandstone, turquoise, gold)
- ▫️ `egypt_scarab` — giant scarab beetle
- ▫️ `egypt_shabti` — animated mummiform funerary statue
- ▫️ `egypt_mummy` — bandaged mummy, arms forward
- 🟧 `egypt_sphinx` — sphinx, winged lion with a pharaoh head
- 🟥 `egypt_apophis` — Apophis, colossal coiled chaos serpent, glowing eyes

## Norse (palette: cold blue, ice white, dark red)
- ▫️ `norse_helhound` — black hellhound wolf, glowing eyes
- ▫️ `norse_draugr` — undead viking warrior with an axe
- ▫️ `norse_jotunn` — frost giant
- 🟧 `norse_troll` — mountain troll brute with a club
- 🟥 `norse_fenrir` — Fenrir, giant monstrous wolf, broken chains, frost breath

## Japan (palette: red, black, white)
- ▫️ `japan_onibi` — floating blue flame spirit, will-o-wisp
- ▫️ `japan_kappa` — kappa, turtle-like green river imp
- ▫️ `japan_oni` — oni, red horned ogre with an iron club
- 🟧 `japan_tengu` — tengu, long-nosed winged yokai
- 🟥 `japan_orochi` — Yamata-no-Orochi, eight-headed serpent dragon

## Aztec (palette: jade green, gold, blood red)
- ▫️ `aztec_obsidian` — animated obsidian shard golem
- ▫️ `aztec_jaguar` — jaguar warrior, feline
- ▫️ `aztec_tzitzimitl` — tzitzimitl, skeletal star demon
- 🟧 `aztec_jaguar_lord` — elite ornate jaguar knight
- 🟥 `aztec_cipactli` — Cipactli, primordial crocodile earth monster

---

## Player & FX
- `player` (48) — hooded wandering soul, dark robe, glowing core, no face
- `projectile_player` (16) — small glowing energy orb, blue-white
- `projectile_enemy` (16) — small glowing energy orb, red-orange

## Tiles (32×32, seamless; tiles/ folder). Per realm: `<realm>_floor`, `<realm>_wall`, `<realm>_obstacle`
- Greece: cracked marble floor / marble brick wall / broken column
- Bali: volcanic stone floor / carved stone wall / mossy statue block
- Egypt: sandstone floor / hieroglyph wall / sarcophagus block
- Norse: icy stone floor / frosted rune wall / ice boulder
- Japan: dark wood shrine floor / red lacquer wall / stone lantern block
- Aztec: carved jade floor / temple stone wall / obsidian block

(One neutral generic set `floor/wall/obstacle` also works — it's auto-tinted per
realm; only make bespoke realm tiles if you want.)
