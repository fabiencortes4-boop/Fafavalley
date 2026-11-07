# Fafavalley

Jeu de ferme cosy en pixel art, pensé d'abord pour **mobile** (Android / iOS),
développé avec **Godot 4.3+** (GDScript, rendu *Compatibility* pour un maximum
d'appareils).

## Jouer dans le navigateur (iPhone, Android, PC)

**https://fabiencortes4-boop.github.io/Fafavalley/**

- iPhone / iPad (Safari) : bouton *Partager* puis **« Sur l'écran d'accueil »** : le jeu
  s'ouvre ensuite en plein écran, comme une application.
- Android (Chrome) : menu ⋮ puis **« Ajouter à l'écran d'accueil »** (ou « Installer »).
- Jouer en mode paysage (un message s'affiche en portrait).
- La partie est sauvegardée dans le navigateur (automatiquement toutes les 45 s, et
  quand on quitte l'application).

La version web est publiée automatiquement par GitHub Actions
(`.github/workflows/web.yml`) à chaque mise à jour de la branche. Prérequis, une seule
fois : *Settings → Pages → Source : GitHub Actions*.

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

- **Vue 3D** (par défaut) avec les modèles Kenney : sol et étangs, arbres selon la saison,
  maisons assemblées (murs, portes, fenêtres, toits), cultures en 3D à chaque stade,
  personnages animés (marche, gestes d'outils), monstres, objets, lumière du jour et de la
  nuit, pluie et neige. La logique du jeu reste sur sa grille : la vue 3D la met en scène.
  Menu → Vue : 3D / 2D pour revenir à la version pixel art.
- **Lieux à l'identité propre**, avec carte de titre et fondu à chaque passage :
  la maison (intérieur boisé, lit pour dormir, cuisinière, cheminée qui crépite), la ferme,
  Valfleur (lumière dorée, lanternes allumées le soir, fumée des cheminées) et la mine
  (froide et sombre, lanterne du mineur).
- **Village agrandi** (60x42) en 6 quartiers : place et fontaine, artisans, ranch de Léon,
  résidences, parc de l'étang, chemin de la mine ; étals du marché, animaux du village.
- **10 habitants** avec leur routine (heures de sortie, lieux visités, retour à la maison),
  petites phrases en passant, dialogues et cadeaux : Rosalie, Gaston, Odette, Lina,
  Bertrand, Mathis (charpentier), Margot (coopérative), Léon (ranch), Théo, Jules (pêcheur).
- **Mini-carte** (en haut à gauche) : joueur, habitants, animaux ; un toucher l'agrandit
  avec le nom des quartiers.
- **Élevage** : Mathis construit le poulailler et l'étable sur les terrains de la ferme
  (or + bois + pierre, 2 jours de chantier) ; Léon vend poules, lapins, vaches et cochons ;
  Margot vend foin, brosse, seau à lait. Mangeoire à remplir, caresses et brossage
  quotidiens, amitié (cœurs), œufs, gros œufs, lait, laine angora, truffes.
  Chaque boutique a ses horaires et ses jours de fermeture.
- **Optimisé pour téléphone** : décor 3D découpé en morceaux (seul ce que voit la caméra
  est dessiné : 13 fois moins de triangles au village), murs des maisons regroupés,
  30 images/s sur téléphone et 20 dans les menus (batterie), mini-carte et aides
  rafraîchies moins souvent. Réglage **Qualité** (économie, normale, élevée), choisi
  automatiquement selon l'appareil. Banc d'essai : `tools/benchmark.tscn`.
- **Rendu plus lisse** : textures filtrées, bords adoucis (anticrénelage), sol en dégradés.
- **24 cultures** réparties sur les 4 saisons (hiver compris) : carotte, navet, maïs, tomate,
  chou, blé, radis, pomme de terre, fraise, ail, chou-fleur, haricot vert, panais, oignon,
  melon, poivron, myrtille, tournesol, aubergine, citrouille, betterave, canneberge,
  raisin, chou kale. Certaines repoussent après récolte. Nouvelles recettes : soupe de
  citrouille, ratatouille, tarte aux myrtilles. L'épicerie présente les graines de saison
  en premier.
- **Scénario détaillé** : scène d'arrivée sur la place de Valfleur (Bertrand et Rosalie),
  puis des objectifs qui **débloquent de nouvelles zones** : la **Forêt de la source** au
  nord de la ferme (tronc dégagé au chapitre 1 : cueillette, lac, campement de Firmin),
  la **mine** (éboulement dégagé au chapitre 2), la **source** derrière les ronces
  (chapitre 4), qui jaillit de nouveau à la fin de l'histoire.
- **Tableau des demandes** (panneau de la place) : 3 demandes d'habitants par jour ; on
  en accepte jusqu'à 3, on livre en parlant à l'habitant, contre de l'or et de l'amitié.
  Elles comptent aussi pour l'histoire (chapitre 2).
- **Scènes de cœur** : 2 scènes par habitant (à 2 et 5 cœurs), avec un choix de réponse
  qui compte. **Anniversaires** : un cadeau ce jour-là vaut 5 fois plus (dates dans
  Menu → Habitants).
- **Mine** : une vraie entrée au village (colline rocheuse, galerie, charpente, rails,
  wagonnet, lanternes). On change d'étage en **marchant sur les escaliers** : ceux qui
  descendent s'enfoncent dans le sol (cachés sous un rocher), ceux qui montent sortent
  du sol. Un **ascenseur** est installé tous les 5 étages (il débloque l'arrêt), et un
  **coffre** tous les 15 étages donne une meilleure arme (lame d'acier, épée de Firmin).
- **Ergonomie** : le bouton Action annonce ce qu'il va faire (Labourer, Parler, Entrer,
  Récolter, Descendre...) ; chaque fenêtre a une croix et se ferme en touchant à côté ;
  menu pause simplifié avec un écran Réglages ; achat par 5 dans les boutiques.
- **Musique d'ambiance** originale (composée par `tools/build_music.py`) : ferme, village,
  mine, intérieurs, fêtes et nuit, avec fondu enchaîné (Menu → Musique pour couper).
- **Tutoriel guidé** pour les nouvelles parties : une consigne à la fois (marcher, courrier,
  labourer, semer, arroser, histoire, village, habitants, dormir), qui avance dès que
  l'action est faite. Bouton « Passer », relançable depuis le menu.
- **Texte plus grand** par défaut, réglable (Menu → Texte : normal, grand, très grand).
- **Intérieurs** pour chaque bâtiment du village : épicerie, mairie (registre et tableau
  du projet), forge de Gaston, menuiserie, coopérative, ranch, maisons d'Odette et Théo,
  de Lina et de Jules. Les commerçants tiennent leur comptoir aux heures d'ouverture,
  les habitants sont chez eux selon leur emploi du temps ; livres et albums racontent
  l'histoire de Valfleur.
- **Événements** : une grande fête par saison (Fête des semis et Fête des récoltes avec
  concours, Nuit des lanternes avec danse, Marché d'hiver), annoncée par lettre la veille ;
  tout le village se rassemble sur la place, décorée de fanions. Marché du colporteur
  chaque samedi matin, et une animation chaque jour (pétanque, peinture, pique-nique,
  concours de pêche, chorale, balade). Le tableau d'affichage donne le calendrier.
- **Village décoré** : jardinières fleuries, bancs, haies, puits, meules de foin,
  tonneaux, bacs à fleurs sur la place ; forêt et route qui continuent au-delà des bords.
- Le temps passe plus vite : une journée dure environ 9 minutes.
- **Histoire en 5 chapitres** (bouton *Histoire*) : la source de Valfleur s'est tarie,
  la Fête des fleurs a disparu, Firmin a quitté la ferme... À toi de faire refleurir la
  vallée. Chaque chapitre propose **3 voies au choix** (cultiver, défricher, vendre,
  se faire des amis, explorer la mine, combattre, pêcher, cuisiner, élever) et
  débloque de **nouvelles recettes** (engrais, confiture, arroseurs, outils de la forge,
  fromage...). Lettres des habitants, récompenses, et fête finale au village.
- Vue rapprochée (zoom x2 par défaut, environ 15 cases de large ; réglable dans Menu → Zoom).
- Gestes d'outils animés (houe levée puis abattue, arrosoir qui verse, hache, pioche, faux,
  canne à pêche) avec particules (terre, eau, copeaux, éclats, herbe), récoltes qui sautent
  vers le sac et petits tremblements d'écran sur les gros coups.
- Personnage vivant : ombre, démarche souple, respiration, poussière et bruits de pas.
- Bruitages pour chaque action, l'interface, la pêche, la mine et les monstres
  (Menu → Son pour couper).
- Horloge : jour de la semaine, date, saison, météo, heure, lieu ; bourse en dessous.
- Saisons visibles : herbe et arbres dorés en automne, neige en hiver ; pluie et neige qui tombent.
- Ferme à défricher : herbes folles (faux), branches et arbres morts (hache), pierres (pioche),
  qui donnent fibre, bois et pierre ; quelques herbes repoussent chaque nuit.
- Boîte aux lettres : lettres des habitants (bienvenue avec hache et faux, conseils de saison,
  cadeaux, récompenses).
- Cueillette : 8 plantes sauvages (2 par saison) à ramasser à la ferme et au village.
- Compétences (Menu → Compétences) : agriculture, minage, pêche, combat, cueillette ;
  10 niveaux chacune, avec un bonus (récolte double, minerai en plus, filet plus large,
  vie max, cueillette double).
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
- **Sac** (bouton « Sac ») : 12 places au départ (= barre rapide), 24 puis 36 avec le grand
  sac et le sac de voyageur (épicerie). Toucher un objet puis la case où le poser ;
  description et prix de vente affichés.
- **Coffres** (fabriqués ou achetés, posés à la ferme) : 36 places. Toucher un objet le fait
  passer du coffre au sac et inversement ; « Ranger les piles » complète les piles déjà
  présentes. Un coffre vide se ramasse à la pioche.
- Dormir dans la maison → bilan de journée + sauvegarde. Évanouissement à 2h.
- Sauvegarde automatique quand l'app passe en arrière-plan.
- Contrôles tactiles : joystick flottant, bouton Action, toucher une tuile voisine, barre rapide (multitouch).

## Architecture

```
project.godot
data/                 # contenu du jeu en JSON (objets, cultures, habitants, poissons, monstres, recettes, lettres)
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
  fx/fx.gd            # particules, poussière, objets qui sautent (2D ou 3D)
  view3d/view3d.gd    # vue 3D : décor, acteurs, caméra, lumière, météo, effets
  view3d/models.gd    # chargement et regroupement (MultiMesh) des modèles Kenney
tools/build_assets.py     # assemble les sprites à partir des packs Kenney
tools/build_sfx.py        # fabrique les bruitages (Kenney + sons synthétisés)
tools/build_music.py      # compose les musiques d'ambiance (synthèse originale)
assets/kenney/            # packs Kenney 2D et sons (CC0)
assets/kenney3d/          # sélection de modèles 3D Kenney (CC0)
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
godot --headless res://tests/crops_test.tscn      # les 24 cultures : croissance, récolte, repousse, 3D
godot --headless res://tests/world_test.tscn      # demandes, scènes de cœur, anniversaires, zones débloquées
godot --headless res://tests/tutorial_test.tscn   # tutoriel, musique selon le lieu, taille du texte
godot --headless res://tests/events_test.tscn     # fêtes, marché, animations, intérieurs
godot --headless res://tests/story_test.tscn      # histoire : chapitres, voies, déblocages, lettres
godot --headless res://tests/animals_test.tscn    # maison, construction, achat d'animaux, foin, œufs, traite, boutiques
godot --headless res://tests/crafting_test.tscn   # arroseurs, engrais, cuisine, forge
godot --headless res://tests/inventory_test.tscn  # sac, agrandissements, coffres
godot --headless res://tests/life_test.tscn       # zoom, débris, courrier, cueillette, compétences, saisons
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
- [x] Défrichage, courrier, cueillette, compétences, saisons visibles
- [ ] Qualité des récoltes
- [x] Village et habitants (emplois du temps, dialogues, cadeaux, amitié)
- [ ] Intérieurs des maisons, scènes de cœur, anniversaires
- [x] Fabrication, cuisine, améliorations d'outils
- [x] Coffres et sac agrandissable
- [ ] Machines de transformation
- [x] Pêche (mini-jeu tactile, 8 espèces, carnet)
- [x] Mine et combat (30 niveaux, 7 monstres, minerais, armes)
- [ ] Animaux, bâtiments, compétences
- [ ] Fil rouge (collections à compléter), festivals
- [ ] Musique, sons, réglages, bêta Play Store

## Licence des assets

Graphismes et police : **Kenney** (www.kenney.nl), licence CC0. Détails dans
[`assets/LICENSE.md`](assets/LICENSE.md).
