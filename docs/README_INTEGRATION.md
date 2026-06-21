# Gods — intégration des assets PixelLab

Sprites pixel art (générés via PixelLab) renommés et restructurés pour **coller
exactement à la convention du dépôt** (voir `ASSETS.md` + `assets/sprites/*/README.md`).

Arborescence à fusionner dans le repo :

```
assets/sprites/
├── entities/   ← mobs, boss, minibos, classes joueur (statique + spritesheets)
├── portraits/  ← divinités (dialogue) + narrateur (Ferryman)
└── props/      ← décor grec (sans collision)
```

## Règles de nommage appliquées
- **Mob / boss** : `entities/<id>.png` (image statique = rotation sud).
- **Animations** : spritesheets horizontales `<id>_idle.png`, `<id>_walk.png`,
  `<id>_attack.png`, `<id>_death.png`. Nb d'images = largeur ÷ hauteur (auto-détecté).
  Assemblées depuis tes `animations/<action>/south/frame_000…`.
- **Attaques signature de boss** : `<id>_<anim>.png` où `<anim>` = champ `anim`
  des abilities dans `content/<pantheon>/enemies.json`
  (ex. `greece_cyclops_boulder_hurl.png`).
- **Divinités** : `portraits/<deity_id>.png` (ids de `content/<pantheon>/deities.json`).
- **Props** : `props/<pantheon>_<name>.png` (noms de `content/<pantheon>/biome.json`).
- Les 6 lots `Selected_characters*` qui se chevauchaient ont été **fusionnés par
  personnage** : un seul id, toutes les animations uniques combinées.

## Détail du mapping
Voir `name_mapping.csv` (dossier source → chemin repo → animations).

## À compléter plus tard (pas d'art source)
- Mobs aztèques : `aztec_obsidian`, `aztec_jaguar`, `aztec_tzitzimitl`,
  `aztec_cipactli` (boss), `aztec_jaguar_lord` (miniboss).
- Portraits grecs manquants : `greece_athena`, `greece_artemis`.
- Classe joueur `player_char_wanderer` + un `player.png` générique.
- Attaques de boss sans animation correspondante (le jeu retombe sur `attack`) :
  `greece_hydra_venom_spray`, `egypt_apophis_chaos_scarabs`,
  `japan_orochi_sake_flood`, `japan_orochi_kusanagi_cut`.
- Props : seul le panthéon grec est couvert (les 5 autres restent à faire).

## Source inutilisée (optionnelle)
`ghostly_grey_wraith_floating_above` et `hooded_wandering_soul_flowing_dark` :
candidats possibles pour un `entities/enemy.png` générique ou un sprite d'âme joueur.

## Mettre dans GitHub (dépôt VolaxxxX/Gods, branche claude/sleepy-cannon-vl3l7u)
Depuis un clone local du repo :
```bash
# copie le dossier assets/ par-dessus celui du repo (fusion, n'écrase que les sprites ajoutés)
cp -r assets/sprites/entities/*   <repo>/assets/sprites/entities/
cp -r assets/sprites/portraits/*  <repo>/assets/sprites/portraits/
cp -r assets/sprites/props/*      <repo>/assets/sprites/props/
cd <repo>
git checkout claude/sleepy-cannon-vl3l7u
git add assets/sprites
git commit -m "art: integrate PixelLab sprites (entities, animations, boss attacks, deity portraits, greek props)"
git push
```
Puis rouvre le projet dans Godot pour qu'il réimporte. Les sprites apparaissent
automatiquement (sinon greybox). Pour activer les nouveaux props grecs, ils sont
déjà listés dans `content/greece/biome.json` (sauf `greece_temple_prop_01..10`,
extras à ajouter si tu les veux).
