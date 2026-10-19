# Contrat des plots — Alpha

`PlotService` (#3) attribue les emplacements préparés par le level design (#25).
Le service est chargé automatiquement par le bootstrap serveur. Aucun asset ni
script Studio n'est créé ou modifié dans ce lot.

## Préparation dans Studio

Le chemin du dossier et le nom du repère sont fixés dans `src/server/Config/PlotConfig.lua`,
alignés sur la map de la DEV. Une seule convention est acceptée :

```text
Workspace
  Lobby
    Plots (Folder)                    PlotConfig.PlotsFolder = { "Lobby", "Plots" }
      Plot_1 (Model, attribut numérique PlotId = 1)
        PointApparition (Part ancrée) PlotConfig.SpawnName = "PointApparition"
        Royaume
          EmplacementCentral          repère du royaume (docs/KINGDOM.md)
        ... décor permanent, arène, panneau
      Plot_2 (Model, PlotId = 2)
      ... jusqu'à 8 à 12 plots
```

Un dossier `Workspace.Plots` ou un repère nommé `Spawn` (ancienne convention) ne sont plus lus.

- Seuls les modèles enfants directs du dossier configuré sont enregistrés, au
  démarrage du serveur. Le nom du modèle est libre. `PlotId` doit être un entier
  positif, fini et unique. Tous les modèles partageant un ID sont ignorés.
- `PointApparition` est une `BasePart` ancrée, enfant direct du modèle, **pas une
  `SpawnLocation`**. Recommandation : une petite Part invisible, non collisionnable,
  horizontale, orientée dans le sens d'arrivée souhaité. Le pivot du personnage
  est placé quatre studs au-dessus de ce repère. Vérifier le dégagement avec l'avatar.
- Garder un spawn initial commun sûr pour l'attente du chargement des données.
  Les repères des plots ne doivent pas participer au choix aléatoire des spawns Roblox.
  Dans la DEV : `Lobby.Monde.SpawnLobby`, seul `SpawnLocation` actif (voir `docs/WORLD.md`).
- Ne pas créer de dossier `Runtime` dans les assets : ce nom est réservé au
  service. Un plot qui en possède déjà un au démarrage est ignoré, sans effacement.
- Régler la capacité du serveur au plus au nombre de plots valides (8 à 12 pour
  l'Alpha). Un nombre inférieur reste utilisable pour les tests avec un avertissement.
- Redémarrer le test après une modification des emplacements. L'ajout, le retrait
  ou le remplacement de plots pendant une partie n'est pas pris en charge.
  Par sécurité, avant chaque attribution ou utilisation, le service revérifie
  le chemin du dossier, le parentage du plot, son ID enregistré et le repère
  `PointApparition` (nom, parent, ancrage).
  Un plot devenu invalide n'est plus exposé par l'API et ne reçoit plus de
  téléportation ni de notification. Une attribution existante reste réservée
  jusqu'au leave ou à la perte de DataLoaded ; aucune réattribution automatique
  ni réparation de la map n'est tentée.

## Agrandissement pour les combats

Les dimensions d'un plot ne sont écrites nulle part dans `src/` : elles viennent des assets. La zone
de préparation, les positions des héros (dalles `CaseHeros`) et la grille ennemie (`FrontEnnemi`) sont
relues par `ArenaService` et les contrôleurs client, donc aucun code ne change avec la taille.

`tools/studio-agrandir-plots.luau` (Studio EDIT, barre de commande) agrandit `PlotTravail` et
`Lobby.Plots.Plot_*`, en une seule étape Ctrl+Z :

| Réglage | Valeur | Effet |
| --- | --- | --- |
| `LONGUEUR` | 20 studs | le côté ennemi (front, camp, rempart, bout du sol) recule : 20 studs de plus entre les héros et les ennemis |
| `ELARGISSEMENT` | 5 studs par côté | le bord s'écarte progressivement au-delà de 30 studs de l'axe ; dalles, porche, pancarte, royaume et portail restent en place |

Mesures de la sandbox v4 (repère de `FrontEnnemi`, identiques sur les 8 plots) :

| | Avant | Après |
| --- | --- | --- |
| Sol (`Sol.SoclePierre`) | 122 × 178 studs | 132 × 203 studs |
| Première rangée de dalles → front ennemi | 23 studs | 43 studs |
| Écart minimal entre sols voisins | 21,6 studs | 15,0 studs |
| Pointe extérieure (distance au centre de la place) | 328 studs | 353 studs |
| Mur invisible `LimiteMap` le plus proche de la pointe | ≈ 41 studs | ≈ 28 studs |

Fonctionnement : le sol en « stade » (`BoutArriere`, `Centre`, `BoutAvant` de chaque couche de `Sol`)
est redimensionné, la pointe côté royaume ne bouge pas. Tout ce qui est côté ennemis recule d'un bloc
(modèles entiers, jamais découpés). Les blocs simples qui traversent la coupe (eau de la rivière,
clairière) s'allongent. Les éléments du bord (rempart, bordure, arbres) des 20 studs droits suivant
la coupe sont recopiés dans la longueur ajoutée (attribut `CopieAgrandissement`). Les arbres de
`Lobby.Monde.ForetBordure` qui tomberaient dans la nouvelle emprise vont dans
`ServerStorage.Archive_Plots.ForetBordure_plots_agrandis`, et une copie de `PlotTravail` d'avant
est gardée dans `ServerStorage.Archive_Plots`. Rien n'est supprimé.

Procédure :

1. Captures **avant** (voir ci-dessous), puis lancer le script avec `APPLIQUER = false` : il affiche
   les mesures, l'écart entre voisins, les arbres et limites concernés, sans rien modifier. Il
   refuse d'agir si deux sols voisins passent à moins de 4 studs.
2. Relancer avec `APPLIQUER = true`. Le script est répétable : un plot qui porte déjà l'attribut
   `AgrandiCombat` est ignoré.
3. Test « Serveur et clients » à deux joueurs : placer 4 héros, lancer 1-1 et 1-5 (boss). Les ennemis
   sortent de leurs repères (`SourcesEnnemis`) et se forment au front reculé. Les héros avancent
   sans buter sur le décor. Deux combats simultanés restent chacun dans leur plot.
4. Captures **après** aux mêmes cadrages, puis contrôle PASS/FIX (ci-dessous).

Captures (avant et après, mêmes positions de caméra, relatives au `FrontEnnemi` du `Plot_1`) :

| # | Vue | But |
| --- | --- | --- |
| 1 | Plongée haute sur tout le plot | longueur et largeur du sol, bord continu |
| 2 | Plongée sur deux plots voisins | aucun chevauchement, forêt dégagée |
| 3 | Derrière les dalles, hauteur d'homme, vers les ennemis | profondeur du champ de bataille |
| 4 | Côté du rempart, à la jonction des copies | aucun trou, aucune pièce qui flotte |
| 5 | Pendant un combat 1-5 | héros et ennemis se déplacent sans être gênés |

Grille PASS/FIX (`docs/VISUAL_QA.md` § 3, appliquée au décor) : **Géométrie** (pas de trou dans le
sol, le rempart, la bordure ni la rivière), **Détails** (rien ne flotte ni ne s'enfonce),
**Matériaux** (copies identiques aux originaux), **Lisibilité** (le front ennemi se voit depuis les
dalles), **Chevauchement** (aucun sol, arbre ou mur entre deux plots), **Déplacement** (aucun héros
ni ennemi bloqué). Toutes ces lignes sont bloquantes. Réinitialiser la caméra après les captures
(`MONSTER_PRODUCTION.md` Outils § A).

## Attribution et nettoyage

Après `DataService:OnPlayerReady`, le premier plot libre par ordre de `PlotId`
est réservé sans attente. Le joueur reçoit l'attribut `PlotId`, et le modèle
reçoit `OwnerUserId`. Ces attributs répliqués servent à la présentation ; les
tables privées du service restent la source de vérité côté serveur.

Le personnage existant, puis chaque nouveau personnage après un respawn, est
positionné sur le repère. Le service attend le HumanoidRootPart et l'arrivée du
personnage dans Workspace avec un budget total de 10 secondes, puis laisse passer
une reprise du scheduler pour que le moteur termine son spawn initial. Une
attente du personnage expirée, un leave ou une
perte de session empêchent une téléportation tardive sur un plot réattribué.
Les téléportations, lectures d'attribution et notifications revérifient aussi
DataLoaded, la présence du profil et le dossier Runtime, sans attendre la
livraison des signaux différés de nettoyage. Les notifications identifient
l'attribution elle-même : un ancien replay ne peut pas annoncer sa remplaçante.
Sans emplacement libre, le joueur est déconnecté avec un message explicite lui
proposant une autre partie. Un dossier absent ou des plots invalides sont aussi
signalés dans les logs, sans bloquer les autres services.

Au départ ou à la perte de `DataLoaded`, le service déconnecte ses listeners,
détruit le dossier `Runtime` de cette attribution, retire les attributs de
propriété et libère l'emplacement. Le décor et les repères restent en place.
Les services gameplay doivent placer leurs clones sous ce dossier `Runtime`
et gérer leurs propres connexions/tâches. Aucun champ PlayerData, aucune
migration et aucun remote ne sont ajoutés. Le royaume persiste via DataService ;
l'emplacement physique peut changer à la prochaine connexion.

## API serveur

Appeler depuis `Start()` ou après celui-ci :

| Méthode | Résultat / usage |
| --- | --- |
| `GetPlot(player)` | Modèle attribué encore utilisable, ou `nil` |
| `GetOwner(plot)` | Joueur propriétaire d'une attribution encore utilisable, ou `nil` |
| `GetRuntime(player)` | Dossier destiné aux clones de royaume/héros de l'attribution encore utilisable, ou `nil` |
| `TeleportToPlot(player)` | Retour d'expédition ; `true` si déplacé, sinon `false`. Peut attendre le root et le parentage du personnage jusqu'à 10 secondes. |
| `OnPlotAssigned(callback)` | `callback(player, plot)` pour chaque attribution, y compris celles déjà faites ; retourne une connexion déconnectable |

`KingdomService` pourra écouter `OnPlotAssigned` puis lire `DataService:GetData`
et `GetRuntime`. Un callback qui attend doit revérifier ces références avant
d'ajouter des objets : le joueur peut être parti entre-temps. Les callbacks
n'ont aucune garantie d'ordre entre eux.

## Validation

Tests locaux du vrai module, avec doubles des API Roblox (Luau CLI officiel) :

```powershell
./tools/test-plots.ps1 -LuauPath <chemin-vers-luau.exe>
rojo build -o build/test.rbxl
```

Ces tests couvrent les règles d'attribution et les courses du cycle de vie,
y compris les joins groupés, les notifications avant livraison du nettoyage,
les changements de validité du plot et CharacterAdded avant le parentage.
Le scheduler simulé contrôle les attentes ; les vrais timings moteur et la
physique ne sont pas reproduits. La suite rapporte tous les échecs et retourne
un code non nul si au moins un test échoue.
Ils ne remplacent pas les tests moteur suivants dans Studio :

1. Préparer au moins deux plots conformes, connecter Rojo, lancer un test serveur
   avec deux clients : chacun reçoit un `PlotId` différent et arrive au bon repère.
2. Réinitialiser les personnages : chacun revient sur son propre plot.
3. Quitter un client : `OwnerUserId` et `Runtime` disparaissent ; le décor reste.
   Rejoindre : l'emplacement libéré peut être repris, sans contenu du précédent joueur.
4. Tester 8 puis 12 plots avec autant de clients : aucun doublon. Tester un client
   supplémentaire : message de serveur plein, sans déplacement des autres joueurs.
5. Retarder/faire échouer le chargement des données puis quitter : aucun plot réservé
   avant les données prêtes, aucune attribution pour un joueur parti.
6. Tester un ID en double, un PointApparition absent/non ancré, un Runtime préexistant et
   un dossier Lobby.Plots absent : logs explicites, assets inchangés, autres services actifs.
7. Quitter/rejoindre avec une progression existante : données inchangées, plot
   attribué à nouveau. Vérifier aussi le placement avec les avatars autorisés et StreamingEnabled.
8. Vérifier le spawn et les départs avec SignalBehavior Immediate et Deferred ;
   aucun callback exploitable ne doit annoncer un joueur déjà parti ou sans données.

Références moteur : [Player.CharacterAdded et ordre du spawn](https://create.roblox.com/docs/reference/engine/classes/Player),
[signaux différés et déconnexion](https://create.roblox.com/docs/scripting/events/deferred).
