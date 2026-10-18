# Quêtes — QuestService

`QuestService` (#6) guide le joueur par une chaîne de quêtes, sans tutoriel lourd.
Le monde (chemin lumineux, cibles qui pulsent) montre quoi faire ; la quête dit pourquoi.

## Chaîne de la Zone 1

| Id | Titre | Objectif | Guidage | Réclamation | Récompense (Alpha, provisoire) |
| --- | --- | --- | --- | --- | --- |
| `SummonStarter` | Invoque ton premier héros | `StarterHeroSummoned` (invocation tutorielle) | portail | **automatique** | aucune : l'Écuyer et son reveal |
| `DefendDomain` | Gagne la défense 1-1 | `StageCompleted` 1-1 | pancarte + pose du héros | « Récupérer » | 50 Or |
| `DefendStage12` | Gagne la défense 1-2 | `StageCompleted` 1-2 | pancarte | « Récupérer » | 75 Or, 5 Gemmes |
| `DefendStage13` | Gagne la défense 1-3 | `StageCompleted` 1-3 | pancarte | « Récupérer » | 100 Or, 10 Gemmes |
| `DefendStage14` | Gagne la défense 1-4 | `StageCompleted` 1-4 | pancarte | « Récupérer » | 150 Or, 15 Gemmes |
| `DefeatRoiOrc` | Vaincre le Roi Orc | `StageCompleted` 1-5 (tout le stage, boss compris) | pancarte | « Récupérer » | 250 Or, 25 Gemmes, 1 Ticket |

Les récompenses de quête ne vivent que dans `QuestConfig.Rewards` : un bonus de progression unique,
en plus des récompenses de stage (`RewardConfig` : First Clear, replay). Une victoire peut donc donner
l'écran de fin du stage **puis** le reveal de la quête : c'est voulu. Le nom du boss dans le titre doit
rester celui de `ArenaConfig.EnemyNames.Boss` (vérifié par les tests).
La logique est serveur. Le client lit une vue en lecture seule et demande la réclamation par
remote (#11, voir § Remotes et HUD).

## QuestConfig

`src/server/Config/QuestConfig.lua` décrit toutes les quêtes. Le code ne connaît aucune
quête en particulier : ajouter une quête se fait uniquement dans la config.

```lua
FirstQuestId = "SummonStarter",
Quests = {
	DefendDomain = {
		Title = "Gagne la défense 1-1",
		Objective = {
			Event = "StageCompleted",        -- événement gameplay attendu
			Match = { Zone = 1, Stage = 1 }, -- champs que le payload doit avoir, à l'identique
			Target = 1,                      -- nombre d'événements correspondants
		},
		Guide = { Target = "StageSign", Placement = true }, -- optionnel : guidage (Placement : apprendre la pose)
		Rewards = { { Kind = "Gold", Amount = 50 } },       -- optionnel : donné une fois à la réclamation
		AutoClaim = nil,                     -- true : réclamée par le serveur dès qu'elle est terminée
		Onboarding = nil,                    -- true : quête d'accueil d'un nouveau profil
		NextQuestId = "DefendStage12",       -- quête suivante, nil = fin de la chaîne
	},
},
```

- La clé (`DefendDomain`) est l'identifiant technique stable, sauvegardé dans PlayerData.
  Ne jamais la renommer sans migration.
- `Match` est facultatif : sans lui, tout événement du bon nom compte. Les valeurs sont
  comparées strictement (`1` ≠ `"1"`) ; les champs du payload absents de `Match` sont ignorés.
- La config est vérifiée au démarrage : `Title`, `Objective.Event`, `Target` entier ≥ 1,
  `Match` table, `NextQuestId` existant, `FirstQuestId` existant, `Guide.Target` connu
  (`Shared.Quests.QuestGuide`), `Rewards` (Kind `Gold` / `Gems` / `SummonTicket`, Amount entier ≥ 1)
  et aucune boucle.
  En cas d'erreur, chaque problème est journalisé et les quêtes sont désactivées, sans crash.

## PlayerData

Le champ existant suffit (pas de nouvelle clé) :

```lua
Quests: { [QuestId]: { Progress: number, Claimed: boolean } }
```

La **quête active** n'est pas sauvegardée à part : c'est la première quête de la chaîne
`FirstQuestId → NextQuestId` qui n'est pas encore réclamée. Si elle n'a pas encore d'état,
elle est créée à `{ Progress = 0, Claimed = false }`. Cette activation a lieu à chaque
`DataService:OnPlayerReady` et à chaque appel de l'API. Elle est idempotente : un état
existant n'est jamais réinitialisé, ni au rejoin, ni lors d'une nouvelle activation.

**Stage déjà gagné.** Une quête `StageCompleted` (`Target = 1`, `Match.Zone` / `Match.Stage`) dont
le stage est déjà dans `Progression.FirstClears` quand elle devient active est aussitôt terminée
(`Progress = 1`, jamais réclamée à la place du joueur) : gagner 1-2 avant d'avoir récupéré 1-1 ne force
jamais à refaire 1-2, et les deux récompenses restent à récupérer.

**Migration (DataVersion 3).** Un profil d'avant cette chaîne a la quête de chaque stage déjà gagné
marquée terminée **et réclamée**, sans ses nouvelles récompenses (pas de pluie de monnaies rétroactive),
et `SummonStarter` réclamée s'il possède déjà un héros. Les stages gagnés ensuite rapportent normalement.

## Événements gameplay

```lua
QuestService:HandleGameplayEvent(player, "StageCompleted", { Zone = 1, Stage = 1 })
```

- Seule la quête active progresse, de +1 par événement correspondant, sans jamais dépasser
  `Target`. Un événement répété après complétion ne change rien.
- Un événement inconnu, une autre zone, un autre stage ou un payload absent ne changent rien.
- Renvoie `true` si une progression a été enregistrée.

**Format de `StageCompleted`** : `{ Zone: number, Stage: number }`. Le payload peut contenir
d'autres champs, ignorés par les quêtes.

## Réclamation

```lua
local ok, reason, rewards = QuestService:ClaimQuest(player, "DefendDomain")
```

- Acceptée une seule fois, sur la quête **active**, terminée (`Progress >= Target`) et pas encore
  réclamée. Section synchrone sans yield : `Claimed = true`, `QuestConfig.Rewards` ajoutées aux
  monnaies une seule fois, quête `NextQuestId` activée ; les récompenses sont renvoyées pour le reveal.
- Refusée sinon, avec la raison : `"données non chargées"`, `"quête inconnue"`,
  `"quête non commencée"`, `"déjà réclamée"`, `"quête non active"` ou `"quête non terminée"`.
- Le client n'envoie que le `QuestId` : aucun montant, aucune récompense ne vient de lui
  (voir [SECURITY.md](SECURITY.md)).
- `Claimed` est sauvegardé par DataService : une réclamation reste acquise après un rejoin ; une quête
  terminée mais pas réclamée reste à récupérer après un rejoin (pas de délai, pas de réclamation forcée).
- **AutoClaim** (`SummonStarter` seulement) : la quête est réclamée dans la même section que sa
  progression ; `QuestChanged` porte alors la quête terminée en second argument et le client annonce
  « Quête terminée ! » avant la suivante, sans bouton.

## API serveur

| Méthode | Résultat / usage |
| --- | --- |
| `GetActiveQuest(player)` | `{ Id, Title, Progress, Target, Completed, GuideTarget?, GuidePlacement, AutoClaim, Onboarding, Rewards }` (copie), ou `nil` : données pas prêtes, quêtes désactivées, ou chaîne entièrement réclamée |
| `GetQuestState(player, questId)` | `{ Progress, Claimed }` (copie), ou `nil` si la quête n'a jamais été commencée |
| `HandleGameplayEvent(player, eventName, payload)` | Voir « Événements gameplay » |
| `ClaimQuest(player, questId)` | `true, nil, récompenses`, ou `false` et la raison du refus |

## Contrats avec les issues suivantes

- **ZoneService (#7)** : quand un stage est réellement terminé côté serveur, il appelle
  `QuestService:HandleGameplayEvent(player, "StageCompleted", { Zone = zone, Stage = stage })`.
  QuestService ne dépend pas de ZoneService ni de CombatService (#8).
- **RewardService (#9, `docs/REWARDS.md`)** : ZoneService l'appelle juste après QuestService
  pour le même `StageCompleted`. Il reste seul responsable
  des récompenses de stage, du First Clear (`Progression.FirstClears`) et du ticket
  d'invocation du 1-1. Les récompenses de quête (`QuestConfig.Rewards`) sont un bonus distinct,
  attribué par QuestService à la réclamation.
- **HeroService** : l'invocation tutorielle signale `StarterHeroSummoned`.
- **Controllers / UI (#11)** : `QuestController` affiche la vue de `GetActiveQuest` et réclame
  par `Remotes.ClaimQuest` (voir § Remotes et HUD).

## Remotes et HUD (#11)

| Remote | Sens | Contenu |
| --- | --- | --- |
| `GetActiveQuest` (RemoteFunction) | client → serveur | vue `{ Id, Title, Progress, Target, Completed, GuideTarget? }` (copie) ou `nil` |
| `ClaimQuest` (RemoteFunction) | client → serveur | le client n'envoie que l'Id de quête (texte) ; réponse `(ok, raison?, récompenses?)`, tout est revérifié (`quête non terminée`, `déjà réclamée`, `quête inconnue`) ; les récompenses de la quête sont ajoutées une seule fois, sans yield |
| `QuestChanged` (RemoteEvent) | serveur → le seul joueur | `(vue ou nil, terminée?)` : même vue, ou `nil` quand la chaîne est terminée ; envoyée à l'activation (join), à chaque progression et à la réclamation ; `terminée = { Id, Title, Target, Rewards }` seulement pour une quête AutoClaim |

Jamais `PlayerData` : le client ne reçoit que la vue (avec `Rewards`, copie des récompenses annoncées).
La réclamation ajoute les récompenses de `QuestConfig.Rewards`, une seule fois même si le client
insiste ; celles du stage restent à RewardService.

Révélation (`src/client/UI/Views/QuestRewardView.lua`) : « QUÊTE ACCOMPLIE ! » qui jaillit sur rayons
dorés, chaque carte tombe, rebondit, tremble, éclate (flash, confettis aux couleurs de la map), se
retourne sur l'objet (« x1 », nom), étoiles qui scintillent ; « Récupérer ! » (clic, toucher, Entrée)
fait voler la carte jusqu'à son compteur du HUD, qui s'anime. Un ticket montre ensuite le portail.
Tant qu'une récompense attend, la fenêtre de quête attire l'œil (contour doré qui pulse, rayons derrière
le parchemin, bouton « Récupérer » qui respire, petit rebond régulier). La récompense n'y est jamais
nommée : c'est une surprise, révélée seulement à la réclamation.

`src/client/Controllers/QuestController.lua` :
- au join, il appelle `GetActiveQuest` puis `QuestView.Show` ; ensuite, chaque `QuestChanged` met
  la vue à jour (progression, « Quête terminée ! », bouton **Récupérer**) ;
- **Récupérer** : petit pop, bouton désactivé tout de suite (double clic sans effet), puis
  `ClaimQuest(questId)` ; les récompenses renvoyées sont révélées. La quête suivante, déjà envoyée par le
  serveur, n'apparaît qu'une fois le reveal fermé et les compteurs du HUD relus. Refus : message bref et
  bouton de nouveau disponible. Une vue `nil` ferme le suivi (`QuestView.Hide`) ;
- pendant le combat, son outro, l'écran de fin et l'invocation, une mise à jour attend que l'écran
  soit libre (après « Continuer ») : jamais d'annonce ni de reveal par-dessus l'écran de fin ;
- quête AutoClaim (`SummonStarter`) : « Quête terminée ! » puis la suivante, sans bouton.

Boucle d'une victoire : mort du dernier ennemi → sac → « VICTOIRE ! » → écran de fin du stage →
Continuer → « Quête terminée ! » + « Récupérer » qui attire l'œil (sans délai, sans réclamation forcée)
→ reveal (cartes une à une) → vol vers Or / Gemmes / Ticket, compteurs animés → quête suivante, chemin
lumineux vers la pancarte, stage suivant déjà sélectionné (voir ARENA_PROTOTYPE.md).

Le suivi est en haut à gauche, sous la fenêtre de chat Roblox et sa barre de saisie quand elles y
sont. Sans cela, le chat recouvre le suivi et capte le clic sur « Récupérer ».

## Lignes de quêtes (regroupement)

Les quêtes sont regroupées en **lignes** (`QuestConfig.Lines`) : chaque ligne est une chaîne de paliers
(`NextQuestId`) qui avance en parallèle des autres. Le panneau montre **une carte par ligne**, au palier
courant (« Défense du domaine · Palier 3/5 ») ; une ligne finie montre son dernier palier « ✓ Récupéré ».

| Ligne | Ouverte | Paliers |
| --- | --- | --- |
| Défense du domaine (`Stages`) | après `SummonStarter` | 1-1 → 1-2 → 1-3 → 1-4 → Roi Orc (1-5) |
| Collection de héros (`Heroes`) | dès le début | premier héros (tutoriel) → 2 → 5 → 10 → 20 → 30 → 45 → 60 héros |

- « Possède N héros » : objectif d'état `HeroesOwned` = nombre de héros **différents** (HeroId) possédés,
  relu dans PlayerData à chaque changement de collection (`HeroService` → `QuestService:SyncState`) et à
  l'activation du palier ; ne fait que monter ; jamais compté depuis un événement. Récompenses ALPHA
  PROVISOIRES (QuestConfig).
- Quête **principale** (suivi du HUD, guidage, caméra d'accueil) : la quête active de la première ligne
  ouverte. Nouveau profil : seule la ligne Héros est ouverte (SummonStarter), puis la Défense s'ouvre et
  devient principale : le tutoriel est inchangé. Défense finie : le palier Héros devient principal.
- Réclamation : seule la quête active de SA ligne, terminée, est réclamable ; les autres lignes ne bougent
  pas. La vue principale porte `ClaimableCount` (quêtes à récupérer, toutes lignes) pour le « ! » du bouton
  Quêtes.
- Ajouter une ligne : une entrée dans `Lines` (Id, Title, FirstQuestId, After?) et ses quêtes chaînées ; une
  quête n'appartient qu'à une ligne (validé au démarrage).

## Panneau Quêtes

Représentation UI du système existant (aucune logique de quête côté client) :

- `Remotes.GetQuestLog` (lecture seule) : les quêtes réclamées de la chaîne puis la quête active (jamais
  les suivantes), avec `Description` (QuestConfig, optionnelle), progression, état et récompenses.
- `QuestPanelView` (bouton Quêtes du menu, ou « Récupérer » du suivi) : à récupérer, puis en cours, puis
  récupérées (`Shared.Quests.QuestLog`, pur et testé : `tools/test-ui.ps1`).
- **Une seule interface réclame** : « Récupérer » du panneau envoie `ClaimQuest(questId)` — uniquement
  l'Id ; le serveur revérifie tout et ajoute les récompenses de QuestConfig, une fois. Le suivi du HUD ne
  réclame plus : son bouton ouvre le panneau.
- Après un claim réussi : reveal (`QuestRewardView`), monnaies 3D qui volent vers le HUD (feedback seulement,
  le serveur a déjà attribué), puis le HUD relit le serveur ; le panneau montre « ✓ Récupéré » et la suite.
- Notification du bouton Quêtes (`QuestController.attention`) : récompense à récupérer (priorité absolue),
  ou nouvelle quête activée pendant la session et pas encore vue dans le panneau ; elle disparaît après le
  claim (s'il ne reste rien à récupérer).
- Test en Studio : `DebugData:Invoke(player, "SetQuestState", questId, progression, réclamée)`.

## Onboarding : premier spawn

`src/client/Controllers/OnboardingCameraController.lua` (+ `Arena/OnboardingView.lua`, pur et testé).
Quand la quête active a `Onboarding = true` (`SummonStarter`), une fois le plot attribué et le personnage
posé sur SON `PointApparition` : le personnage est tourné vers SON arène et la caméra glisse en 0,6 s
derrière lui, légèrement au-dessus, regard vers l'arène (centre de `Arene` du plot du joueur, sinon sa
`PanneauStage`). Puis `CameraType = Custom`, `CameraSubject = Humanoid` : la caméra est rendue tout de
suite. Une seule fois par session (pas après un reset ni une mort) et jamais pour un profil sorti de
`SummonStarter`. Les 8 `PointApparition` regardent déjà leur propre arène (audit Studio : écart 0°).

## Guidage (flèches au sol)

Le joueur doit pouvoir suivre le jeu presque sans lire : une quête qui demande d'aller quelque part
porte `Guide = { Target = ... }`. La vue de la quête active expose alors `GuideTarget` (présentation
seulement, rien de PlayerData), retiré dès que la quête est terminée.

| Cible (`Shared.Quests.QuestGuide.Targets`) | Objet du plot du joueur | Arrivée (studs) |
| --- | --- | --- |
| `StageSign` | `Arene.PanneauStage` (chemin vers `Banniere`) | 10 |
| `SummonPortal` | `PortailInvocation` (focus `Structure`) | 12 |
| `Arena` | `Arene` (focus `Emplacements`) | 25 |
| `Kingdom` | `Royaume` | 14 |
| `HeroPlacement` | `Arene.Emplacements.Heros` | 8 |

`src/client/Controllers/QuestGuideController.lua` (visuel seulement) :
- résout la cible dans le plot du joueur local (`PlotView`), jamais `PlotTravail` ni un autre plot ;
- chemin `PathfindingService` (client) depuis `HumanoidRootPart`, recalculé seulement si la cible
  change, si le joueur a bougé de 6 studs ou si le calcul a échoué (ligne droite en secours) ;
- 10 flèches dorées au plus devant le joueur (`UI/GuideArrows`, même flèche chunky que la flèche UI, en
  pièces simples, sans asset), couchées au sol tous les 4,5 studs et tournées vers la suite du chemin ; une
  vague avance vers la cible (la flèche au passage se soulève, les autres s'estompent un peu) ;
- une grosse flèche 3D rebondit au-dessus de la cible (pancarte, portail, puis dalle pendant
  l'apprentissage de la pose), toujours tournée vers la caméra ;
- cible : elle-même « vivante » (`UI/WorldPulse`, valeurs `UITheme.World.Guide`) : léger voile doré qui
  respire, sans contour au creux, lumière qui pulse et quelques étincelles ; aucune pancarte « OBJECTIF » ;
- `Guide.Placement` (1-1) : à l'arène, tant qu'aucun héros n'est posé, le héros à prendre luit dans la
  hotbar et la dalle `ArenaConfig.PlacementSlot` (centre) pulse ; un héros posé, la pancarte pulse, la
  pastille « F · Lancer » respire et la fenêtre Expédition met en avant « Préparer l'équipe » ou « Lancer » ;
- masqué pendant le combat (entrée des ennemis comprise), les écrans (récompenses, invocation,
  stages) et une fois la quête terminée ; à la distance d'arrivée, le chemin s'efface, la cible reste
  légèrement en évidence et l'interaction normale (E) prend le relais.

Règles de visibilité et résolution : `QuestGuide.mode` et `QuestGuide.resolve`, purs et testés
(`tools/test-presentation.ps1`, `tools/test-quests.ps1`). Côté interface (flèche UI vers le raccourci à
prendre, « Lancer », « Invoquer ») : voir `docs/TUTORIAL_GUIDANCE.md`.

Aucun système d'événements générique n'existe encore dans le projet. Tant que les appelants
sont peu nombreux, #7 appelle directement QuestService (puis RewardService) ; un bus
d'événements serveur pourra être introduit si le nombre d'abonnés le justifie.

## Validation

Tests locaux du vrai module avec un double de DataService (Luau CLI officiel) :

```powershell
./tools/test-quests.ps1 -LuauPath <chemin-vers-luau.exe>
```

Ils couvrent l'activation, la non-réinitialisation, les données absentes, les événements
non correspondants, la progression bornée, la réclamation unique, le rejoin (avant / après la
réclamation), deux joueurs indépendants, l'enchaînement `NextQuestId`, `NextQuestId = nil`, les configs
invalides, le guidage, la vraie chaîne de la Zone 1 (récompenses exactes, une fois chacune), AutoClaim,
le stage déjà gagné avant la quête, les réclamations falsifiées / futures / répétées et le nom du boss.

En Studio, `ServerStorage.DebugData` (DebugService, Studio uniquement) simule ZoneService
depuis la ligne de commande côté Serveur : `"GetActiveQuest"`,
`"QuestEvent", "StageCompleted", { Zone = 1, Stage = 1 }` et `"ClaimQuest", "DefendDomain"`.
La vraie fin de Stage 1 ne pourra être testée qu'avec #7 et #8.
