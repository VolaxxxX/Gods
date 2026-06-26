# PixelLab prompts — per-realm ENDING backdrops (optional)

The ending cinematic (`scenes/ending/ending.gd`) is **fully procedural** — a
realm-tinted gradient, a growing doorway of light, drifting motes and the soul
rising. It already looks intentional with **no art**.

If you want a bespoke painted backdrop per realm, drop a file at:

```
assets/sprites/endings/<realm>.png      # greece, bali, egypt, norse, japan, aztec
```

The engine picks it up automatically (else it falls back to the gradient). The
engine draws the soul, the growing light glow, the motes and the narration **on
top**, and dims→brightens the backdrop as the soul ascends — so design the image
as a *backdrop*, not a finished frame.

## Global specs
- **16:9, 1280×720** (or a clean multiple; it's stretched to fill).
- **Vertical composition**: darker underworld at the **bottom**, the realm's
  colour through the **middle**, opening to **bright light at the top-centre**
  (that's where the engine's glow + the rising soul go — keep the top-centre
  uncluttered and luminous).
- Painterly pixel-art, same restrained palette as the realm; **low detail in the
  centre** (the soul sits mid-frame), richer at the edges.
- No characters, no text. Atmospheric, reverent — this is the soul's release.
- The theme is **"the crossing that leads up, not down"**: a threshold between
  the underworld and dawn.

## Per-realm prompts

**Greece — Hades → dawn**
> pixel-art ending backdrop, 1280x720, the river Styx at the bottom in cold
> grey-blue marble, rising into pale gold dawn light at the top centre, distant
> Greek columns dissolving into mist, hallowed and quiet, low contrast centre

**Bali — niskala → light**
> pixel-art ending backdrop, 1280x720, dark volcanic temple steps and split candi
> bentar gate at the bottom, rising into warm emerald-and-gold dawn at the top
> centre, drifting incense haze, serene, ornate edges, calm luminous centre

**Egypt — the Duat → sunrise**
> pixel-art ending backdrop, 1280x720, dark sandstone hall with faint hieroglyphs
> at the bottom, opening to a brilliant turquoise-and-gold sunrise at the top
> centre, the sun-barque's light, dry and vast, uncluttered glowing centre

**Norse — Helheim → cold light**
> pixel-art ending backdrop, 1280x720, frost-rimed dark stone and mist at the
> bottom, rising into pale ice-blue dawn light at the top centre, faint snow,
> the Bifrost shimmer far off, stark and cold, luminous quiet centre

**Japan — Yomi → moon/sun**
> pixel-art ending backdrop, 1280x720, dark lacquer-and-crimson shrine grounds at
> the bottom, a red torii arch, rising into soft bone-white and warm dawn light at
> the top centre, blighted gloom lifting, still and reverent, glowing centre

**Aztec — Mictlan → dawn over the bone-road**
> pixel-art ending backdrop, 1280x720, dark jade-green basalt and skull motifs at
> the bottom, the nine-level bone-road, rising into warm gold-and-turquoise dawn
> at the top centre, serpent carvings at the edges, solemn, bright open centre

## Priority
Lowest — the procedural ending is already shipped and good. These only add
painterly flavour. Do Greece first to see the pipeline, then the rest.
