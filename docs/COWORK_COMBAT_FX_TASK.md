# Cowork task — redo combat VFX, projectiles, boss attacks & icons on PixelLab

You are Claude Cowork with a browser + this repo (`volaxxxx/gods`, branch
`claude/sleepy-cannon-vl3l7u`). Goal: replace the basic combat visuals (the little
blue/green dots) with **beautiful, original, animated** combat art made on
**PixelLab (pixellab.ai)** — projectiles, impacts, shockwaves, per-boss signature
attacks (long flames, frost shards, lightning, venom, quakes…), and nicer icons.

The engine is already wired for all of this; **you only supply the PNGs at the
exact paths/filenames below.** Missing files just fall back to greybox, so nothing
breaks — but the point is to fill them all in, beautifully.

---

## 0. Cover ALL of PixelLab — forget nothing
Work through and VERIFY each of these PixelLab areas:
- **Characters** — entity/boss base sprites and their animation sets (idle / walk /
  attack / death) AND the per-attack boss animation sheets (§3C).
- **Create** — scenery / decor / props / tiles / backdrops (§5).
- **Animations** — the VFX: projectiles, impacts, muzzle, slash, shockwaves, the
  per-boss bursts, and the flame/energy strips (§3A–§3C).

At the end, re-open EACH area and confirm every asset was generated **and exported**
(downloaded) into the repo. Do not stop while any listed asset is still missing.

---

## 1. Global art rules (apply to everything)
- **Pixel-art**, one coherent style across all realms — same line weight, shading,
  top-left light. Differentiate realms by **palette only** (see `docs/ASSETS.md`
  and `docs/ART_PROMPTS_TILES.md` §2 for each realm's palette/mood).
- **Transparent background** for everything in this task (FX, projectiles, icons,
  character frames).
- **Moderate contrast** so projectiles/FX pop on the graded, vignetted floors but
  don't blow out.

## 2. File format rules (CRITICAL — the engine parses by shape)
Put every file under `assets/sprites/...` with the EXACT name listed. Overwrite the
existing file (keep the filename).

| Asset kind | Folder | Sheet format the engine expects |
|---|---|---|
| **VFX** (impact, muzzle, slash, shockwave, `burst_*`) | `assets/sprites/fx/` | **Animated**: a square **4×4 grid = 16 frames** (read L→R, top→bottom) **or** a horizontal strip of square frames. ~64px/frame. |
| **Projectiles** (`projectile_*`) | `assets/sprites/fx/` | **Animated** = a **horizontal strip** of square frames (width = N×height) → it cycles + rotates to face its flight. **Static** = a single square. Use animated strips for flames/bolts. ~48–64px/frame. |
| **Boss attack anims** (`<id>_<anim>.png`) | `assets/sprites/entities/` | A **horizontal strip** of square frames, SAME frame size/style as that entity's existing `_idle/_walk/_attack/_death` sheets. |
| **Icons** (`<id>.png`) | `assets/sprites/icons/` | A single **square** (64–128px), readable tiny, transparent. |

After placing files, re-import is automatic in the editor; just commit the `.png`
(the `.import` files regenerate).

---

## 3. The combat assets to (re)make

### 3A. Generic VFX (used everywhere) — make these gorgeous (4×4 animated, transparent)
- `fx/impact.png` — projectile hit spark/flash.
- `fx/muzzle.png` — the player's shot flash (a quick bright bloom).
- `fx/slash.png` — the melee swing arc (a crescent slash).
- `fx/shockwave.png` — **a real expanding shock ring** (the generic boss-burst fallback). This is the "ondes de choc" — make it read as a ground/air shockwave expanding outward.

### 3B. Generic projectiles (animated horizontal strips, transparent)
- `fx/projectile_player.png` — the player's bolt (a clean energetic orb/arrow that spins or pulses).
- `fx/projectile_enemy.png` — generic enemy shot (a darker, menacing orb).

### 3C. Per-boss & per-mini-boss signature attacks
For EACH id below, make THREE things:
1. `fx/projectile_<id>.png` — its themed projectile (animated strip).
2. `fx/burst_<id>.png` — its nova/charge burst (4×4 animated ring/explosion = its shockwave).
3. `entities/<id>_<anim>.png` — one animation strip per listed attack `anim` (the boss body performing that attack), matching its other sheets.

Make each attack **beautiful and ORIGINAL to that boss** — here's the direction:

| Boss / mini-boss | Signature attacks (anim names) | Projectile / VFX direction |
|---|---|---|
| `greece_hydra` (boss) | venom_spray, regen_heads, coiling_lunge | dripping **green venom globs** (animated); burst = toxic green ring |
| `greece_cyclops` (mini) | boulder_hurl, ground_stomp | tumbling **boulders**; burst = dust **shockwave** from the stomp |
| `bali_rangda` (boss) | curse_of_leyak, cackling_hex, barongs_bane | **purple curse-fire** bolts (animated); burst = violet hex ring |
| `bali_bhuta_lord` (mini) | spirit_wail, grave_reach | ghostly **spirit wisps**; burst = pale spectral ring |
| `egypt_apophis` (boss) | solar_eclipse, devouring_coil, chaos_scarabs, **venom_breath** | **LONG ANIMATED FLAME** strip for the breath (this is the "longues vraies flammes") + golden solar bolts; burst = solar-eclipse ring |
| `egypt_sphinx` (mini) | riddle_beams, sand_veil_dash | glowing **glyph/energy beams** (long animated strip); burst = sand swirl |
| `norse_fenrir` (boss) | gleipnir_snap, frost_bite_dash, pack_howl | **frost shards / ice spikes** (animated); burst = **ice-shatter shockwave** |
| `norse_troll` (mini) | rock_throw, quake_slam | hurled **rocks**; burst = ground-crack **shockwave** |
| `japan_orochi` (boss) | eight_head_volley, sake_flood, kusanagi_cut | **blue lightning/water bolts** (animated); burst = storm ring |
| `japan_tengu` (mini) | wind_slash, feather_storm | **wind blades / feathers** (animated); burst = gust ring |
| `aztec_cipactli` (boss) | primordial_surge, maw_of_the_deep, blood_tithe | **obsidian/blood spikes** (animated); burst = earth **shockwave** |
| `aztec_jaguar_lord` (mini) | pounce, obsidian_claws | **obsidian claw shards** (animated); burst = jade burst |

(If you want to give MORE bosses a long-flame/long-beam attack like Apophis, that's
welcome — make the animated strip; ask the repo owner to wire the `breath` ability
on that boss in its `content/<realm>/enemies.json`.)

### 3D. Ranged-mob projectiles (animated strips)
Also remake `fx/projectile_<id>.png` for the ranged minions:
`greece_harpy`, `bali_naga`, `japan_kitsune`, `aztec_eagle_warrior`.

---

## 3E. PLAYER characters — weapon-appropriate sprites + DIRECTIONAL attack anims
Right now only the Hunter has its own sprite; the others fall back to a generic
sword sprite, so a ranged soul looks like it's throwing swords (wrong). Per
playable character `<id>` in {char_wanderer, char_warrior, char_hunter,
char_swift}, into `assets/sprites/entities/`, each a horizontal strip of square
frames matching the existing sheets:
- `player_<id>.png` (idle), `player_<id>_walk.png`, `player_<id>_death.png`,
  `player_<id>_dash.png`.
- **Directional attack swings** (the engine plays these by aim):
  `player_<id>_attack_side.png`, `player_<id>_attack_up.png`,
  `player_<id>_attack_down.png` (side art faces right; the engine flips it for
  left). Make the swing show the character's OWN weapon:
  - **char_wanderer** (Shade, ranged 1-shot): a staff/wand cast.
  - **char_warrior** (Champion, MELEE): a sword/axe slash.
  - **char_hunter** (Oracle, ranged pierce): a bow draw-and-loose.
  - **char_swift** (Revenant, ranged 3-shot): twin pistols/daggers throw.
- **Projectiles must match the weapon, NOT swords** — the ranged souls fire
  energy/arrows, so make `fx/projectile_player.png` a clean **energy bolt /
  arrow** (animated strip), never a flying sword.

## 4. Icons — make them pro (square, transparent, readable tiny)
Regenerate **every existing file** in `assets/sprites/icons/` (keep each filename).
They cover: per-deity **boons** (e.g. `greece_zeus_chain`, `egypt_horus_strike`…),
per-realm **items/relics** (e.g. `norse_mjolnir`, `aztec_sun_stone`…), and the
**doors** (`door_treasure`, `door_boon`, `door_vigor`). Each should read clearly at
~40px inside its gold medallion frame (the game already frames them). List the
folder first, then redo each one better; don't miss any.

---

## 5. Scenery / decor (PixelLab "Create") — verify & top up
The realms already have tiles/props/portraits. In **Create**, verify each realm has
its decor and make any that look weak nicer (same palette):
- `assets/sprites/props/<id>.png` (e.g. `greece_column`, `egypt_urn`, …) — grounded, transparent.
- Optional polish: per-realm ending backdrops `assets/sprites/endings/<realm>.png`
  (see `docs/ART_PROMPTS_ENDINGS.md`) and any tile variants (`docs/ART_PROMPTS_TILES.md`).

---

## 6. EXPORT VERIFICATION (do not skip — this is half the job)
The frequent failure is generating art on PixelLab but never exporting it into the
repo. So, explicitly:
1. For EVERY asset above, confirm the PNG is **downloaded and saved at the exact
   path/filename** in the repo (overwriting, transparent bg, correct sheet shape).
2. Re-open **each** PixelLab section (Characters, Create, Animations) and tick off
   that nothing generated there was left un-exported.
3. Cross-check against this doc's lists; produce a short report of: created,
   replaced, still-missing. Keep going until "still-missing" is empty.
4. `git add -A && git commit && git push` to `claude/sleepy-cannon-vl3l7u`. Commit
   only the `.png` files (the `.import` are regenerated by Godot).
5. If you can run Godot: `godot --headless res://tests/test_main.tscn` should print
   `39 checks, 0 failed`, and the Web export must still build.

Deliver beautiful, animated, per-boss-distinct combat art — and prove every piece
made it into the repo.
