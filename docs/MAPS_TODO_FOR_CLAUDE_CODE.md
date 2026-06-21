# À FAIRE DANS GODOT — maps "belles" + flow (brief pour Claude Code)

Le joueur trouve les maps encore trop plates/petites et veut un rendu qui "donne
envie". J'ai poussé tout ce qui se fait **sans moteur** (assets + code drop-in,
validé au parseur gdtoolkit mais **jamais lancé dans Godot**). Ce qui reste exige
l'éditeur + des allers-retours visuels : c'est ton terrain.

## Déjà fait (à TESTER puis AJUSTER en jeu)
- Sprites agrandis : joueur `3.4×RADIUS`, ennemis `3.0×_radius` (pour voir le pixel art).
- Caméra `zoom = 1.6→1.7` (vue serrée, on ne voit pas toute la salle d'un coup).
- Murs épais 28px + sol/murs assombris + vignette + relief "front-face".
- Ombres de contact sous joueur/mobs/props.
- Grandes salles 19×13 / 21×13 + salles **non rectangulaires** (octagon/cross/hex/T,
  via murs `#` intérieurs désormais rendus+collisionnés).
- Déco **placée à la main** dans les templates (symbole `D`), plus d'aléatoire.
- FX de combat + FX signature par boss/miniboss (assets/sprites/fx).

➡️ **Régle ces valeurs au feeling sur un vrai téléphone** : `camera.zoom`
(`scenes/run/run_scene.gd`), les facteurs d'échelle (`player.gd`, `enemy.gd`),
`WALL_THICK` et la densité de déco (`scenes/room/room.gd`).

## 1. Vraie beauté des sols (LE gros morceau — impossible à faire à l'aveugle)
Le sol reste **une tuile 64px répétée à plat** → répétition visible + faible
contraste (ex. Grèce : mur clair ≈ sol clair, donc la forme octogonale ne se lit
presque pas). À faire en moteur :
- **TileMapLayer + TileSet avec terrains (autotiling)** : bords, coins int/ext,
  transitions automatiques au lieu d'un remplissage plat.
- **Variantes de sol** (3–4 par royaume, placées en random pondéré) pour casser la
  répétition. (Les `_alt` existent ; en générer d'autres au besoin.)
- **Murs avec profondeur** : face supérieure + face avant ("south") + coins, ombre
  portée — pas juste une bande.
- **Contraste par royaume** : assombrir/teinter les murs pour qu'ils tranchent sur
  le sol (sinon les salles non-rect ne se voient pas).
- **Lighting** (`CanvasModulate` + `PointLight2D` sur braseros/lave/runes),
  vignette écran, particules d'ambiance.
- Garder le fallback greybox si une tuile manque.

## 2. "Deux choix à la fin de chaque étage, sauf après le boss" (à préciser)
Le joueur veut un **embranchement à 2 choix** en fin d'étage (style Hades / Slay
the Spire), sauf après un boss. Aujourd'hui : l'étage est un **arbre de salles**
(plusieurs portes), le boss est le cul-de-sac le plus loin, et le choix de
**royaume** n'apparaît qu'après le boss final.
**Décision produit à confirmer avec le joueur** : veut-il
(a) qu'à chaque fin d'étage palier on **propose 2 portes/destinations** (avec aperçu
de la récompense derrière, à la Hades), le boss final gardant le choix de royaume ?
ou (b) autre chose ? Implémenter côté `run_scene` / `floor_generator` + une petite
UI de choix (réutiliser `RealmChoice`/`BlessingChoice`).

## 3. Vérifs
- Relancer `godot --headless --script res://tests/test_runner.gd` : j'ai ajouté de
  gros templates non-rect → vérifier `test_floor_generator` (reachability/quotas)
  passe encore.
- Réimporter les assets (sprites/fx/tiles) puis tester l'export Web sur mobile.
