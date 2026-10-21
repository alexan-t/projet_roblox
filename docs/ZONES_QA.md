# Zones 2 à 6 — contrôle du 19 octobre 2026

**Verdict global : FIX.** Les cinq zones fonctionnent en test solo, mais des images de
l'interface restent absentes dans le sandbox connecté. Aucun PASS global n'est revendiqué.
La mission reste à finaliser après correction des accès aux assets et contrôle multijoueur.

## Environnement et portée

- Place Studio connectée : **test 3**, placeId `120616399792561` ; aucune publication.
- Code synchronisé avec le plugin **Rojo 7.7.0**, depuis ce worktree, avant les tests.
- Les cinq décors et huit nouveaux modèles de combat sont dans Studio, les pancartes dans
  les huit arènes ; trois modèles de base absents ont été copiés des références validées.
- ProfileStore a signalé **API services unavailable — data will not be saved** : les profils
  de test étaient en mémoire. Les clears simulés et héros de test disparaissent à Stop.
- Les contrôles de combat ont utilisé Chevalier du Lierre, Brise-Pierre, Apprenti Pyromancien
  et Guetteuse des Pins, niveau 20, posés sur les cases 1 à 4, vitesse x2.
- Les victoires de combat sont distinctes des clears préparatoires simulés via DebugData.
  Aucun nouvel ennemi ni nouvelle rareté de monstre n'a été créé.

## Contrôles fonctionnels

| Contrôle | Résultat | Preuve / portée |
| --- | --- | --- |
| Six zones, trente stages exposés par le serveur | PASS | GetArenaState en Client : 30 entrées, compositions, XP et récompenses |
| Accès initial aux boss refusé, déblocage successif | PASS | DebugData StartStage/CompleteStage, 1-1 à 6-5 ; fins simulées, pas des combats |
| Choix des zones 2 à 6 | PASS | ArenaAction SelectStage ; exactement un décor actif avec le bon ZoneId |
| Boss 2-5, 3-5, 4-5, 5-5, 6-5 | PASS | Combats réels de CombatService, fin Victory ; retours en Placement |
| Boss de zone et héros visibles | PASS | Captures de Slime King et King Tréant en combat ; modèles texturés existants |
| Relance pendant l'outro | PASS | Après Victory de 3-5, SelectStage 5-5 puis Ready en moins d'une seconde : décor Zone 5 confirmé |
| Pancarte : E ouvre Expédition | PASS | Nouveau Play après correction ; ScreenGui Expedition présent |
| Flèches du menu jusqu'à la Zone 6 verrouillée | PASS | Cinq clics réels, cinq cartes 6-1..6-5, pas d'onglet Élite en Zone 6 |
| Indication de déblocage d'une première étape | PASS | « Termine la zone 5 » vérifié dans le GUI ; test pur pour les zones 2 à 6 |
| Deux décors sur deux plots tournés différents | PASS | ZoneDecor appliqué sur Plot_2 et Plot_3, Zone 1 inchangée sur Plot_1, pivots relatifs vérifiés puis restaurés |
| Deux joueurs et deux combats simultanés | FIX | Non exécuté dans cette session mono-client ; les tests purs d'isolation ne le remplacent pas |

Le test au niveau 20 vérifie le fonctionnement. L'équilibrage aux niveaux cibles 4/8/12/16/20
est couvert séparément par les simulations CombatEngine (trois équipes, cinq graines).

## Captures réelles et grille visuelle

Les originaux sont dans `automation/screenshots/zones/` :

| Capture | Contenu |
| --- | --- |
| [zone2-combat.jpg](../automation/screenshots/zones/zone2-combat.jpg) | Slime King contre l'équipe dans la Mare aux Slimes |
| [zone2-overview.jpg](../automation/screenshots/zones/zone2-overview.jpg) | Première vue isolée du gabarit, sans sol du plot ; contrôle de construction seulement |
| [zone3-final.jpg](../automation/screenshots/zones/zone3-final.jpg) | Décor de la Forêt des Tréants posé sur Plot_1, Edit |
| [zone4-final.jpg](../automation/screenshots/zones/zone4-final.jpg) | Décor du Camp de la Horde posé sur Plot_1, Edit |
| [zone5-before-fix.jpg](../automation/screenshots/zones/zone5-before-fix.jpg) | Lave trop lumineuse et anciennes pointes anguleuses, avant correction |
| [zone5-final.jpg](../automation/screenshots/zones/zone5-final.jpg) | Lave sans surexposition, stalagmites arrondies, après correction, Edit |
| [zone6-combat.jpg](../automation/screenshots/zones/zone6-combat.jpg) | King Tréant, équipe et grands arbres du Bois Ancien |
| [expedition-zone6-final.jpg](../automation/screenshots/zones/expedition-zone6-final.jpg) | Consultation réelle de la Zone 6 verrouillée depuis la pancarte ; images de récompenses absentes |

Application de VISUAL_QA aux **décors et à leur intégration**, avec les monstres validés
réutilisés sans remodelage. Ces captures ne constituent pas une nouvelle validation de
créature à six angles ; aucune nouvelle créature n'est livrée.

| Critère | Grille | Observation |
| --- | --- | --- |
| Brief / progression | OK | Cinq décors distincts, cinq stages chacun, boss sur X-5 |
| Zone / palette | OK | Mares vertes, forêt dense, camp ocre, roche/lave orange, vieux bois sombre/cyan |
| Lisibilité de l'arène | OK | Clairière, neuf cases et passage d'entrée dégagés dans les vues finales |
| Géométrie / clipping visible | OK | Réutilisation des repères de Zone 1 ; accessoires hors cases, stalagmites pleines après correction |
| Cohérence des monstres | OK | Copies des références validées ; Slime King et King Tréant restent dominants face aux héros |
| Couleurs / lumière du décor | OK | Lave corrigée, points lumineux limités ; formes arrondies remplaçant les blocs de basalte |
| Interface / matériaux des images | KO | Cases de menu et récompenses vides dans les captures Play, malgré les textes présents |

**Défaut bloquant réellement visible :** [Interface] les icônes du menu et des récompenses
ne se chargent pas (`zone2-combat`, `zone6-combat`, `expedition-zone6-final`). La console
signale notamment `User is not authorized to access Asset` pour des images existantes,
dont `74149875739571`, `99196320622532` et `136778535271316`. Le propriétaire doit rétablir
l'accès de cette expérience aux images concernées (ou effectuer la validation dans la place
DEV autorisée), puis recapturer. Aucun AssetId de remplacement n'a été inventé ou publié.

Les annonces « Rare ! » visibles dans certaines captures proviennent de l'aperçu d'invocation
du sandbox, pas d'une rareté attribuée aux monstres. La capture finale du menu est sans annonce.

## Corrections issues du test Studio

- `ProximityPrompt.Triggered` transmettait le Player au paramètre optionnel de numéro de zone :
  E affichait « Aucun stage disponible ». Le callback ignore maintenant cet argument.
- Un lancement avant la fin de l'outro pouvait garder le décor précédent. Le décor et le
  FrontEnnemi sont maintenant résolus avant la création du nouveau combat.
- L'aperçu UI utilisait encore `Waves = 1/2`, incompatible avec les vraies listes de vagues :
  son fixture utilise désormais le contrat courant et les statuts Unlocked/Locked.
- L'étape 6-1 verrouillée demandait « Termine 6-0 » ; elle demande désormais de finir la zone 5.
- La lave saturait l'image et les pointes étaient anguleuses : matière et géométrie corrigées,
  puis recapturées. Les images avant correction restent identifiées comme telles.

## Tests automatisés et état de sortie

Neuf lanceurs exécutés avec Luau CLI : `test-zones`, `test-combat`, `test-arena`,
`test-rewards`, `test-expedition`, `test-presentation`, `test-heroes`, `test-ui`, `test-security`.
Tous les cas signalés passent, aucun échec final. Le test Expédition a été rejoué après
l'ajout de la vérification du message inter-zone. `rojo build` et `git diff --check` passent.
Les neuf lanceurs ont été rejoués sans Studio lors de la tentative suivante : tous passent
(ZoneService 32, CombatService 45, RewardFlow 17, Expedition 15, Security 23, etc.).
Les deux points FIX ci-dessus demandent Studio et ne sont pas levés par ces tests.

Nouvelle vérification Studio (test 3, Edit) : `ContentProvider:PreloadAsync` renvoie toujours
`Failure` pour `74149875739571`, `99196320622532` et `136778535271316` ; l'accès n'est pas
rétabli, aucune capture refaite. Le Play lancé par MCP reste mono-client, même avec
`TestService.NumberOfPlayers = 2` (un seul joueur présent) ; la valeur 0 a été restaurée.
Le test à deux joueurs doit être lancé à la main (Test > Clients 2) ou dans la place DEV.

Vérification du 19/10 : les trois images renvoient encore `Failure` dans test 3. Six
lanceurs rejoués (zones 32, combat 45, arena 14, rewards 17, expedition 15,
presentation 19) : tous passent. Verdict inchangé : **FIX** tant que les images et le
test à deux joueurs ne sont pas validés en Studio.

Studio est revenu en Edit. Les huit plots ont retrouvé leur Zone 1, les objets d'aperçu
temporaires sont retirés, les caméras ont été recréées suivant MONSTER_PRODUCTION § Outils A.
L'attribut de démonstration initial `ApercuUI = Expedition` est restauré.
Les gabarits et les pancartes restent disponibles pour le prochain Play.
Branche `acc/mission-f9c766ee` conservée conformément à la consigne de mission, qui interdit
le changement de branche ; aucun push, aucune fusion, aucune publication.

## Étape 3 — tests, 19 octobre 2026

**Tests automatisés : PASS. Verdict global visuel : FIX, inchangé.**

Couverture complétée dans les specs existantes :

- ZoneService parcourt les trente stages : tous les statuts et indicateurs de First Clear
  sont vérifiés à chaque étape, ainsi que le lancement, la fin et la délégation des trente
  victoires aux récompenses. La progression d'un second joueur reste indépendante.
  Le double de RewardService ne sauvegarde pas : le test applique explicitement les clears.
  Ce contrôle ne remplace pas deux clients réels dans Studio.
- RewardFlow valide désormais une entrée de récompenses pour chacun des trente stages des
  six zones, au lieu des cinq stages de Zone 1 seulement.

Luau CLI officiel téléchargé depuis la dernière release de `luau-lang/luau` dans
`build/luau-cli` (dossier ignoré), sans installation globale. Les vingt lanceurs
`tools/test-*.ps1` ont été exécutés avec `-LuauPath build/luau-cli/luau.exe` :

| Lanceurs | Résultat |
| --- | --- |
| arena, combat, expedition, heroes, items | PASS |
| kingdom, migrations, playerstate, plots, presentation | PASS |
| quests, resources, rewards, sacoche, security | PASS |
| skeleton, summon, tutorial, ui, zones | PASS |

Résultats ciblés : ZoneService **33/33**, CombatEngine **36/36**, CombatService **45/45**,
ArenaRules **14/14**, ArenaPrep **25/25**, Expedition **15/15**, RewardService **16/16**,
RewardFlow **17/17**, CombatPresentation **19/19**, HeroProgression **13/13**.
Aucun échec. Les lanceurs migrations et summon rejouent des suites de heroes ; leurs
résultats ne doivent pas être comptés comme des cas indépendants supplémentaires.

`node --test tests/*.test.mjs` : **14/14** contrôles du runner Node passent. Les contrôles
internes supplémentaires des catalogues signalent aussi Items **19/19**, Resources **13/13**.
`rojo build -o build/zones-validation.rbxlx` : PASS. `git diff --check` : PASS.
La sortie détaillée des lanceurs est conservée localement dans
`build/zone-test-results.json` (non versionnée).

Contrôle MCP en Edit dans **test 3** : les cinq gabarits de zones 2 à 6 existent dans
`ServerStorage.Assets.ZonesArene`, chacun avec son ZoneId et son FrontEnnemi.
`ContentProvider:PreloadAsync` retourne toujours **Failure** pour les trois images
`74149875739571`, `99196320622532`, `136778535271316`.
Aucune modification Studio, nouvelle capture ou nouvelle validation visuelle dans cette
étape de tests ; les captures et défauts documentés plus haut restent la preuve visuelle.
Le test Studio à deux clients reste non exécuté. Aucun accès aux images n'a été modifié.

### Tests rejoués au 19/10, après l'ajout des contrôles de reprise

**Tests automatisés : PASS. Verdict global visuel : FIX, inchangé.**

Nouveau test Node `tests/zones-studio-checks.test.mjs` (**6/6**) : il garde
`tools/studio-check-menu-icons.luau` et `tools/studio-check-two-players.luau` alignés sur
le code. Il vérifie que les deux scripts restent en lecture seule, que le contrôle des
images lit bien les 13 AssetIds de `MenuIconConfig`, que les trois images bloquées sont
toujours celles citées ici, et que le contrôle à deux joueurs lit les mêmes noms et
attributs que le serveur (`Lobby.Plots`, `OwnerUserId`, `Arene.Zones`, `ZoneId`,
`DataLoaded`, `CombatId`, `Alive`). Si le code change, ce test casse avant le test manuel.

`node --test --test-isolation=none tests/*.test.mjs` : **20/20**. Les vingt lanceurs
`tools/test-*.ps1` passent, sans aucun échec : ZoneService **33/33**, CombatEngine
**36/36**, CombatService **45/45**, ArenaRules **14/14**, ArenaPrep **25/25**,
PlacementState **14/14**, Expedition **15/15**, RewardService **16/16**, RewardFlow
**17/17**, CombatPresentation **19/19**, HeroService **47/47**, HeroProgression **13/13**,
HeroRules **10/10**, Migrations **21/21**, PlotService **37/37**, QuestService **43/43**,
KingdomService **19/19**, Security **23/23**, Skeleton **13/13**, AnimationSets **14/14**,
Tutorial **13/13**, Sacoche **9/9**, PlayerStateService **7/7**, QuestLog **7/7**,
ItemConfig **5/5**, ResourceConfig **5/5**.
`rojo build` n'a pas été relancé dans cette étape (commande non autorisée dans
l'environnement de l'agent) ; le dernier build du 19/10 reste PASS et aucun fichier de
`src/` n'a changé depuis.

Studio n'était pas accessible dans cette étape : les deux scripts de contrôle n'ont pas
été exécutés. Les trois images restent bloquées et le test à deux clients reste à faire.

## Reprise — ce qui reste pour passer à PASS

Le code des zones est terminé ; les deux points FIX ne se règlent qu'en Studio et sur le
compte propriétaire. L'agent de cette étape n'avait ni accès aux réglages des assets, ni
Studio, ni deux clients. Ces étapes, dans l'ordre, permettent de lever le verdict.

### 1. Images du menu bloquées (propriétaire du jeu)

1. Sur le Creator Hub, ouvrir chacune des images `74149875739571` (quest.png),
   `99196320622532` (shop.png) et `136778535271316` (bag.png).
2. Leur donner l'accès à l'expérience **test 3** (placeId `120616399792561`), ou les
   republier depuis le compte/groupe qui possède l'expérience. Les PNG d'origine sont figés
   dans `docs/references/ui/invocation-v2/source-manifest.json` : rien à redessiner.
3. En cas de republication seulement : coller les nouveaux `rbxassetid://` dans
   `src/shared/Config/MenuIconConfig.lua` (seule source des AssetIds du menu).
4. Dans test 3, en Edit, exécuter `tools/studio-check-menu-icons.luau` dans la barre de
   commande : il doit afficher `13/13 lisibles` et renvoyer `0`.

### 2. Test à deux joueurs (manuel)

1. Rojo connecté depuis ce dépôt. Onglet **Test** → *Clients et serveurs* → **2 joueurs** →
   *Démarrer* : une fenêtre serveur et deux fenêtres clients s'ouvrent.
2. Dans chaque client, placer une équipe et choisir **une zone différente** (par exemple
   Zone 2 pour l'un, Zone 6 pour l'autre ; préparer la progression avec `DebugData` comme
   en solo). Lancer les deux combats à quelques secondes d'écart.
3. Pendant que les deux combats tournent, dans la fenêtre **serveur**, exécuter
   `tools/studio-check-two-players.luau` : il doit afficher `Deux joueurs : PASS`.
4. Vérifier à l'œil dans chaque client : son propre décor, ses héros, ses ennemis, une fin
   Victory ou Defeat qui ne touche que lui, puis le retour en Placement.
5. Capturer chaque client pendant le combat dans `automation/screenshots/zones/`
   (`two-players-client1.jpg`, `two-players-client2.jpg`).

### 3. Nouvelles captures et verdict

1. Refaire en Play les captures `zone2-combat`, `zone6-combat` et `expedition-zone6-final`,
   menu et récompenses visibles.
2. Appliquer `docs/VISUAL_QA.md` aux nouvelles captures, puis remplacer dans ce fichier la
   ligne « Deux joueurs et deux combats simultanés » et le critère « Interface / matériaux
   des images » par le résultat obtenu. Verdict global **PASS** seulement si les deux passent.
3. Réinitialiser la caméra de Studio (`docs/MONSTER_PRODUCTION.md` § Outils).

## Zone 2 — Royaume des Sables, 21 octobre 2026

Décor du Désert des Ruines complété d'après les recos de l'équipe et renommé **Le Royaume des Sables**
(`ArenaConfig.ZoneNames[2]`, outils, doc). Gabarit reconstruit dans « test 3 » par
`tools/studio-zones-assets.luau` (Zone 2 seule), une étape ChangeHistoryService par passe.

Ajouts par rapport à la Zone 1 : crêtes de grès le long du rempart (falaises vertes), bassin d'oasis
bordé de pierres sous la grande mare, palmiers, roseaux et canal ancien à demi ensablé (rivière),
avant-poste du désert avec palissades de bois sec, auvent déchiré, drapeaux et amphores (camp gobelin),
ossements, amphores et petits tas de sable dispersés. Signature : **tête de statue colossale** (22 studs,
némès rayé d'or) qui sort du sable côté est, tournée vers l'entrée. Repères `SourcesEnnemis`, portique
et cases des héros inchangés ; allée et cases dégagées.

Captures (Edit, gabarit posé dans l'arène de Plot_1 puis Zone 1 restaurée) :
[vue d'ensemble](../automation/screenshots/zones/zone2-sables-overview.jpg),
[tête](../automation/screenshots/zones/zone2-sables-tete.jpg),
[avant-poste](../automation/screenshots/zones/zone2-sables-avant-poste.jpg),
[fond](../automation/screenshots/zones/zone2-sables-fond.jpg),
[oasis](../automation/screenshots/zones/zone2-sables-oasis.jpg),
[vitrine `PlotsZones.Plot_Zone2`](../automation/screenshots/zones/zone2-sables-vitrine.jpg).

Le décor est posé à son emplacement prévu, la vitrine `Workspace.PlotsZones.Plot_Zone2` (panneau renommé),
et non dans les arènes du hub. L'outil d'assets supprimait la copie de la vitrine en reconstruisant une
zone : il l'y remplace désormais par le nouveau décor.

Correction du sol du fond : le cercle `SolZone` s'arrêtait vers z -54 alors que le rempart descend
jusqu'à z -74 ; l'herbe du plot (teintée olive par la vitrine) apparaissait derrière la pyramide.
Nappe de sable `SolZone.FondArriere` ajoutée ([capture](../automation/screenshots/zones/zone2-sables-fond-sol.jpg)).
Les zones 3 à 6 utilisent le même cercle et le même rempart : à vérifier.

| Critère | Grille | Observation |
| --- | --- | --- |
| Brief | OK | Tous les éléments des recos présents, signature lisible depuis l'entrée |
| Zone / palette | OK | Sable, grès ocre, accents or et toile rouge ; eau turquoise de l'oasis |
| Lisibilité de l'arène | OK | Cases, allée et front ennemi dégagés |
| Volumes | OK | Formes arrondies ; crêtes refaites trois fois (piles puis jarres refusées) |
| Géométrie / clipping visible | OK | Rien ne flotte, accessoires hors cases |
| Présence de la signature | OK | La tête domine le flanc est (rempart 9 à 15 studs) |
| Falaises | KO non bloquant | Crêtes rocheuses basses (9 à 15 studs), pas de vraies falaises hautes |

**Verdict : PASS** (1 KO non bloquant). Non testé : combat en Play dans ce décor (repères inchangés).
