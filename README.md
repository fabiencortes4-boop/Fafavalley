# Fafavalley

Jeu de ferme cosy en pixel art, pensé d'abord pour **mobile** (Android / iOS),
développé avec **Godot 4.3+** (GDScript, rendu *Compatibility* pour un maximum
d'appareils).

## Lancer le projet

1. Installer [Godot 4.3 ou plus récent](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot → *Importer* → choisir `project.godot`.
3. Appuyer sur **F5**.

Sur PC, la souris simule le tactile. Raccourcis clavier :

| Action | Touches |
|---|---|
| Se déplacer | ZQSD / WASD / flèches |
| Agir (outil, semer, récolter, interagir) | Espace ou E |
| Choisir un objet | 1 … 0, -, =, molette |
| Menu | Échap (bouton retour sur Android) |

## Ce que contient ce prototype

- Cycle jour/nuit (6h → 2h), 4 saisons de 28 jours, météo (la pluie arrose).
- Labourer (houe), arroser (arrosoir, à remplir à l'étang), semer, faire pousser, récolter.
- 6 cultures saisonnières (carotte, navet, chou, tomate et maïs qui repoussent, blé).
- Énergie, coffre d'expédition vendu la nuit.
- **Village de Valfleur** (par le chemin à l'est de la ferme) : épicerie de graines
  (9h-17h), place avec puits, mairie, tableau d'affichage.
- **5 habitants** avec emploi du temps (ils sortent, se promènent, rentrent le soir),
  dialogues selon l'amitié, la saison et la météo, **cœurs d'amitié** (10 max),
  **cadeaux** une fois par jour selon leurs goûts. Menu → Habitants pour suivre ses amitiés.
- **Pêche** : canne vendue à l'épicerie (250 or). Face à l'eau, lancer avec Action,
  attendre le « ! » (le téléphone vibre), ferrer, puis mini-jeu : appuyer pour pousser
  le filet à droite, relâcher pour le laisser revenir, garder le poisson dedans.
  8 espèces selon l'étang, la saison, l'heure et la météo ; tailles et records dans
  Menu → Carnet de pêche. Les poissons se vendent et s'offrent.
- **Mine** (entrée au nord-est du village) : au premier passage, le coffre de Firmin donne
  une pioche et une épée rouillée. Niveaux générés au hasard (30 au total) : rochers à
  casser (pierre, charbon, cuivre, fer, or, gemmes selon la profondeur), échelle cachée
  sous un rocher, lanterne et obscurité croissante, ascenseur tous les 5 niveaux, armes
  à trouver aux niveaux 10 et 20.
- **Combat** : coups d'épée devant soi, 7 monstres (gelée, chauve-souris, rats, araignée,
  crabe, fantôme) qui sautent, volent ou poursuivent, butins à vendre. Barre de vie ;
  à 0, on se réveille au village (soins payants). Légumes et poissons se mangent
  (Action avec l'aliment en main) pour regagner énergie et vie.
- **Fabrication** (Menu → Fabrication) : arroseurs à poser sur la ferme (arrosent 4 ou 8 cases
  chaque matin, se ramassent à la pioche), engrais (croissance plus rapide), 4 plats
  cuisinés qui soignent bien plus que les aliments crus.
- **Forge de Gaston** (enclume devant sa maison) : pioche renforcée (2x plus efficace),
  arrosoir en cuivre (60 doses, arrose 3 cases), épée en fer.
- Dormir dans la maison → bilan de journée + sauvegarde. Évanouissement à 2h.
- Sauvegarde automatique quand l'app passe en arrière-plan.
- Contrôles tactiles : joystick flottant, bouton Action, toucher une tuile voisine, barre rapide (multitouch).

## Architecture

```
project.godot
data/                 # contenu du jeu en JSON (objets, cultures, habitants, poissons, monstres, recettes)
scenes/main.tscn      # point d'entrée
scripts/
  autoload/           # singletons globaux
    event_bus.gd      #   signaux partagés (découplage des systèmes)
    time_manager.gd   #   heure, jour, saison, météo
    game_data.gd      #   chargement des JSON, icônes
    inventory.gd      #   barre rapide + or
    farm_state.gd     #   tuiles, cultures, expédition (logique pure)
    player_state.gd   #   énergie, eau, position
    relations.gd      #   amitié, discussions, cadeaux
    fish_log.gd       #   carnet de pêche
    crafting.gd       #   recettes, fabrication, améliorations
    save_manager.gd   #   sauvegarde JSON dans user://
    game_flow.gd      #   nouvelle partie, fin de journée
  world/world_map.gd  # base des cartes : ASCII -> TileMapLayer, bâtiments, passages
  world/farm.gd       # ferme : labour, cultures, expédition, sommeil
  world/village.gd    # village : bâtiments, habitants, itinéraires (AStarGrid2D)
  world/mine_level.gd # niveau de mine généré (automate cellulaire), rochers, échelle
  entities/monster.gd # monstres : sauter, voler, poursuivre
  entities/pickup.gd  # objets au sol attirés par le joueur
  entities/npc.gd     # habitant : emploi du temps, marche
  systems/fishing.gd  # lancer, touche, choix du poisson
  ui/fishing_minigame.gd
  entities/player.gd
  ui/                 # HUD, joystick, thème
tools/build_assets.py     # assemble les sprites à partir des packs Kenney
assets/kenney/            # packs Kenney originaux (CC0)
assets/sprites/           # planches utilisées par le jeu
tests/                    # tests automatiques (gameplay, joystick, capture d'écran)
```

Principes :
- **Données séparées du code** : ajouter une culture = une entrée dans `data/crops.json`
  (+ une ligne dans `crops.png`), un objet = une entrée dans `data/items.json`.
- **État séparé de l'affichage** : `FarmState` ne connaît pas la scène, `Farm` ne fait
  que refléter l'état → la sauvegarde et la simulation nocturne sont simples.
- **Carte en ASCII** dans `farm.gd` : facile à éditer avant de passer à l'éditeur de TileMap.
  Les bords des chemins, de l'étang et des rangées labourées se raccordent automatiquement.

## Tests

```
godot --headless res://tests/gameplay_test.tscn   # labour, semis, arrosage, nuit, récolte, vente, sauvegarde
godot --headless res://tests/village_test.tscn    # passage au village, habitants, amitié, épicerie
godot --headless res://tests/fishing_test.tscn    # canne, lancer, touche, mini-jeu, carnet
godot --headless res://tests/mine_test.tscn       # mine, rochers, échelle, combat, ascenseur
godot --headless res://tests/crafting_test.tscn   # arroseurs, engrais, cuisine, forge
godot --headless --fixed-fps 60 res://tests/combat_balance.tscn  # équilibrage du combat (simulation)
godot --headless -s res://tests/fishing_balance.gd # équilibrage du mini-jeu (simulation)
godot --headless res://tests/movement_test.tscn   # joystick tactile
xvfb-run godot --rendering-driver opengl3 res://tests/screenshot.tscn -- capture.png
```

## Exporter sur Android

1. Godot → *Éditeur → Gérer les modèles d'exportation* → télécharger.
2. Installer OpenJDK 17 et le SDK Android, puis les renseigner dans
   *Éditeur → Paramètres de l'éditeur → Export → Android*.
3. *Projet → Exporter…* : le préréglage **Android** est déjà fourni (`export_presets.cfg` :
   paquet `com.fafavalley.game`, plein écran, autorisation de vibrer pour la pêche).
4. Brancher le téléphone (débogage USB) et cliquer sur l'icône Android en haut à droite
   pour un déploiement en un clic.

iOS : même principe, mais il faut un Mac avec Xcode et un compte Apple Developer.

## Feuille de route

- [x] Prototype : ferme, outils, cultures, temps, vente, sauvegarde, contrôles tactiles
- [ ] Inventaire complet + coffres, qualité des récoltes
- [x] Village et habitants (emplois du temps, dialogues, cadeaux, amitié)
- [ ] Intérieurs des maisons, scènes de cœur, anniversaires
- [x] Fabrication, cuisine, améliorations d'outils
- [ ] Coffres, machines de transformation
- [x] Pêche (mini-jeu tactile, 8 espèces, carnet)
- [x] Mine et combat (30 niveaux, 7 monstres, minerais, armes)
- [ ] Animaux, bâtiments, compétences
- [ ] Fil rouge (collections à compléter), festivals
- [ ] Musique, sons, réglages, bêta Play Store

## Licence des assets

Graphismes et police : **Kenney** (www.kenney.nl), licence CC0. Détails dans
[`assets/LICENSE.md`](assets/LICENSE.md).
