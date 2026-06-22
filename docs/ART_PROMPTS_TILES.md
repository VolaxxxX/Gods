# PixelLab prompts — tile ATLASES for real autotiling

Goal: replace the single 64px floor/wall/obstacle tiles with proper **tilesets**
so the engine can autotile (edges, corners, transitions), vary the floor, and
give walls depth. This is the last art-dependent step for "beautiful maps"
(see `MAPS_TODO_FOR_CLAUDE_CODE.md` §2).

When these exist, I (Claude Code) will build a Godot **TileSet + TileMapLayer**
with terrain sets and wire it into `scenes/room/room.gd` (keeping the current
code-drawn renderer as the greybox fallback). **No code is blocked on anything
else — only on these images.**

---

## 0. GLOBAL SPECS (apply to every prompt)

- **Top-down / slight 3-4 angle**, the same view as the existing sprites.
- **Cell = 64×64 px**, **seamlessly tileable** (edges wrap). Generate at 64 or a
  clean multiple (128) and I downscale.
- **Pixel-art**, one coherent style across all six realms — **same line weight,
  same shading, same light direction (top-left)**. Differentiate realms by
  **palette only**, not by style (per `ASSETS.md`).
- Transparent background only where noted (props/doors). Floor/wall pieces are
  full-bleed (no transparency).
- Keep contrast moderate so entities and projectiles pop on top.

### Files to deliver (naming the engine will expect)
Per realm `<r>` in {greece, bali, egypt, norse, japan, aztec}, into
`assets/sprites/tiles/`:

| Piece | File | Count | Notes |
|---|---|---|---|
| Floor base | `<r>_floor.png` | 1 | already exists — keep |
| Floor variants | `<r>_floor_b.png`, `<r>_floor_c.png` | 2 | cracked / detailed, same base palette |
| Wall top | `<r>_wall.png` | 1 | already exists — the top surface |
| Wall front face | `<r>_wall_face.png` | 1 | the vertical south-facing side (lit top, dark base) |
| Wall corners | `<r>_wall_corner.png` | 1 | a 64×64 outer-corner piece (2 faces) |
| Obstacle / cover | `<r>_obstacle.png` | 1 | already exists — a raised block |
| Door / arch | `<r>_door.png` | 1 | transparent bg, an open archway, ~96×96 |
| (post-boss alt) | `<r>_*_alt.png` | — | already exist; regenerate variants the same way if desired |

That's **5 new tile files per realm** (2 floor variants + wall face + wall
corner + door) = **30 images**. Floors/walls/obstacles base already exist.

---

## 1. REUSABLE PROMPT TEMPLATES

Replace `{REALM PALETTE/MOOD}` with the per-realm block in §2.

**Floor variant (×2 per realm — "b" cracked, "c" detailed):**
> top-down seamless tileable stone floor tile, 64x64 pixel art, {REALM
> PALETTE/MOOD}, subtle cracks and wear, low contrast so characters read on top,
> consistent top-left lighting, no border, edges tile seamlessly

(For "c" swap "subtle cracks and wear" → "a faint decorative inlay / mosaic
motif of the culture, still low-contrast".)

**Wall front face (`<r>_wall_face.png`):**
> top-down pixel art wall FRONT FACE strip, 64x64, {REALM PALETTE/MOOD} masonry,
> lit stone lip at the very top, darkening toward the bottom, reads as the
> vertical side of a thick wall seen from a 3-4 top-down angle, tileable left-right

**Wall outer corner (`<r>_wall_corner.png`):**
> top-down pixel art wall OUTER CORNER block, 64x64, {REALM PALETTE/MOOD}
> masonry, two visible faces meeting at a corner, lit top-left, drop-shadow edge
> bottom-right

**Door / arch (`<r>_door.png`, transparent):**
> top-down pixel art {REALM} doorway ARCH, ~96x96, transparent background,
> ornate {REALM PALETTE/MOOD} stone/metal frame around a dark open passage,
> symmetric, fits a 64px-wide opening, no floor under it

**Obstacle / cover (if regenerating `<r>_obstacle.png`):**
> top-down pixel art {REALM} cover block, 64x64, a low {REALM PALETTE/MOOD}
> obstacle (crate/altar/rock/idol) the player hides behind, lit top-left, soft
> drop shadow at its base, transparent corners

---

## 2. PER-REALM PALETTE / MOOD BLOCKS

Use the realm's floor/wall/accent hexes for colour guidance.

### Greece — Underworld of Hades
`{REALM PALETTE/MOOD}` = "pale marble and grey-blue stone (floor #1b2230, wall
#3a4a5a) with **gold** Greek-key (meander) accents #d8b25a; cold, hallowed".
Door: marble columns + gold lintel. Obstacle: a broken marble column drum or urn.

### Bali — the Unseen (niskala)
`{REALM PALETTE/MOOD}` = "dark volcanic stone and carved wood (floor #241f1a,
wall #4a3b2a) with **gold** temple-gilt accents #d4af37; warm ember glow".
Door: a split *candi bentar* temple gate. Obstacle: a mossy demon statue or
offering stack. (Respect the living tradition — ornate, not gory.)

### Egypt — the Duat
`{REALM PALETTE/MOOD}` = "sandstone and ochre (floor #2a2418, wall #6b5a2a) with
**turquoise** glyph accents #37c7c0; carved hieroglyph walls, dry".
Door: a pylon gate with hieroglyphs. Obstacle: a sarcophagus or canopic jar.

### Norse — Helheim
`{REALM PALETTE/MOOD}` = "frost-rimed dark stone and ice (floor #1a2230, wall
#3b4a5a) with **pale ice-blue** accents #c0d6e8; cold mist, snow".
Door: heavy timber + iron-banded gate, frost. Obstacle: a runestone or ice shard.

### Japan — Yomi
`{REALM PALETTE/MOOD}` = "dark lacquer and deep crimson (floor #241016, wall
#7a2230) with **bone-white** accents #e8e0d0; shadowed, blighted".
Door: a torii-style red gate. Obstacle: a stone lantern (tōrō) or cracked shrine.

### Aztec — Mictlan
`{REALM PALETTE/MOOD}` = "dark jade-green stone and basalt (floor #16241c, wall
#2a6b5a) with **gold/turquoise** accents #e0c040; carved serpent motifs".
Door: a stepped-pyramid gateway with serpent heads. Obstacle: a skull rack or
sun-stone block.

---

## 3. PRIORITY ORDER (if doing it incrementally)
1. **Greece** full set (it's the prototype realm) → I wire the TileSet + autotile
   and you see the whole pipeline on one realm.
2. Then the other five, same recipe.
3. Floor variants give the biggest anti-repetition win; the wall face/corner give
   the depth; the door sprite replaces the drawn arch.

Drop the PNGs in `assets/sprites/tiles/`, tell me, and I build the autotiling
TileMapLayer (greybox/code-drawn stays as the fallback when a piece is missing).


---
## ✅ WIRED (Claude Code)
The 30 atlas pieces are integrated: rooms now build a real **TileMapLayer floor**
with weighted random variants (`<r>_floor`/`_floor_b`/`_floor_c`, `_alt` on floor 2),
and the renderer uses `<r>_wall_face`, `<r>_wall_corner` and `<r>_door` (arch) sprites.
Greybox/code-drawn rendering remains the fallback when a piece is absent. Verified in Godot.
