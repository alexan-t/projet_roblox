# Contrat des plots — Alpha

`PlotService` (#3) attribue les emplacements préparés par le level design (#25).
Le service est chargé automatiquement par le bootstrap serveur. Aucun asset ni
script Studio n'est créé ou modifié dans ce lot.

## Préparation dans Studio

Préparer cette structure dans la DEV commune, via Studio / Team Create :

```text
Workspace
  Plots (Folder)
    Plot_01 (Model, attribut numérique PlotId = 1)
      Spawn (Part ancrée)
      ... décor permanent, repères du royaume et de l'expédition
    Plot_02 (Model, attribut numérique PlotId = 2)
      Spawn (Part ancrée)
    ... jusqu'à 8 à 12 plots
```

- Seuls les modèles enfants directs de `Workspace.Plots` sont enregistrés, au
  démarrage du serveur. Le nom du modèle est libre. `PlotId` doit être un entier
  positif, fini et unique. Tous les modèles partageant un ID sont ignorés.
- `Spawn` est une `BasePart` ancrée, enfant direct du modèle, **pas une
  `SpawnLocation`**. Recommandation : une petite Part invisible, non collisionnable,
  horizontale, orientée dans le sens d'arrivée souhaité. Le pivot du personnage
  est placé quatre studs au-dessus de ce repère. Vérifier le dégagement avec l'avatar.
- Garder un spawn initial commun sûr pour l'attente du chargement des données.
  Les repères des plots ne doivent pas participer au choix aléatoire des spawns Roblox.
- Ne pas créer de dossier `Runtime` dans les assets : ce nom est réservé au
  service. Un plot qui en possède déjà un au démarrage est ignoré, sans effacement.
- Régler la capacité du serveur au plus au nombre de plots valides (8 à 12 pour
  l'Alpha). Un nombre inférieur reste utilisable pour les tests avec un avertissement.
- Redémarrer le test après une modification des emplacements. L'ajout, le retrait
  ou le remplacement de plots pendant une partie n'est pas pris en charge.

## Attribution et nettoyage

Après `DataService:OnPlayerReady`, le premier plot libre par ordre de `PlotId`
est réservé sans attente. Le joueur reçoit l'attribut `PlotId`, et le modèle
reçoit `OwnerUserId`. Ces attributs répliqués servent à la présentation ; les
tables privées du service restent la source de vérité côté serveur.

Le personnage existant, puis chaque nouveau personnage après un respawn, est
positionné sur le repère. Une attente du personnage expirée, un leave ou une
perte de session empêchent une téléportation tardive sur un plot réattribué.
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
| `GetPlot(player)` | Modèle attribué, ou `nil` |
| `GetOwner(plot)` | Joueur propriétaire, ou `nil` |
| `GetRuntime(player)` | Dossier destiné aux clones de royaume/héros, ou `nil` |
| `TeleportToPlot(player)` | Retour d'expédition ; `true` si déplacé, sinon `false`. Peut attendre le `HumanoidRootPart` jusqu'à 10 secondes. |
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

Ces tests couvrent les règles d'attribution et les courses du cycle de vie.
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
6. Tester un ID en double, un Spawn absent/non ancré, un Runtime préexistant et
   un dossier Plots absent : logs explicites, assets inchangés, autres services actifs.
7. Quitter/rejoindre avec une progression existante : données inchangées, plot
   attribué à nouveau. Vérifier aussi le placement avec les avatars autorisés et StreamingEnabled.

Référence moteur : [Player.CharacterAdded et spawn manuel avec PivotTo](https://create.roblox.com/docs/reference/engine/classes/Player).
