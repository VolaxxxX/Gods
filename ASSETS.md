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

## 4. Sprites & tilesets — later (greybox is fine for now)

Only once gameplay/feel is locked. Keep ONE coherent style across all six
pantheons (palette per culture, same line/scale). Candidates:
- Kenney *Tiny Dungeon / Roguelike* tiles & characters (CC0)
- itch.io top-down packs (**check commercial license per pack**)

Needed categories (per the brief): player + enemy sprites, projectiles, item
icons, room tiles/props per pantheon, VFX, UI. We'll define exact sizes/palette
before sourcing so everything stays consistent.

## 5. AI-generated assets (optional)

If you want to generate art via AI, tell me and I'll specify exact
resolution / palette / framing per category so the set stays coherent (and mind
licenses).
