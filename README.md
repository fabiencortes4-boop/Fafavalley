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
- **La nature reprend ses droits** : un sillon labouré laissé vide et sec 3 nuits se
  couvre de mauvaises herbes ; une culture oubliée 6 nuits sans eau fane, et les herbes
  prennent sa place 3 nuits plus tard (9 nuits en tout) ; les mauvaises herbes se propagent aux cases voisines, et branches
  et pierres réapparaissent dans les coins abandonnés. Dans la serre, la terre redevient
  simplement nue. Bilan au réveil.
- Eau texturée (vaguelettes, reflets), bateaux en planches avec voile ; minerais plus
  rares dans la mine ; personnage 10 % plus endurant (110 points d'énergie).
- **Port du Héron** (à l'est du village, par l'avenue) : 4 nouveaux villageois (Marius le
  tavernier, Nina la gardienne du phare, Basile le marchand, Céleste la musicienne), la
  **taverne** où les habitants se retrouvent chaque soir de 20h à 23h30 (musique,
  plats chez Marius), le comptoir de Basile (graines rares, minerais), pontons de pêche,
  bateaux, phare. **Chapitre « Le phare du Héron »** : aider Nina et Marius à rallumer le
  phare, éteint depuis le départ de Firmin (récompense, recette de la soupe du marin).
- **Animations de pêche et de combat en 3D** : canne, fil, bouchon lancé en arc, ronds
  dans l'eau, poisson qui jaillit ; arc du coup d'épée, chiffres de dégâts, monstres qui
  sursautent et disparaissent, joueur qui clignote quand il est touché.
- **Mine** : un escalier peut apparaître sous n'importe quel rocher cassé.
- **Maisons à l'échelle** du personnage (plain-pied) et plus soignées : soubassement en
  pierre, toit de tuiles avec faîtage et avant-toit, jardinières fleuries sous les
  fenêtres, marche, paillasson, lanterne. **Jardins des villageois** : massifs fleuris
  clôturés, potager d'Odette, chevalet de Lina, filets de Jules, foin du ranch, caisses
  de l'épicerie, mât de la mairie...
- **Optimisé pour téléphone** : décor 3D découpé en morceaux (seul ce que voit la caméra
  est dessiné : 13 fois moins de triangles au village), murs des maisons regroupés,
  30 images/s sur téléphone et 20 dans les menus (batterie), mini-carte et aides
  rafraîchies moins souvent. Réglage **Qualité** (économie, normale, élevée), choisi
  automatiquement selon l'appareil. Banc d'essai : `tools/benchmark.tscn`.
- **Rendu plus lisse** : textures filtrées, bords adoucis (anticrénelage), sol en dégradés.
- **Monde moins cubique** : le sol est un relief continu (hauteurs aux coins de chaque case) ;
  les berges des étangs et du lac descendent en pente douce vers l'eau, avec des contours
  arrondis et une teinte boue/sable humide ; légères collines en forêt et en bordure de
  carte ; touffes d'herbe, cailloux et fleurs le long des chemins, routes et clôtures pour
  casser les bords droits. Le décor suit le relief, et les lampadaires, pontons, bornes,
  bacs, bottes de foin, étals, machines et meubles sont faits de cylindres plutôt que de cubes.
- **Maisons adoucies** : toits galbés (pente raide au bord, arrondis au faîte) avec faîtage
  et rives en rondins, pignons courbes, poteaux d'angle ronds, soubassement aux angles
  arrondis, cheminée ronde en pierre, marche en demi-lune, auvent bombé, jardinières rondes.
- **Personnages « peluche »** : les pièces cubiques des modèles Blocky (tête, buste, bras,
  jambes) sont arrondies au chargement (`Models.rounded`) : faces subdivisées et projetées
  sur une boîte aux arêtes arrondies, UV conservés, donc tenues, éditeur de personnage et
  animations inchangés. Les portraits de dialogue sont rendus depuis ces mêmes modèles.
- **Rochers de la mine** modelés à la volée (`scripts/view3d/rock_mesh.gd`) : pierre à
  facettes teintée selon l'étage, filon coloré qui la traverse, pépites de cuivre, de fer,
  d'or ou de charbon, grappes de cristaux (gemmes, givre, opale de feu qui rougeoie).
  Planche de contrôle : `tools/render_rocks.tscn -- sortie.png`.
- **Pas d'objets qui se traversent** : le décor voisin d'une maison est écarté des murs et
  des avant-toits (jardins, tonneaux, haies, arbres réduits), les arbres s'écartent des bancs,
  lampadaires et étals, les rochers de la mine restent dans leur case. Les habitants ne
  traversent plus le joueur ni les autres habitants : ils s'arrêtent, contournent, et ne
  passent qu'en dernier recours. Contrôle automatique : `tools/clip_check.tscn -- village port farm`
  liste les objets qui rentrent dans une maison ou se chevauchent.
- **Arbres fruitiers** (chez Rosalie) : cerisier, pêcher, oranger, pommier. Adultes en
  10-12 jours, ils donnent un fruit par jour dans leur saison (3 au plus) : on les secoue.
- **Serre** (construite par Mathis : or, bois, pierre, quartz) : on y cultive tout, en
  toute saison, à l'abri de la pluie.
- **Mariage** : Rosalie, Lina, Mathis ou Margot. À 8 cœurs, une scène puis un bouquet
  (chez Rosalie) pour sortir ensemble ; à 10 cœurs, le pendentif de la source (forgé par
  Gaston) pour la demande. Mariage sur la place 3 jours plus tard ; ensuite, la personne
  vit à la ferme (à la maison le matin et le soir, dehors l'après-midi) et aide chaque
  matin : arrosage, foin, petit plat.
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
- **Clairière des bûcherons** (sud de la forêt, juste au-dessus de la ferme) : 21 arbres à
  bois, pins à l'est du chemin, platanes et chênes à l'ouest (`scripts/autoload/woods.gd`).
  On les abat à la hache (8 à 12 coups selon l'essence, moins avec une meilleure hache) :
  10 à 18 bûches, des graines, et du **bois dur** pour le chêne ; l'arbre bascule du côté
  opposé au joueur, puis la souche s'arrache pour encore un peu de bois. Les graines
  (pomme de pin, boule de platane, gland ; aussi chez Mathis) se replantent sur l'herbe
  libre de la forêt : pousse, jeune arbre, petit arbre, adulte en 6, 8 ou 10 jours. Une
  souche oubliée rejette au bout de 5 jours et la clairière se reboise doucement toute
  seule. Succès « Bûcheron » (25 arbres abattus).
- **Bois dur** (chênes) dans 5 recettes : **hache renforcée** chez Gaston (fer + bois dur,
  abat deux fois plus vite), **fût de chêne** (vieillit en 4 nuits au lieu de 7), et des
  **meubles en chêne** : fauteuil (on s'y assoit pour se reposer, à la maison), armoire,
  horloge comtoise.
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
- **Éditeur de personnage** (nouvelle partie, et Menu > Réglages > Apparence) : aperçu 3D
  qui tourne, sexe, 6 teintes de peau, 8 coupes (court, rasé, mèche, afro, carré, long,
  chignon, chauve), 8 couleurs de cheveux, pilosité (moustache, bouc, barbes, favoris),
  couleur des yeux, du haut et du bas, bouton « Au hasard ». La texture du personnage est
  peinte à la volée (`scripts/view3d/character_look.gd`). Prénom (utilisé dans les
  dialogues) et nom de la ferme. **3 emplacements** de sauvegarde, export et import de
  partie en texte (Réglages > Exporter, écran titre > Importer), retour à l'écran titre.
- **Accessibilité** : qualité marquée aussi par 1 à 3 points (pas seulement la couleur),
  vitesse du texte réglable (lent, normal, rapide, instantané).
- **Guide** (Menu > Guide) et **astuces** qui s'affichent une fois, au bon moment
  (qualité, machines, appâts, casiers, port, bancs, fêtes, tonneau).
- **Mine à thèmes** : terre, glace (10-19, gelées de givre, cristaux de givre), lave
  (20-29, gelées de magma, opales de feu), et au niveau 30 le **Gardien de la source**
  (barre de vie, 5000 or, Cœur de la montagne, succès).
- **Maison** : agrandissement chez Mathis (8000 or) et meubles à poser (tapis, lampe,
  plante, bibliothèque, tableau de Lina, table) ; la pioche les reprend.
- **Ferme** : chèvres (lait de chèvre) et moutons (laine) ; ruche (miel tous les 4 jours,
  sauf l'hiver) ; tonneau de vieillissement (+1 cran de qualité par semaine).
- **Famille** : quelques semaines après le mariage, un bébé arrive (scène), au berceau
  puis sur le tapis ; on joue avec lui chaque jour. Le conjoint vide aussi les machines.
- **Météo** : orages l'été (éclairs, tonnerre), brume du matin sur le port et au large.
- **Fêtes** : feu d'artifice de l'été, foire aux citrouilles (récoltes), pêche sur glace
  (poissons). Les habitants commentent tes exploits (confitures, légendes, Gardien...)
  et de nouvelles scènes de cœur au port.
- **Économie** : `python3 tools/economy_sim.py` (valeur ajoutée des machines, année type).
- **Transformation** (à fabriquer, à poser à la ferme) : bocal à conserves (confitures,
  conserves), pressoir (jus), fumoir (poisson fumé), presse à fromage (fromage, mayonnaise).
  Le produit garde la qualité et le nom de l'ingrédient (« Confiture de melon ★ or »),
  son prix dépend de l'ingrédient. Les plats cuisinés prennent la qualité des ingrédients.
- **Concours de la fête** : un jury note l'objet présenté (valeur et surtout qualité) face
  à trois habitants ; classement et prix selon le rang.
- **Pêche** : appâts (le poisson mord deux fois plus vite, prises plus belles), casiers
  posés dans l'eau (crabes, crevettes, moules, huîtres au port ; écrevisses aux étangs),
  sortie en mer avec la barque de Basile (« Au large » : thon, espadon), et 4 poissons
  légendaires (un seul exemplaire chacun, lettre de Jules pour les trouver).
- **Vie du monde** : les habitants s'assoient sur les bancs et aux tables de la taverne ;
  mouettes au port, canards sur les étangs, papillons au printemps et en été.
- **Qualité** des récoltes, fruits, fleurs, cueillettes, poissons et produits d'élevage :
  normale, ★ argent, ★ or, ★ cristal (étoile sur l'icône). Elle dépend de la compétence,
  de l'engrais, de l'âge de l'arbre, du bonheur de l'animal, de la taille du poisson et
  d'une prise parfaite. Vente x1,25 / x1,5 / x2, plats plus nourrissants, cadeaux plus
  appréciés. Les demandes du tableau peuvent exiger une qualité minimale (mieux payées).
- **Pontons et bateaux** : planches disjointes, pieux, cordes, échelles et bouées ;
  barque de pêche à voile, canot à rames et petit bateau à cabine qui tanguent.
- **Village et port aménagés** : routes pavées avec bordures de pierre, grande place de
  Valfleur dallée en rosace autour de la fontaine (bancs tournés vers elle, arbres en bac),
  lampadaires en fonte qui s'allument le soir, au port : quai avec bornes d'amarrage,
  étal du poissonnier, filets qui sèchent, vieille ancre, bancs face à la mer
  (textures : `tools/build_paving.py`).
- **S'asseoir** sur un banc (village, port) ou une chaise (taverne, maisons, chez soi) :
  Action pour s'asseoir, bouger ou Action pour se lever. Le repos rend un peu d'énergie
  (jusqu'à 80 % : ça ne remplace pas une nuit).
- **Boutique** : chaque graine indique son temps de pousse jusqu'à la récolte, sa repousse,
  ses saisons et le prix de vente ; boutons « Acheter x1 » et « x5 ».
- **Habitants cohérents** : chaque habitant porte une tenue liée à son métier (tablier de
  cuir du forgeron, ciré jaune du pêcheur, costume du maire, vareuse du tavernier...),
  générée par `tools/build_npc_textures.py`. Portraits des dialogues et petits sprites 2D
  sont rendus depuis ces mêmes modèles 3D (`tools/render_characters.tscn -- --portraits`).
- **Textes lisibles** : police arrondie Nunito (OFL) pour les textes, police pixel pour
  les titres. Le texte des dialogues défile avec une petite « voix » propre à chaque
  habitant (plus grave pour Gaston, plus aiguë pour Théo...).
- **Album de collections** (Menu → Album) : chaque objet obtenu pour la première fois
  s'inscrit dans 6 collections (récoltes, cueillette, poissons, élevage, cuisine, mine),
  silhouettes pour ce qui reste à trouver ; or en récompense à la moitié et à la totalité.
- **28 succès** (Menu → Succès) avec barre de progression et or en récompense : récoltes,
  fortune, pêche, profondeur de la mine, amitiés, mariage, histoire, album...
- **Game feel** : bannières animées avec étincelles et petite fanfare, compteur d'or qui
  défile (« +120 » qui s'envole), objets récoltés qui volent jusqu'à leur case, arrêt sur
  image et secousse de caméra 3D sur les coups, vibrations du téléphone (récolte, rochers,
  coups, prise ; réglables), jauge d'énergie qui clignote quand on est fatigué.
- **Équilibrage** : `python3 tools/balance_report.py` donne l'or par case et par jour de
  chaque culture ; les prix suivent une courbe cohérente (cultures rapides et sûres
  autour de 5, cultures longues ou à repousse jusqu'à 11-12).
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
  23 espèces : 13 d'eau douce (étangs, lac de la forêt) et 10 de mer (au port : sardine,
  bar, dorade, thon, calmar, espadon...), selon la saison, l'heure et la météo ; tailles
  et records dans Menu → Carnet de pêche (sections lac et mer). Les poissons se vendent et s'offrent.
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
    collections.gd    #   album de collections et paliers
    achievements.gd   #   succès (data/achievements.json)
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
godot --headless res://tests/nature_test.tscn     # terrain négligé : herbes, cultures fanées, propagation
godot --headless res://tests/port_test.tscn       # port, taverne du soir, chapitre du phare
godot --headless res://tests/family_test.tscn     # arbres fruitiers, serre, mariage
godot --headless res://tests/crops_test.tscn      # les 24 cultures : croissance, récolte, repousse, 3D
godot --headless res://tests/woods_test.tscn      # arbres à bois : abattage, souche, replantation, pousse
godot --headless res://tests/world_test.tscn      # demandes, scènes de cœur, anniversaires, zones débloquées
godot --headless res://tests/tutorial_test.tscn   # tutoriel, musique selon le lieu, taille du texte
godot --headless res://tests/events_test.tscn     # fêtes, marché, animations, intérieurs
godot --headless res://tests/life2_test.tscn     # mine à thèmes, Gardien, maison, enfant, fêtes, sauvegardes, accessibilité
godot --headless res://tests/crafts_test.tscn    # machines, plats de qualité, concours, appâts, casiers, mer, légendaires
godot --headless res://tests/quality_test.tscn   # qualité, demandes exigeantes, poissons de lac et de mer
godot --headless res://tests/decor_test.tscn     # place, bancs et chaises (repos), infos des graines
godot --headless res://tests/collections_test.tscn # album, paliers, succès, sauvegarde
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
Police des textes : **Nunito** (The Nunito Project Authors), SIL Open Font License 1.1,
voir [`assets/fonts/nunito_OFL.txt`](assets/fonts/nunito_OFL.txt).
