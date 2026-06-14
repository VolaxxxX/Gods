# Tiles (per realm)

Tileable PNGs drawn repeated across the room. Filename = `<pantheon>_<kind>`.
Kinds: `floor`, `wall`, `obstacle`. Missing files fall back to the biome's
palette colour.

Per pantheon: `greece`, `bali`, `egypt`, `norse`, `japan`, `aztec`. e.g.
- `greece_floor.png`, `greece_wall.png`, `greece_obstacle.png`
- `egypt_floor.png`, `egypt_wall.png`, …

## Sizes
- **32×32 px**, seamlessly tileable. The engine tiles them (cell size in-game is
  64px, so a 32px tile repeats 2× per cell — that's fine).
Keep the same style across realms; the palette per pantheon carries identity.
