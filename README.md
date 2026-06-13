# Gods

A free, mobile-first action roguelike themed on the world's mythologies and
their underworlds. You play a soul traveling the afterlives of six pantheons.
Feel: *The Binding of Isaac* (room loop, twin-stick shooting, item synergies) +
*Hades* (nervous combat, divine blessings).

- **Engine:** Godot 4.x (GL Compatibility renderer)
- **Targets (priority):** Web HTML5 → Android. iOS is covered via the Web build.
- **Language:** English only, all text via a key system (`localization/en.json`).
- **Status:** Phase 0 (foundations) done; Phase 1 (Greek vertical slice, greybox)
  in progress. See `CLAUDE.md` for the full architecture and decision log.

## Run it

You need [Godot 4.x](https://godotengine.org/download) (standard build).

1. Open the project: `godot --editor` in this folder (or open `project.godot`
   from the Godot project manager). Let it finish importing — this builds the
   global class cache the scripts rely on.
2. Press F5 (or the Play button). The boot screen → hub → **Descend** starts a run.

### Controls
- **Touch / mouse:** left half of the screen = move stick, right half =
  aim + fire stick (floating joysticks). Auto-aim is on by default.
- **Keyboard (desktop):** WASD to move, hold left mouse to aim & fire.

## Tests

Critical systems (RNG determinism, damage math, floor generation) are tested
headless — no rendering required:

```sh
godot --headless --script res://tests/test_runner.gd
```

Exits non-zero if any check fails.

## Export

`export_presets.cfg` ships a **Web** preset (priority) and an **Android** preset.
Install the matching export templates in the editor first
(`Editor → Manage Export Templates`), then `Project → Export`.

- Web: outputs `builds/web/index.html`. Serve over HTTPS with cross-origin
  isolation headers (the preset enables the PWA + COOP/COEP option). Test in a
  real mobile browser, not just the editor.
- Android: outputs `builds/android/gods.apk` for direct sideload.

## Project layout

See `CLAUDE.md` §4. In short: `core/` (engine services), `components/`
(reusable entity parts), `systems/` (roguelike systems), `entities/`,
`scenes/`, `ui/`, `content/` (data-driven JSON per pantheon), `tests/`.

## Adding content

No engine code needed. Add a JSON file under `content/<pantheon>/`, list it in
`content/manifest.json`, and add any display strings to `localization/en.json`.
Schemas live in `core/data/*_data.gd`.
