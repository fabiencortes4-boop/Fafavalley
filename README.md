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
- Énergie, coffre d'expédition vendu la nuit, étal de graines.
- Dormir dans la maison → bilan de journée + sauvegarde. Évanouissement à 2h.
- Sauvegarde automatique quand l'app passe en arrière-plan.
- Contrôles tactiles : joystick flottant, bouton Action, toucher une tuile voisine, barre rapide (multitouch).

## Architecture

```
project.godot
data/                 # contenu du jeu en JSON (objets, cultures) : pas de code à toucher
scenes/main.tscn      # point d'entrée
scripts/
  autoload/           # singletons globaux
    event_bus.gd      #   signaux partagés (découplage des systèmes)
    time_manager.gd   #   heure, jour, saison, météo
    game_data.gd      #   chargement des JSON, icônes
    inventory.gd      #   barre rapide + or
    farm_state.gd     #   tuiles, cultures, expédition (logique pure)
    player_state.gd   #   énergie, eau, position
    save_manager.gd   #   sauvegarde JSON dans user://
    game_flow.gd      #   nouvelle partie, fin de journée
  world/farm.gd       # carte ASCII -> TileMapLayer, actions du joueur
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
godot --headless res://tests/movement_test.tscn   # joystick tactile
xvfb-run godot --rendering-driver opengl3 res://tests/screenshot.tscn -- capture.png
```

## Exporter sur Android

1. Godot → *Éditeur → Gérer les modèles d'exportation* → télécharger.
2. Installer OpenJDK 17 et le SDK Android, puis les renseigner dans
   *Éditeur → Paramètres de l'éditeur → Export → Android*.
3. *Projet → Exporter… → Ajouter… → Android*, nom de paquet `com.fafavalley.game`,
   orientation paysage (déjà réglée dans le projet).
4. Brancher le téléphone (débogage USB) et cliquer sur l'icône Android en haut à droite
   pour un déploiement en un clic.

iOS : même principe, mais il faut un Mac avec Xcode et un compte Apple Developer.

## Feuille de route

- [x] Prototype : ferme, outils, cultures, temps, vente, sauvegarde, contrôles tactiles
- [ ] Inventaire complet + coffres, qualité des récoltes
- [ ] Village et PNJ (emplois du temps, dialogues, cadeaux, amitié)
- [ ] Fabrication, cuisine, machines de transformation
- [ ] Pêche (mini-jeu tactile), mine et combat
- [ ] Animaux, bâtiments, compétences
- [ ] Fil rouge (collections à compléter), festivals
- [ ] Musique, sons, réglages, bêta Play Store

## Licence des assets

Graphismes et police : **Kenney** (www.kenney.nl), licence CC0. Détails dans
[`assets/LICENSE.md`](assets/LICENSE.md).
