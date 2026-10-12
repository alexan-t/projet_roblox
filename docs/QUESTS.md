# Quêtes — QuestService

`QuestService` (#6) guide le joueur par une chaîne de quêtes, sans tutoriel lourd.
Première quête : **Défends ton domaine**, terminer Zone 1 - Stage 1.
La logique est serveur. Le client lit une vue en lecture seule et demande la réclamation par
remote (#11, voir § Remotes et HUD).

## QuestConfig

`src/server/Config/QuestConfig.lua` décrit toutes les quêtes. Le code ne connaît aucune
quête en particulier : ajouter une quête se fait uniquement dans la config.

```lua
FirstQuestId = "DefendDomain",
Quests = {
	DefendDomain = {
		Title = "Défends ton domaine",
		Objective = {
			Event = "StageCompleted",        -- événement gameplay attendu
			Match = { Zone = 1, Stage = 1 }, -- champs que le payload doit avoir, à l'identique
			Target = 1,                      -- nombre d'événements correspondants
		},
		NextQuestId = nil,                   -- quête suivante, nil = fin de la chaîne
	},
},
```

- La clé (`DefendDomain`) est l'identifiant technique stable, sauvegardé dans PlayerData.
  Ne jamais la renommer sans migration.
- `Match` est facultatif : sans lui, tout événement du bon nom compte. Les valeurs sont
  comparées strictement (`1` ≠ `"1"`) ; les champs du payload absents de `Match` sont ignorés.
- La config est vérifiée au démarrage : `Title`, `Objective.Event`, `Target` entier ≥ 1,
  `Match` table, `NextQuestId` existant, `FirstQuestId` existant et aucune boucle.
  En cas d'erreur, chaque problème est journalisé et les quêtes sont désactivées, sans crash.

## PlayerData

Aucun changement de schéma, aucune migration. Le champ existant suffit :

```lua
Quests: { [QuestId]: { Progress: number, Claimed: boolean } }
```

La **quête active** n'est pas sauvegardée à part : c'est la première quête de la chaîne
`FirstQuestId → NextQuestId` qui n'est pas encore réclamée. Si elle n'a pas encore d'état,
elle est créée à `{ Progress = 0, Claimed = false }`. Cette activation a lieu à chaque
`DataService:OnPlayerReady` et à chaque appel de l'API. Elle est idempotente : un état
existant n'est jamais réinitialisé, ni au rejoin, ni lors d'une nouvelle activation.

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
local ok, reason = QuestService:ClaimQuest(player, "DefendDomain")
```

- Acceptée une seule fois, sur une quête terminée (`Progress >= Target`) et pas encore
  réclamée : `Claimed` passe à `true` et la quête `NextQuestId` est activée si elle existe.
- Refusée sinon, avec la raison : `"données non chargées"`, `"quête inconnue"`,
  `"quête non commencée"`, `"quête non terminée"` ou `"déjà réclamée"`.
- `Claimed` est sauvegardé par DataService : une réclamation reste acquise après un rejoin.
- **Aucune récompense n'est attribuée** : l'issue #6 n'en définit pas. QuestService ne
  modifie ni les devises, ni `Progression.FirstClears`, ni les tickets d'invocation.

## API serveur

| Méthode | Résultat / usage |
| --- | --- |
| `GetActiveQuest(player)` | `{ Id, Title, Progress, Target, Completed }` (copie), ou `nil` : données pas prêtes, quêtes désactivées, ou chaîne entièrement réclamée |
| `GetQuestState(player, questId)` | `{ Progress, Claimed }` (copie), ou `nil` si la quête n'a jamais été commencée |
| `HandleGameplayEvent(player, eventName, payload)` | Voir « Événements gameplay » |
| `ClaimQuest(player, questId)` | `true`, ou `false` et la raison du refus |

## Contrats avec les issues suivantes

- **ZoneService (#7)** : quand un stage est réellement terminé côté serveur, il appelle
  `QuestService:HandleGameplayEvent(player, "StageCompleted", { Zone = zone, Stage = stage })`.
  QuestService ne dépend pas de ZoneService ni de CombatService (#8).
- **RewardService (#9, `docs/REWARDS.md`)** : ZoneService l'appelle juste après QuestService
  pour le même `StageCompleted`. Il reste seul responsable
  des récompenses de stage, du First Clear (`Progression.FirstClears`) et du ticket
  d'invocation initial. Si une quête doit un jour donner une récompense, elle sera définie
  dans la config et attribuée par RewardService, pas par QuestService.
- **Controllers / UI (#11)** : `QuestController` affiche la vue de `GetActiveQuest` et réclame
  par `Remotes.ClaimQuest` (voir § Remotes et HUD).

## Remotes et HUD (#11)

| Remote | Sens | Contenu |
| --- | --- | --- |
| `GetActiveQuest` (RemoteFunction) | client → serveur | vue `{ Id, Title, Progress, Target, Completed }` (copie) ou `nil` |
| `ClaimQuest` (RemoteFunction) | client → serveur | le client n'envoie que l'Id de quête (texte) ; réponse `(ok, raison?)`, tout est revérifié (`quête non terminée`, `déjà réclamée`, `quête inconnue`) |
| `QuestChanged` (RemoteEvent) | serveur → le seul joueur | même vue, ou `nil` quand la chaîne est terminée ; envoyée à l'activation (join), à chaque progression et à la réclamation |

Jamais `PlayerData` : le client ne reçoit que la vue. La réclamation ne donne aucune récompense
(celles du stage viennent de RewardService).

`src/client/Controllers/QuestController.lua` :
- au join, il appelle `GetActiveQuest` puis `QuestView.Show` ; ensuite, chaque `QuestChanged` met
  la vue à jour (progression, « Quête terminée ! », bouton **Récupérer**) ;
- **Récupérer** appelle `ClaimQuest(questId)`. Une vue `nil` ferme le suivi (`QuestView.Hide`) :
  il n'existe pas de quête suivante aujourd'hui ;
- pendant l'écran de fin de combat, une mise à jour attend « Continuer », pour que l'annonce ne se
  perde pas derrière l'écran.

Le suivi est en haut à gauche, sous la fenêtre de chat Roblox et sa barre de saisie quand elles y
sont. Sans cela, le chat recouvre le suivi et capte le clic sur « Récupérer ».

Aucun système d'événements générique n'existe encore dans le projet. Tant que les appelants
sont peu nombreux, #7 appelle directement QuestService (puis RewardService) ; un bus
d'événements serveur pourra être introduit si le nombre d'abonnés le justifie.

## Validation

Tests locaux du vrai module avec un double de DataService (Luau CLI officiel) :

```powershell
./tools/test-quests.ps1 -LuauPath <chemin-vers-luau.exe>
```

Ils couvrent l'activation, la non-réinitialisation, les données absentes, les événements
non correspondants, la progression bornée, la réclamation unique, le rejoin, deux joueurs
indépendants, l'enchaînement `NextQuestId` (avec une config de test à deux quêtes),
`NextQuestId = nil`, les configs invalides et l'absence d'effet sur le reste de PlayerData.

En Studio, `ServerStorage.DebugData` (DebugService, Studio uniquement) simule ZoneService
depuis la ligne de commande côté Serveur : `"GetActiveQuest"`,
`"QuestEvent", "StageCompleted", { Zone = 1, Stage = 1 }` et `"ClaimQuest", "DefendDomain"`.
La vraie fin de Stage 1 ne pourra être testée qu'avec #7 et #8.
