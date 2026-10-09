# Récompenses de stage et First Clear (RewardService)

Issue #9. Le serveur décide seul de ce qu'une victoire rapporte. Le client ne fait qu'afficher.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `src/server/Config/RewardConfig.lua` | Données : récompenses par stage |
| `src/server/Rewards/RewardRules.lua` | Règles pures : validation, First Clear, ajout des devises |
| `src/server/Services/RewardService.lua` | Service : chargement de la config, identité de completion, attribution |

## Config

```lua
Stages = {
	["1-1"] = {
		FirstClearReward = { { Kind = "Gold", Amount = 100 }, { Kind = "Gems", Amount = 10 },
			{ Kind = "SummonTicket", Amount = 1, New = true } },
		RepeatReward = { { Kind = "Gold", Amount = 20 } },
	},
}
```

- **Clé** : `"<zone>-<stage>"`, la même que `Progression.FirstClears`.
- **`FirstClearReward`** : donnée une seule fois par sauvegarde, à la première victoire du stage.
- **`RepeatReward`** : donnée à chaque victoire suivante (replay). Une liste vide est permise.
- **Récompense** : `{ Kind, Amount, New? }`.
  - `Kind` vaut `Gold`, `Gems` ou `SummonTicket` ; il alimente `Currencies.Gold`, `Currencies.Gems` ou `Currencies.SummonTickets`.
  - `Amount` est un entier fini ≥ 0.
  - `New` est un simple badge « Nouveau » sur l'écran de fin, sans effet de gameplay.
- **Valeurs Alpha provisoires.** Seul le ticket d'invocation du premier clear de 1-1 est exigé (#9, il sert à #10). L'or, les gemmes et le replay sont des valeurs de départ à équilibrer.

Au démarrage (`Init`), chaque entrée est validée. Une entrée est refusée, avec un warning, si l'un de ces cas se présente :
- `Kind` inconnu ;
- montant négatif, décimal, infini ou NaN ;
- liste manquante ou mal formée ;
- `New` non booléen.

Une entrée refusée ne donne **rien**, pas même le First Clear. Les autres stages restent utilisables.

## Flux

```
CombatEngine : Victory / Defeat
  → CombatService verrouille sa session (stop)
  → ZoneService:CompleteStage(player, sessionId, victory)          -- une seule fois par session
      victoire seulement :
      → QuestService:HandleGameplayEvent(player, "StageCompleted", { Zone, Stage })
      → RewardService:HandleStageCompleted(player, zone, stage, sessionId)
  → CombatService envoie au client UN SEUL CombatEnded { Result, FirstClear, Rewards }
  → OnCombatEnded (callbacks serveur)
```

- ZoneService fournit le résultat du stage, QuestService fait avancer les quêtes et RewardService distribue les récompenses. Il n'y a pas de bus d'événements : ZoneService appelle les deux services à la suite, comme le prévoyait `docs/QUESTS.md`.
- Le `CombatEnded` interne du moteur n'est jamais envoyé tel quel. CombatService envoie un seul `CombatEnded` enrichi, **après** l'attribution.
- Défaite : `FirstClear = false`, `Rewards = {}`. RewardService n'est pas appelé.
- Victoire refusée par RewardService (données non chargées, config invalide…) : `FirstClear = false`, `Rewards = {}`, avec un warning côté ZoneService.

## API serveur

| Méthode | Résultat |
| --- | --- |
| `HandleStageCompleted(player, zone, stage, completionId)` | `{ FirstClear, Rewards }`, ou `nil` et la raison |

Raisons de refus :
- `"données non chargées"` ;
- `"completion inconnue"` (`completionId` nil) ;
- `"stage inconnu"` ;
- `"récompenses invalides"` ;
- `"completion déjà récompensée"`.

`Rewards` est une **copie** de la liste réellement attribuée, au format attendu par `RewardScreenController.Show`.

## Garanties

- **First Clear.** La section critique vérifie `FirstClears[key]`, le marque à `true`, puis ajoute les devises. Elle est synchrone, sans aucun yield. Deux appels ne peuvent donc pas voir tous les deux « pas encore cleared ».
- **Identité de completion.** C'est l'id de la session de stage de ZoneService, unique sur le serveur. Une même completion n'est récompensée qu'une fois : un rappel tardif ou dupliqué est refusé, ce qui empêche de recevoir à la fois `FirstClearReward` et `RepeatReward` pour une seule victoire. Les ids sont mémorisés par joueur et oubliés à son départ.
- **Persistance.** Les devises et `FirstClears` sont modifiés dans le profil DataService **avant** l'envoi de `CombatEnded` ; ProfileStore les sauvegarde. Rien n'est à « réclamer » : il n'existe aucune remote `ClaimReward`. Une déconnexion pendant l'écran de fin ne perd donc rien. Après un rejoin, le First Clear déjà sauvegardé fait que seule `RepeatReward` est donnée.
- **Déverrouillage.** `FirstClears["1-1"] = true` déverrouille 1-2 dans ZoneService (`"stage verrouillé"`), sans autre changement.
- **Progression.** `Progression.HighestStage` et `Progression.CurrentZone` ne sont ni lus ni écrits. Aujourd'hui, aucun code ne les utilise : seules leurs valeurs par défaut existent. #9 ne leur invente pas de règle.

## Client

`ArenaPlacementController` reçoit le `CombatEnded` enrichi. Après `RESULT_DELAY`, il appelle `RewardScreenController.Show({ Result, FirstClear, Rewards })`.

Aucun affichage permanent des devises n'existe encore : `CurrencyView` ne sert que dans l'aperçu UI. Le solde est visible dans les données du joueur.

## Validation

```powershell
./tools/test-rewards.ps1 -LuauPath <chemin-vers-luau.exe>
```

- `RewardService.spec.lua` utilise le vrai service, les vraies règles et la vraie config. Il couvre :
  - premier clear et ticket ;
  - montants exacts ;
  - replay ;
  - même completion appelée deux fois ;
  - deux joueurs ;
  - données non chargées ;
  - stage inconnu ;
  - config invalide ;
  - rejoin.
- `RewardFlow.spec.lua` est le test d'intégration du vrai chemin CombatEngine → CombatService → ZoneService → QuestService → RewardService → `CombatEnded`. Il couvre la victoire, la défaite, le replay, l'appel en double et deux joueurs.
