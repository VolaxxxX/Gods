# Tiles (per realm)

Tileable PNGs drawn repeated across the room. Filename = `<pantheon>_<kind>`.
Kinds: `floor`, `wall`, `obstacle`. Missing files fall back to the biome's
palette colour.

Per pantheon: `greece`, `bali`, `egypt`, `norse`, `japan`, `aztec`. e.g.
- `greece_floor.png`, `greece_wall.png`, `greece_obstacle.png`
- `egypt_floor.png`, `egypt_wall.png`, …

## Two ways to use this
1. **One generic set, tinted per realm (least work):** drop `floor.png`,
   `wall.png`, `obstacle.png` (no pantheon prefix). They're auto-tinted by each
   biome's palette, so a single neutral/light tileset gives all six realms their
   own colour. Use light, low-contrast tiles so the tint reads.
2. **Bespoke per realm:** drop `<pantheon>_floor.png` etc. — used as-is, no tint.
Per-realm files take priority over the generic ones.

## Sizes
- **32×32 px**, seamlessly tileable. The engine tiles them (cell size in-game is
  64px, so a 32px tile repeats 2× per cell — that's fine).
