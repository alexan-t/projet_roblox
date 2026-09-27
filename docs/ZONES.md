# Zones et stages — ZoneService

`ZoneService` (#7) décide **quel stage** un joueur peut lancer, crée la **session serveur**
correspondante et reçoit sa **fin**. Il ne fait aucun combat : ennemis, dégâts, vagues
réelles, mini-boss, x2 et victoire/défaite calculées sont le rôle de CombatService (#8).

## StageConfig

`src/server/Config/StageConfig.lua` décrit tous les stages. ZoneService ne connaît aucun
stage en particulier : ajouter le Stage 2 ou la Zone 2 se fait uniquement dans la config.

```lua
Zones = {
	[1] = {
		Stages = {
			[1] = {
				Waves = {
					{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 4 } } },
				},
				MiniBoss = { EnemyId = "Boss" },
			},
		},
	},
},
```

- Zones et stages sont des listes : identifiants entiers **consécutifs à partir de 1**.
  La clé stable d'un stage est `"<zone>-<stage>"` (Stage 1 : `"1-1"`).
- `Waves` : liste non vide de vagues ; chaque vague a une liste non vide `Enemies` de
  `{ EnemyId: string non vide, Count: entier >= 1 }`.
- `MiniBoss` : facultatif, `{ EnemyId }`, affronté après la dernière vague.
- `EnemyId` est un **identifiant logique**. Stage 1 reprend les types de la vague de
  démonstration de `CombatIntroController` (`Slime`, `Gobelin`, `Boss`). Aucune statistique
  (PV, dégâts, vitesse), aucun modèle, aucune position : CombatService (#8) associera ces
  identifiants à leurs stats et à leurs modèles (future `EnemyConfig`).
- Validation au démarrage :
  - structure `Zones` / `Stages` invalide : avertissement, **aucun** stage lançable ;
  - contenu d'un stage invalide : avertissement, **ce stage** refusé (`"stage indisponible"`),
    les autres restent jouables. Pas de crash.
- La config est copiée et gelée au démarrage : ni une session ni un appelant ne peut la modifier.

## Règles d'accès

`CanStartStage(player, zone, stage)` refuse, dans cet ordre :

| Raison | Condition |
| --- | --- |
| `"données non chargées"` | joueur parti, `DataLoaded` absent ou profil absent |
| `"aucun plot"` | `PlotService:GetPlot(player)` ne renvoie rien : le stage se lance depuis son plot |
| `"stage inconnu"` | zone ou stage absent de la config, ou identifiant non entier |
| `"stage indisponible"` | stage présent mais config invalide |
| `"stage verrouillé"` | le stage précédent n'est pas dans `Progression.FirstClears` |
| `"session déjà en cours"` | une session active existe déjà pour ce joueur |

Le stage précédent est le stage `n - 1` de la même zone, ou le dernier stage de la zone
précédente pour le premier stage d'une zone. **Zone 1 / Stage 1 est toujours ouvert.**
ZoneService **ne modifie pas PlayerData** : `FirstClears` est écrit par RewardService (#9)
avec la même clé `"<zone>-<stage>"`. `CurrentZone` et `HighestStage` ne sont pas utilisés.

## Session

Une session est **runtime uniquement** (jamais sauvegardée) et au plus **une par joueur**.
`StartStage` et `GetSession` renvoient une vue gelée :

```lua
{ Id = 1, Zone = 1, Stage = 1, Status = "Running", Config = <config du stage, gelée> }
```

À chaque accès, la session est revérifiée : joueur présent, `DataLoaded`, profil chargé et
**même plot** qu'au lancement. Sinon elle est supprimée, sans attendre un signal. Elle est
aussi supprimée à `PlayerRemoving`.

## API serveur

| Méthode | Résultat |
| --- | --- |
| `CanStartStage(player, zone, stage)` | `true`, ou `false` et la raison |
| `StartStage(player, zone, stage)` | vue de la session, ou `nil` et la raison |
| `GetSession(player)` | vue de la session active, ou `nil` |
| `CompleteStage(player, sessionId, victory)` | `true` si la session active `sessionId` est terminée |
| `CancelStage(player)` | `true` si une session active a été annulée |

Cycle : `Running` → `CompleteStage(victoire)` ou `CompleteStage(défaite)` ou `CancelStage`.
Dans tous les cas la session disparaît et le joueur peut relancer un stage autorisé.
`sessionId` empêche une fin tardive d'une ancienne session de terminer la nouvelle.

## Action client → serveur

`ReplicatedStorage.Remotes.RequestStartStage` (RemoteFunction, créée par le serveur au démarrage) :

```lua
local ok, reason = Remotes.RequestStartStage:InvokeServer(1, 1)
```

- Le client n'envoie que `zone` et `stage`, deux entiers. Tout autre argument est ignoré.
- Le serveur applique les mêmes règles que `StartStage` ; réponse `(ok, raison?)`.
- Le client ne fournit jamais d'ennemis, de vagues, de config, de résultat ni de récompense.
  Il n'existe **aucune** action client pour terminer un stage.

C'est la seule remote de ce lot ; #11 (ZoneController) l'utilisera.

## Contrats

- **QuestService (#6)** : sur une **victoire** uniquement, ZoneService appelle
  `QuestService:HandleGameplayEvent(player, "StageCompleted", { Zone = zone, Stage = stage })`,
  une seule fois par session. Rien au lancement, à la défaite, à l'annulation ni au départ.
- **CombatService (#8)** : lit la session (`GetSession`) et sa `Config` pour créer le vrai
  combat (vagues, mini-boss). À la fin, il appelle
  `ZoneService:CompleteStage(player, session.Id, victory)`. C'est le seul appelant prévu.
- **RewardService (#9)** : sera appelé par ZoneService au même endroit que QuestService,
  à la victoire. Il gère First Clear (`FirstClears["<zone>-<stage>"] = true`, ce qui
  déverrouille le stage suivant), récompenses de replay et ticket initial. ZoneService
  n'attribue **aucune** récompense, devise ni ticket.

## Validation

```powershell
./tools/test-zones.ps1 -LuauPath <chemin-vers-luau.exe>
```

Le vrai module est exécuté avec la vraie config (et des configs de test) et des doubles
de DataService, PlotService et QuestService.

En Studio, `ServerStorage.DebugData` (Studio uniquement) simule CombatService depuis la
ligne de commande côté Serveur : `"StartStage", 1, 1`, `"GetStageSession"`,
`"CompleteStage", true | false` et `"CancelStage"`. Le vrai combat de Stage 1 (ennemis,
vagues physiques, mini-boss) ne pourra être testé qu'avec #8.
