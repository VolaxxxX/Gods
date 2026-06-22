# À FAIRE DANS GODOT — maps "belles" + flow (brief pour Claude Code)

Le joueur veut des maps qui "donnent envie". J'ai poussé ce qui se fait **sans
moteur** (assets + contenu, validé au parseur gdtoolkit mais **jamais lancé dans
Godot**). Le reste exige l'éditeur + des allers-retours visuels : ton terrain.

> ## ✅ FAIT (Claude Code, 2e passe — lancé dans Godot 4.3 + rendu xvfb)
> - **Placement pertinent + au sol** (`scenes/room/room.gd`) : props placés
>   UNIQUEMENT s'ils sont clairs de porte / spawn / obstacle / autre prop
>   (`_prop_ok`) → le long des murs et coins, jamais devant une porte ni sur un
>   spawn ; ancrage par le bas de la boîte opaque (déjà le cas props ET entités) +
>   ombre de contact. Un obstacle `O` qui tomberait dans une bouche de porte est
>   retiré auto (`_is_solid_cell` → anti-soft-lock). Spawns aléatoires évitent les
>   solides/portes. Vérifié au rendu (courtyard + octagon).
> - **Beauté des sols (en moteur, sans atlas)** : **joints (grout)** sur la grille
>   de tuiles → vrai sol carrelé ; **relief des murs** (lèvre éclairée tout autour +
>   blocs de coin) ; **obstacles en relief** (dessus éclairé, base sombre, ombre
>   portée). S'ajoute à variation/vignette/lighting/particules déjà en place.
> - **Export Web RÉPARÉ** : la compression VRAM ETC2/ASTC bloquait l'export (erreur
>   de config muette en headless). Désactivée pour le preset Web (inutile en
>   renderer GL Compatibility) → `--export-release "Web"` produit wasm+pck+PWA.
>   **39/39 tests** passent.
> - RESTE bloqué sur de l'art : un **vrai TileMapLayer autotile** (atlas bords/coins)
>   et des portes-sprites par royaume. Le code-drawn atteint déjà le look des refs.

## 0. DÉCISIONS / RETOURS DU JOUEUR (à respecter)
- **Branchement : 2 PORTES façon Hades** (déjà commencé : `ui/door_choice.gd`). À
  la fin de chaque étage palier, 2 portes au choix avec **aperçu** (icône+nom+desc)
  de la salle/récompense derrière. Le boss FINAL garde le **choix de royaume**.
- Maps **plus grandes**, **zoomées**, **non rectangulaires**, mobs **gros**.

## 1. ⚠️ PLACEMENT DES OBJETS & OBSTACLES (retour direct du joueur)
> "les objets et obstacles ne sont pas toujours bien placés : ils doivent être
> PERTINENTS et AU SOL."

Images de référence committées dans **`docs/maps_reference/`** (montrent la cible
ET les défauts) :
- `ref_crafted_rooms.png` — salles soignées par royaume (cible).
- `ref_furnished_per_realm.png` — déco par royaume.
- `ref_octagon_room.png` — salle non-rect.

À garantir EN JEU :
- **Au sol (pas de flottement)** : ancrer chaque prop ET chaque entité par le BAS
  de sa boîte opaque (`used_rect`), pas par la hauteur du PNG. (`_place_prop`
  utilise déjà `Sprites.content_bottom` ✔ — **vérifier que c'est aussi le cas pour
  les ENTITÉS** joueur/mobs, et que l'ombre de contact tombe pile sous les pieds.)
- **Pertinents** :
  - Props **contre les murs / dans les coins**, jamais au milieu du passage,
    espacés régulièrement, **jamais devant une porte**, et cohérents avec le lieu.
  - Obstacles = **vrai couvert** : symétriques/logiques, ne bloquent ni les portes
    ni ne coincent le joueur, laissent des lignes de tir/d'esquive lisibles.
  - Éviter qu'un prop/obstacle chevauche un spawn d'ennemi ou la zone de départ.
- **Lisibilité** : ombre portée douce sous props/obstacles ; contraste mur/sol par
  royaume pour que la forme non-rect se lise.

## 2. Vraie beauté des sols (gros morceau)
- **TileMapLayer + TileSet terrains (autotiling)** : bords/coins/transitions.
- **Variantes de sol** (3–4 par royaume, random pondéré) anti-répétition.
- **Murs avec profondeur** (face haute + face avant + coins + ombre).
- **Lighting** (`CanvasModulate` + `PointLight2D`), vignette, particules.

## 3. Contenu déjà fourni (côté data, à TESTER puis ajuster)
- **18 salles "crafted" façon Hades** (3/royaume) dans `content/<realm>/rooms.json`
  (colonnade, courtyard, pit, alcoves, gauntlet, cross, diamond) — formes
  non-rect via murs `#` intérieurs, obstacles `O`, déco `D` hand-placed.
- Grandes salles communes + non-rect dans `rooms_common.json`.
- Sprites agrandis (joueur 3.4×, mobs 3.0×), zoom 1.7, FX combat + signatures
  boss/miniboss, **audio** (SFX + musiques par royaume), **icônes** boons + portes.

## 4. Vérifs
- `godot --headless --script res://tests/test_runner.gd` (j'ai ajouté beaucoup de
  templates → vérifier `test_floor_generator` reachability/quotas).
- Réimporter sprites/fx/tiles/audio ; tester l'export Web sur mobile.
