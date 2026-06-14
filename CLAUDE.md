# CLAUDE.md — Gods (mythology roguelike)

Authoritative architecture & decision log. Read this first every session.
Keep it updated when you make a structural decision.

## 1. What this is

A free, mobile-first action roguelike themed on the world's mythologies and
their underworlds. The player is a soul traveling the afterlives of six
pantheons. Feeling reference: *The Binding of Isaac* (room loop, twin-stick
shooting, item synergies) + *Hades* (nervous combat, divine blessings,
replay-driven narrative).

- **Language of the game: ENGLISH only.** All displayed text goes through a key
  system (`Loc`), never hardcoded. One translation file (`localization/en.json`).
- **Free-to-play**, no ads, no IAP, no paywall.
- **Distribution priority:** (1) Web HTML5 in browser, (2) Android APK. iOS is
  covered for free via the Web build (Safari). Currently **private** (two
  players), not published.
- **Orientation:** landscape.

## 2. Locked technical decisions

| Decision | Choice | Why |
|---|---|---|
| Engine | Godot 4.x, GL Compatibility renderer | Best Web/mobile target; text scenes; one codebase for Web/Android/iOS |
| Language | GDScript | C# Web export is unstable; Web is priority |
| View | **Top-down 2D** | Best perf on low/mid Android; simplest twin-stick touch; readable hitboxes |
| Content data | **JSON** (not `.tres`) | Hand-authorable, web-safe, headless-testable, data-driven |
| Procedural scope | **Floor layout ONLY** | Rooms, decor, enemy placement are authored by hand; the generator only picks & connects hand-made room templates (Isaac model) |
| RNG | Centralized seeded `RNG` autoload | Deterministic daily seeds / seed sharing |

### Pantheon direction (locked)
- **Greece** = Phase 1 prototype (best documented).
- **Americas** = **Aztec** slice.
- **Europe** = **Norse** only (Celtic/Slavic are possible later additions).
- Full set: Greece, Egypt, Japan, Norse, Aztec, Bali/Indonesia.

## 3. Architecture principles (non-negotiable)

1. **Data-driven.** Enemies, items, blessings, deities, rooms, biomes are data
   (JSON parsed into typed objects), not hardcoded. Adding content = adding data.
2. **Modularity per pantheon.** Each pantheon is a self-contained content module
   plugged into a common core. A pantheon can be toggled without breaking others.
3. **Layered separation:** core engine services / roguelike systems / themed
   content / presentation. **No game logic in the presentation layer.**
4. **Composition over inheritance.** Reusable components (health, movement,
   weapon, hurtbox, AI) attached to entities.
5. **Procedural = floor layout only.** Everything inside rooms is authored.
6. **Deterministic seed** through the central `RNG`.
7. **Robust versioned saves** (meta-progression + run resume, migratable).
8. **Critical systems are testable headless:** floor generation, item synergies,
   damage. See `tests/`.

## 4. Layout

```
core/            Engine services (autoloads): events, rng, i18n, data, input,
                 save, run, scene routing. No theme content here.
components/       Reusable entity components (health, movement, weapon, ...).
systems/          Roguelike systems: floor generation, damage, combat helpers.
entities/         Player, enemies, projectiles (code-built, greybox visuals).
scenes/           Screen scenes loaded by SceneRouter (boot, hub, run).
ui/               HUD + touch controls (presentation only).
presentation/     Greybox drawing helpers, palette.
localization/     en.json (key -> English text).
content/          Data modules per pantheon (JSON) + manifest.json.
tests/            Headless test runner + system tests.
```

## 5. Autoloads (singletons), load order

`Events` -> `RNG` -> `Loc` -> `GameData` -> `GameInput` -> `SaveManager` ->
`RunManager` -> `SceneRouter`.

- **Events** — global signal bus (decouples systems).
- **RNG** — seeded deterministic RNG with named independent streams.
- **Loc** — localization; `Loc.t("key")`.
- **GameData** — loads `content/manifest.json`, parses all data files into typed
  registries keyed by id.
- **GameInput** — abstract twin-stick input (touch + keyboard) → move/aim/fire.
- **SaveManager** — versioned meta-progression + run resume.
- **RunManager** — current run state (seed, floor, room, player stats).
- **SceneRouter** — scene transitions.

## 6. Conventions

- Files & dirs: `snake_case`. Classes (`class_name`): `PascalCase`.
- One `class_name` per data type so editor/tools can see them.
- Signals: past-tense or noun events (`died`, `room_cleared`, `damage_taken`).
- No magic numbers that should be data — push to JSON.
- Greybox first: code-drawn colored shapes. The game must be fun before any art.
- Commit atomically with clear messages.

## 7. Content authoring (JSON)

Each file: `{ "type": "<category>", "entries": [ {...}, ... ] }`.
Categories: `entity`, `item`, `deity`, `blessing`, `biome`, `room`.
List every content file in `content/manifest.json`. `GameData` reads the
manifest, then each file, routing entries by `type` to the right registry.
See `core/data/*_data.gd` for the schema each category expects (`from_dict`).

## 8. Testing

Headless: `godot --headless --script res://tests/test_runner.gd`.
Critical coverage: RNG determinism, damage calculation, floor generation
(reachability, quotas, determinism).

## 9. Build / export

`export_presets.cfg` defines a **Web** preset (priority) and **Android**.
Web build must stay light and load fast; test in a real browser, not just the
editor. Audio must unlock on first tap (Web autoplay policy) — handled in boot.

## 10. Status (update each phase)

- **Phase 0 — Foundations:** project, autoloads, data system, seeded RNG, i18n,
  Web export preset, hub scene, tests. **DONE (pending in-editor/Web verification
  by maintainer — Godot not available in the build container).**
- **Phase 1 — Greek vertical slice (greybox):** twin-stick move + shoot, 3
  enemies + Hydra boss, generated floor, room clear → doors, death → hub, plus
  juice (screenshake/hit-stop/damage-flash/death pops). **DONE (pending Web/editor
  verification).**
- **Phase 2 — Roguelike systems:** **STARTED.** Done: `StatBlock` aggregation,
  item pickups + live stat application, data-driven `SynergyEngine`, divine pacts
  (altar blessing choice), on-hit/passive effects (chain lightning, deflect),
  **gold drops + priced shops**, **sacrifice altars** (HP → item), and
  **meta-progression** (karma earned per run → permanent reincarnation upgrades,
  data-driven `MetaUpgradeData`, bought at the hub, applied to base stats),
  **weighing of the soul** (`SoulJudgment` turns play style into a verdict +
  bonus karma; style tracked via kills/no-damage clears/shop buys), and
  **syncretism rivalries** (mixing rival deities' boons applies a curse modifier,
  warned in the altar UI), **seed-entry UI**, and **run resume to the exact room**
  (snapshot stores current room + cleared set; floor regenerated from seed).
  **Phase 2 complete.**
- **Phase 3 — Content expansion:** **STARTED.** 2nd pantheon **Bali/Indonesia**
  added as a self-contained module (biome, 3 enemies + Rangda boss, deities,
  blessings, items, synergy, rooms). Hub has a **realm selector**; **multi-biome
  runs** chain realms after each boss (non-linear branches, items/blessings/HP
  carry over, +50% heal on descent), which unlocks **cross-pantheon hybrid
  synergies** (`content/cross/synergies.json`, evaluated over ALL synergies so
  tag combos fire across pantheons). Cultural note: Bali is a living tradition —
  see the `_note` in `content/bali/biome.json`. **ALL SIX pantheons now exist**
  as data modules: Greece, Bali, Egypt (Duat), Norse (Helheim), Japan (Yomi),
  Aztec (Mictlan) — each with biome, 3 enemies + boss, 5–6 deities + blessings,
  4 relics, a synergy, rooms. Rivalries per pantheon; cross-pantheon hybrid
  synergies bridge several. Runs span up to 3 of the 6 realms (branch choice).
  **Playable characters** (data-driven `CharacterData`: Wanderer/Warrior/Hunter/
  Swift, chosen at the hub, starting-kit stat modifiers via StatBlock) and
  **ranged attacks** (data-driven `ranged`/`range_*` on entities; all 6 bosses +
  Greek harpy fire enemy projectiles via an enemy-faction WeaponComponent).
  **Bespoke boss/miniboss patterns** (data-driven `abilities` on entities:
  `nova`, `spread`, `summon`; cooldowns shorten when enraged <40% HP). Each boss
  has a signature kit (Hydra summons heads + nova, Orochi 8-shot nova, Fenrir
  summons helhounds, etc.). **Cursed rooms** (free loot guarded by extra foes)
  and **god encounters** (clearing a combat room may make a realm god offer 2
  boons, or unleash a WRATH wave rewarding gold + an item).
  **Hades-style zone structure:** each pantheon = `floors` sub-maps (default 2).
  Floor 1 ends with a **palier boss** (the pantheon's `miniboss_id`); clearing it
  regenerates a NEW map of the SAME zone (heal, keep everything). The final floor
  ends with the **true boss in 2 phases** (`phase2_abilities` + burst at
  `phase2_at` HP). The realm-choice (next pantheon) appears only after the final
  boss. Floors are short (`room_count` 6) to keep runs ~15–30 min.
  Shared room library (`content/rooms_common.json`, pantheon "") gives every
  realm a common pool of varied authored layouts + its own (palette = identity).
  Remaining Phase 3 polish: secret rooms.
- **Phase 4 — Art & audio:** **STARTED (code-only).** Data-driven `Audio`
  autoload: event-driven SFX + per-realm looping music, auto-loaded from
  `assets/audio/{sfx,music}/` by filename (silent if absent), volumes persisted
  in `meta.options` and tweakable from the pause menu. Asset inventory written
  in `ASSETS.md`. Sprites/tilesets/fonts/music files themselves are **blocked on
  the maintainer** (sourcing). No procedural visuals (greybox stays until art).
- **Phase 5 — Distribution:** not started (Web/Android export presets exist).

### Progression aggregation (Phase 2)
`RunManager` owns `owned_items` / `chosen_blessings`. `collect_modifiers()` and
`collect_effects()` merge item modifiers + blessing modifiers + active synergy
grants (via `SynergyEngine`). The player rebuilds a `StatBlock` from
`BASE_STATS` + these modifiers on `item_picked_up` / `blessing_chosen`. New stats
need no code — just use the stat name (with `_add`/`_mult`) in data.

### Known limitation
The dev container has **no Godot binary**, so the editor, the headless tests, and
the Web export have **not been run** here. All code is written to Godot 4.3
GDScript syntax. First action on a machine with Godot: open the project (let it
import), run `tests/test_runner.gd` headless, then test the Web export.
