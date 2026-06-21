# Brief for Claude Code — Asset status + full map overhaul

This is a task brief. Goal: make the rooms look like real game maps, not a flat
texture stretched over a rectangle. Plus a checklist of remaining art gaps.

## 1. Current asset status (already in the repo, branch `claude/sleepy-cannon-vl3l7u`)

- **Entities** — 192 PNGs in `assets/sprites/entities/`: ~32 creatures across the
  6 pantheons (normal mobs, minibosses, bosses with per-attack animation sheets),
  plus 3 player classes. Static `<id>.png` + `<id>_idle/walk/attack/death.png`
  spritesheets + boss `<id>_<anim>.png`. Auto-loaded by id.
- **Portraits** — 33 in `assets/sprites/portraits/` (deities + `narrator`).
- **Props** — 16 Greek props in `assets/sprites/props/`.
- **Tiles** — `floor/wall/obstacle` (+ `_alt`) for all 6 pantheons already present.
- UI assets + font present. All gameplay systems work.

## 2. The map problem (root cause)

`scenes/room/room.gd::_draw()` renders rooms as:
- **floor** = one tile texture `draw_texture_rect(..., tile=true)` repeated flat
  across the whole rectangle;
- **walls** = 4 border bars (`draw_texture_rect` on N/S/E/W rects);
- **doors** = a `draw_circle`; **obstacles** = isolated 1-tile cells.

`assets/sprites/tiles/README.md` confirms it: *"Tileable PNGs drawn repeated across
the room."* Rooms are fixed 13×9 boxes. No autotiling, no edges/corners, no depth,
no variation. That flat repeated-texture-on-a-box is exactly the "ugly rectangle"
look to fix.

## 3. Objective — full overhaul (real tiled maps)

Replace the code-drawn greybox rendering with a proper Godot 4 **TileMapLayer +
TileSet** pipeline, with autotiling, wall depth, decoration and atmosphere. Keep a
greybox fallback when art is missing so the game never breaks.

### 3.1 Tiling & autotiling
- Migrate room rendering to **`TileMapLayer`** (Godot 4.3+) — separate layers:
  `floor`, `walls`, `decor`, `overlay`. In-game cell is 64px.
- Build a **`TileSet` with terrain sets (autotiling)** for floor and walls so the
  engine places correct **edges, inner/outer corners and transitions** automatically
  instead of a flat fill. Drive it from the floor graph's room rectangle + obstacle
  grid (the `RoomTemplate.grid`, `O` = obstacle/wall cell).
- **Floor variety:** 3–4 floor variants per pantheon placed with weighted random
  (e.g. 80% plain, 20% cracked/detailed) to kill the repeating-texture look.

### 3.2 Walls with depth (the biggest visual win)
- Render walls as **top face + front ("south") face + corner pieces**, not flat
  bars, so walls read as 3D-ish with a lip and a cast shadow onto the floor.
- Add a soft **drop shadow** under wall bases and obstacles.
- Doors become a real **arch/door sprite** per pantheon with an open/close state
  (locked = closed gate art), replacing the drawn circle.

### 3.3 Decoration & atmosphere
- **Decor layer (Y-sorted):** scatter the existing props (already supported by
  `_scatter_props()`), placed off the walking path, with shadows. Add more props
  per pantheon (see gaps below).
- **Lighting:** `CanvasModulate` for biome mood + `PointLight2D` on light sources
  (braziers, lava, runes). Soft **ambient shadow blob under each entity**.
- **Vignette** (screen-space) + subtle ambient **particles** (dust motes, embers,
  fireflies, snow) per pantheon.
- Keep the post-miniboss `_alt` / corrupted-tint variant behaviour.

### 3.4 Room shapes & layout
- Enrich `RoomTemplate` grids beyond the 13×9 box: **L-shapes, pillared halls,
  alcoves, wide arenas, chokepoints**. Add several authored templates per room type
  and pick at random. Distinct **boss-arena** layouts.
- Make sure `floor_generator` / `tests/test_floor_generator.gd` still pass.

## 4. New tile art needed (so it actually looks good)

Single 32px textures can't autotile. Produce **tileset atlases** (PixelLab or hand),
in the established style, cell 64px:
- Per pantheon **floor atlas**: 3–4 variants + edge/corner pieces.
- Per pantheon **wall atlas**: top face, front face, inner/outer corners, end caps.
- Per pantheon **obstacle** set + a **door/arch** sprite.
- Keep one coherent style across all six realms; differentiate by palette, per
  `ASSETS.md`.

## 5. Remaining asset gaps (no source art yet)

- **Aztec mobs:** `aztec_obsidian`, `aztec_jaguar`, `aztec_tzitzimitl`,
  `aztec_cipactli` (boss), `aztec_jaguar_lord` (miniboss).
- **Greek deity portraits:** `greece_athena`, `greece_artemis`.
- **Player:** `player_char_wanderer` + a generic `player.png`.
- **Props for 5 pantheons** (only `greece` exists): bali / egypt / norse / japan /
  aztec — ids listed in each `content/<pantheon>/biome.json`.
- **Boss attacks with no matching animation** (currently fall back to `attack`):
  `greece_hydra_venom_spray`, `egypt_apophis_chaos_scarabs`,
  `japan_orochi_sake_flood`, `japan_orochi_kusanagi_cut`.

## 6. Acceptance
- A room no longer looks like one texture on a box: visible tiled edges/corners,
  walls with depth + shadow, scattered props, vignette/lighting, varied layouts.
- Greybox fallback still works when a tile/atlas is absent.
- Headless tests pass: `godot --headless --script res://tests/test_runner.gd`.
- Provide before/after screenshots of a Greece room.

Mapping of every PixelLab sprite → repo path is in `docs/name_mapping.csv`;
full coverage in `docs/coverage_report.json`.
