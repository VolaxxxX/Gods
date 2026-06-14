# SFX

Drop sound files here named after the logical keys the game plays. The `Audio`
autoload auto-loads `<key>.ogg` / `.wav` / `.mp3` and stays silent if missing.

Expected keys (rename your files to these):

- `shoot`   — player fires (currently not hooked to avoid spam; reserved)
- `hit`     — an enemy is hit/dies
- `death`   — the player dies
- `hurt`    — the player takes damage
- `pickup`  — item picked up
- `coin`    — gold gained
- `blessing`— a boon chosen
- `boss`    — (reserved) boss appears
- `door`    — (reserved) room transition
- `ui`      — UI tick (also plays when dragging the SFX volume slider)

See `/ASSETS.md` for recommended CC0 packs.
