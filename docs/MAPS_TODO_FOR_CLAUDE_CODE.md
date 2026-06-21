# À FAIRE DANS GODOT — maps "belles" + flow (brief pour Claude Code)

> ## ✅ FAIT (session Claude Code, Godot 4.3 téléchargé + lancé en headless/xvfb)
> - **Le jeu se lançait PAS** : 3 erreurs de parse Godot 4.3 (`var path := …` non
>   typé dans `sprites.gd` / `fx.gd` / `audio.gd`). Corrigé → import propre.
> - **Tests** : le harnais `--script` ne compilait pas `floor_generator` (autoloads
>   pas encore enregistrés). Ajout de `tests/test_main.tscn` (run en SCÈNE). Les
>   **39 checks passent**.
> - **"Tout flotte"** : ancrage par le **bas de la boîte opaque** (`Sprites.content_bottom`
>   / `anim_content_bottom`) pour joueur, mobs et props. **Ombre de contact** sous
>   chaque mob.
> - **Murs lisibles** : murs assombris (×0.55) + biseau clair + face avant + ombre
>   portée sur le sol ; **variation de sol** par cellule (anti-répétition) ; vignette
>   renforcée ; **portes en arche** (herse rouge si verrouillée).
> - **2 PORTES façon Hades** : `ui/door_choice.gd` (Trésor / Faveur / Vigueur, aperçu
>   récompense) branché à la fin de chaque étage palier ; le boss FINAL garde
>   `RealmChoice`.
> - Vérifié au rendu réel (xvfb + llvmpipe) : screenshots salle de départ + salle de
>   combat Grèce → mobs/props posés au sol, murs et obstacles avec relief.
>
> ## ⏳ RESTE (le gros morceau visuel, bloqué sur de l'art d'atlas)
> Le **TileMapLayer + autotiling** (§2) demande des **atlas** (bords/coins/faces),
> pas les tuiles 64px uniques actuelles (cf. `MAPS_OVERHAUL_BRIEF.md` §4). En
> attendant ces atlas, le rendu code-drawn a été nettement amélioré (ci-dessus).
> Lighting `PointLight2D`, particules d'ambiance et vraies portes-sprites restent à
> faire en moteur.

---


Le joueur trouve les maps encore trop plates et "tout flotte". J'ai poussé ce qui
se fait **sans moteur** (assets + code drop-in, validé au parseur gdtoolkit mais
**jamais lancé dans Godot**). Le reste exige l'éditeur + des allers-retours
visuels sur un vrai téléphone : c'est ton terrain.

## 0. DÉCISIONS DU JOUEUR (à respecter)
- **Branchement : 2 portes façon Hades.** À la fin de chaque étage *palier*,
  proposer **2 portes au choix** avec un **aperçu** de ce qu'il y a derrière
  (type de salle / récompense). **Le boss FINAL** garde le **choix de royaume**
  (`RealmChoice`). Implémenter côté `run_scene` + `floor_generator` ; réutiliser
  une UI type `RealmChoice`/`BlessingChoice` pour le picker de portes.
- Maps **plus grandes**, **zoomées** (on ne voit pas tout sans bouger), **non
  rectangulaires**, déco **non aléatoire**, mobs **gros** (voir le pixel art).

## 1. "Tout flotte" + "pas de murs" (BLOQUANT visuel — à régler en jeu)
- **Sprites/props pas ancrés au sol** : les objets PixelLab ont du vide en bas de
  leur cadre, donc un ancrage par hauteur d'image laisse un trou → "ça vole".
  ➜ Ancrer par le **bas de la boîte englobante opaque** (used_rect), pas par la
  hauteur du PNG. Idem vérifier l'ancrage des entités (joueur/mobs) + position de
  l'ombre de contact pile sous les pieds.
- **Murs invisibles** : faible contraste mur/sol (ex. Grèce : mur clair ≈ sol
  clair) → la forme non-rect ne se lit pas. ➜ **Assombrir/teinter les murs par
  royaume** pour qu'ils tranchent, + le relief (voir §2).

## 2. Vraie beauté des sols (LE gros morceau)
Le sol reste **une tuile 64px répétée à plat**. À faire en moteur :
- **TileMapLayer + TileSet avec terrains (autotiling)** : bords, coins, transitions.
- **Variantes de sol** (3–4 par royaume, random pondéré) pour casser la répétition.
- **Murs avec profondeur** : face haute + face avant + coins + ombre portée.
- **Lighting** (`CanvasModulate` + `PointLight2D`), vignette écran, particules.
- Garder le fallback greybox si une tuile manque.

## 3. Déjà fait (à TESTER puis AJUSTER au feeling)
- Sprites : joueur `3.4×RADIUS`, ennemis `3.0×_radius`. Caméra `zoom 1.7`.
- Grandes salles 19×13 / 21×13 + non-rect (octagon/cross/hex/T : murs `#`
  intérieurs rendus+collisionnés). Déco hand-placed (symbole `D`).
- Murs 28px + sol/murs assombris + vignette + relief + ombres de contact.
- FX de combat + signatures par boss/miniboss.
➜ Régler `camera.zoom` (`run_scene.gd`), les échelles (`player.gd`/`enemy.gd`),
`WALL_THICK` et la densité de déco (`room.gd`) en regardant l'écran.

## 4. Vérifs
- `godot --headless --script res://tests/test_runner.gd` (j'ai ajouté de gros
  templates non-rect → vérifier `test_floor_generator`).
- Réimporter sprites/fx/tiles, tester l'export Web sur mobile.
