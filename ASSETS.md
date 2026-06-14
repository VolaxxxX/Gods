# Asset shopping list (Phase 4)

The game is fully playable in greybox. This is what to download to dress it up.
**Always verify the license allows free use** (CC0 / OFL / CC-BY with credit).
Prefer **CC0** (no attribution needed). Keep the Web build light.

When you've downloaded something, tell me the pack + where you put it and I'll
wire it in (most audio works automatically via the naming rules below).

---

## 1. SFX — priority (mostly automatic)

**Recommended (CC0, no credit required): Kenney audio packs** — https://kenney.nl/assets
- *Interface Sounds*, *UI Audio* → `ui`, `pickup`, `coin`, `blessing`
- *Impact Sounds* / *RPG Audio* → `hit`, `hurt`, `death`, `door`
- *Sci-fi/Weapon* or *RPG Audio* → `shoot`, `boss`

Also good: https://freesound.org (filter **License: CC0**).

**How to install:** rename to the logical keys and drop into
`assets/audio/sfx/` (e.g. `hit.ogg`, `coin.wav`). Full key list:
`shoot, hit, death, hurt, pickup, coin, blessing, boss, door, ui`.
The `Audio` autoload picks them up automatically — no code needed.

## 2. Music — one looping track per realm + hub

Themed loops (small files, <~1–2 MB each):
- Kevin MacLeod / incompetech — https://incompetech.com (CC-BY, **credit required**)
- OpenGameArt — https://opengameart.org (filter CC0/CC-BY), search "gamelan",
  "koto", "lyre", "andean", "ritual drums"
- Kenney *Music Jingles/Loops* (CC0) for placeholders

**How to install:** `assets/audio/music/<id>.ogg` with ids:
`hub, greece, bali, egypt, norse, japan, aztec`. Auto-loaded & looped.
If you use CC-BY tracks, list credits in a `CREDITS.md`.

## 3. Fonts — quick visual upgrade

Google Fonts (OFL, free commercial) — https://fonts.google.com
- Titles: **Cinzel** (mythic Roman caps) → `assets/fonts/display.ttf`
- UI/body: **Inter** or **Noto Sans** → `assets/fonts/ui.ttf`
(Noto covers many scripts if we localize later.)
I'll hook these into a Godot Theme once present.

## 4. Sprites & tilesets — fully plug-and-play (drop PNGs, no code)

The sprite pipeline is wired: drop a PNG with the right name and it shows;
otherwise greybox is used. So you can add art incrementally, realm by realm.

**Recommended base (CC0): Kenney** — https://kenney.nl/assets
- *Tiny Dungeon*, *Roguelike Characters/Caves/Dungeon*, *1-Bit Pack* — characters,
  tiles, props (CC0, free, no credit).
- itch.io top-down packs are fine too — **check each pack's commercial license**.

Keep ONE coherent style across all six pantheons; differentiate realms by
**palette/tint**, not by art style.

### Where & how (auto-loaded by name)
- **Mobs & player** → `assets/sprites/entities/` — file = entity id
  (e.g. `greece_shade.png`, `bali_rangda.png`, `player.png`). 32×32 normal,
  48×48 miniboss, 64×64 boss. See that folder's README for the full id list.
- **Map tiles per realm** → `assets/sprites/tiles/` —
  `<pantheon>_floor.png`, `<pantheon>_wall.png`, `<pantheon>_obstacle.png`
  (e.g. `egypt_floor.png`). 32×32, seamlessly tileable.
- **Attacks/projectiles** → `assets/sprites/fx/` —
  `projectile_player.png`, `projectile_enemy.png`. 16×16.

Drop the file, (re)open Godot so it imports, run. Sizes aren't strict (sprites
are scaled to the entity/tile), but stay consistent. Animation (multiple frames)
can come later — single-frame PNGs work now.

### Suggested order
1. One realm's tiles (`greece_floor/wall/obstacle`) → instant "real" room.
2. `player.png` + that realm's mobs.
3. `projectile_player/enemy`.
4. Repeat per realm; tell me and I'll help with tinting/consistency.

Item icons & UI sprites: later (a Godot Theme + icon atlas); greybox is fine
for now.

## 5. AI-generated assets (optional)

If you want to generate art via AI, tell me and I'll specify exact
resolution / palette / framing per category so the set stays coherent (and mind
licenses).
