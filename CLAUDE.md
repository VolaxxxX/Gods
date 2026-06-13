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
  warned in the altar UI).
  Remaining: seed-entry UI, run resume to exact room, cross-pantheon hybrid
  synergies (needs a 2nd pantheon).
- Phases 3–5: not started. See the project brief.

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
