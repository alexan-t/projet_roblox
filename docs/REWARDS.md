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
- **ALPHA 0.0.2 PROVISOIRE (#80).** Les First Clears 1-2 à 1-5 restent vides (ils ouvrent la progression). `TicketEconomy` centralise les tickets de replay : Normal 1-2/1-3 = 1, 1-4 = 2, boss 1-5 = 5 ; Élite 1-1 à 1-4 = 2, boss = 10. Ainsi les x10 et x100 ont une source régulière, sans monétisation. Voir [SUMMON.md](SUMMON.md).
  - 1-1 conserve 100 or, 10 gemmes et 1 ticket au premier clear, 20 or en replay.

Au démarrage (`Init`), chaque entrée est validée. Une entrée est refusée, avec un warning, si l'un de ces cas se présente :
- `Kind` inconnu ;
- montant négatif, décimal, infini ou NaN ;
- liste manquante ou mal formée ;
- `New` non booléen.

Une entrée refusée ne donne **rien**, pas même le First Clear. Les autres stages restent utilisables.

**Mode Élite (#69)** : `RewardConfig.EliteStages`, même format et même clé `"<zone>-<stage>"`, lu quand
ZoneService termine une session Élite (`HandleStageCompleted(..., mode = "Elite")`). Son First Clear est
enregistré dans `Progression.EliteFirstClears` (il débloque le stage Élite suivant), jamais dans
`FirstClears` ; les deux progressions sont indépendantes. Les First Clears Élite restent vides ; les replays donnent les tickets définis dans `TicketEconomy` (ALPHA 0.0.2 PROVISOIRE, #80). Le butin (équipements, ressources) est géré à part par `LootConfig` (§ Loot), jamais dans `RewardConfig`.

## Flux

```
CombatEngine : Victory / Defeat
  → CombatService verrouille sa session (stop)
  → ZoneService:CompleteStage(player, sessionId, victory)          -- une seule fois par session
      victoire seulement :
      → QuestService:HandleGameplayEvent(player, "StageCompleted", { Zone, Stage })
      → RewardService:HandleStageCompleted(player, zone, stage, sessionId)   -- monnaies, First Clear, puis loot (#72)
  → CombatService envoie au client UN SEUL CombatEnded { Result, FirstClear, Rewards, Loot? }
  → OnCombatEnded (callbacks serveur)
```

- ZoneService fournit le résultat du stage, QuestService fait avancer les quêtes et RewardService distribue les récompenses. Il n'y a pas de bus d'événements : ZoneService appelle les deux services à la suite, comme le prévoyait `docs/QUESTS.md`.
- Le `CombatEnded` interne du moteur n'est jamais envoyé tel quel. CombatService envoie un seul `CombatEnded` enrichi, **après** l'attribution.
- Défaite : `FirstClear = false`, `Rewards = {}`. RewardService n'est pas appelé.
- Victoire refusée par RewardService (données non chargées, config invalide…) : `FirstClear = false`, `Rewards = {}`, avec un warning côté ZoneService.

## API serveur

| Méthode | Résultat |
| --- | --- |
| `HandleStageCompleted(player, zone, stage, completionId, mode?)` | `{ FirstClear, Rewards, Loot? }`, ou `nil` et la raison |

Raisons de refus :
- `"données non chargées"` ;
- `"completion inconnue"` (`completionId` nil) ;
- `"stage inconnu"` ;
- `"récompenses invalides"` ;
- `"completion déjà récompensée"`.

`Rewards` est une **copie** de la liste réellement attribuée, au format attendu par `RewardScreenController.Show`.

## Loot (#72, V1 serveur)

À chaque victoire, RewardService tire aussi un butin (ressources + éventuel équipement), le range dans
`PlayerData.Inventory` et le joint au résultat. Le client n'envoie jamais `ItemId`, `ResourceId`, quantité, rareté ni
résultat de tirage ; il n'existe aucun remote `GrantItem` / `GrantResource`.

> **ALPHA 0.0.2 PROVISOIRE — placeholder, à remplacer après simulation.** Toutes les valeurs de
> `src/server/Config/LootConfig.lua` (chances, quantités, poids de rareté, plafond, garantie) sont des placeholders.
> Aucune n'est un fait de design. `tools/simulate-loot.ps1` les mesure à la demande ; ses chiffres, tant que la config
> est un placeholder, ne sont pas des objectifs.

**Les catalogues existent déjà et ne sont pas réinventés.** `ItemConfig` (100 équipements, 7 emplacements, 10 raretés)
et `ResourceConfig` (60 ressources, 6 familles) sont la source de vérité ; `LootConfig` ne fait que **référencer** leurs
identifiants. Les ressources n'ont aucune rareté.

### Fichiers

| Fichier | Rôle |
| --- | --- |
| `src/server/Config/LootConfig.lua` | Données : `Stages` / `EliteStages` (clé `"<zone>-<stage>"`), `Zones` (règles de zone), `EquipmentCap` |
| `src/server/Loot/LootRules.lua` | Pur : `problems` (validation), `roll` (tirage), `preview` (aperçu) |
| `src/server/Inventory/InventoryRules.lua` | Pur : `ensure`, `addEquipment`, `addResource`, `apply`, `view` |
| `src/server/Services/InventoryService.lua` | Remotes de lecture `GetInventory` / `InventoryChanged`, fabrique d'`ItemInstanceId` |
| `tools/simulate-loot.ps1` (+ `.luau`) | Simulation déterministe, à la demande (ni test ni CI) |

### Données et contrat

```lua
PlayerData.Inventory = {
	Equipment = { [ItemInstanceId] = { ItemId = "item_015", UpgradeLevel = 0 } }, -- une entrée par exemplaire
	Resources = { ["resource_011"] = 12 },                                         -- piles, entier >= 0
}
```

- `DataVersion` **reste 4**, aucune migration : `Inventory` est une clé fixe de `DefaultPlayerData`, `Profile:Reconcile()` l'ajoute
  vide aux profils existants sans rien toucher d'autre (test de contrat dans `Migrations.spec.lua`, avec le vrai `ReconcileTable`
  de ProfileStore). Lecture tolérante : une table absente ou de mauvais type est recréée, une entrée invalide est ignorée et
  jamais supprimée.
- `ItemInstanceId` = `"I_T"` + `os.time()` (10 chiffres) + séquence (4 chiffres) + `"_"` + GUID, généré côté serveur ; le tri par
  identifiant donne l'ordre d'obtention.
- `CombatEnded` gagne un champ **séparé** de `Rewards` (qui reste les monnaies), présent pour une victoire dont le loot a été
  attribué, **absent** sinon (défaite, zone sans table, LootConfig invalide, erreur de loot) :

```lua
Loot = {
	Items = { { InstanceId = "I_T…", ItemId = "item_015" } },            -- uniques
	Resources = { { ResourceId = "resource_011", Amount = 3 } },         -- empilables, ordre du catalogue
	Overflow = false,                                                     -- true : plafond d'équipement atteint
}
```

  Le serveur n'envoie jamais de rareté : le client lit nom, rareté, emplacement, icône et famille dans `ItemConfig` /
  `ResourceConfig`. Le loot est sauvegardé (mutation de `PlayerData`) avant l'envoi de `CombatEnded`.
- Vue lecture seule : `GetInventory` (RemoteFunction) et `InventoryChanged` (RemoteEvent, poussée après chaque mutation) :
  `{ Equipment = { { InstanceId, ItemId, UpgradeLevel } } (trié par InstanceId), Resources = { { ResourceId, Amount } } (Amount >= 1,
  ordre du catalogue), Count, Cap }`. Les arguments du client sont ignorés.

### Règles de tirage (`LootRules.roll`)

- Entrée d'un stage : `Equipment = { Chance, Rarities = { { Rarity, Weight } } }`, `FirstClearEquipment = { Rarities }`
  (facultatif), `Items = { { ItemId, Chance } }` (facultatif), `Resources = { { ResourceId, Chance, Min, Max } }`.
- Équipement : avec la probabilité `Chance`, UN équipement. **Rareté d'abord** (poids entiers), **puis item uniforme** parmi les items
  du catalogue de cette rareté (pas de poids par `ItemId`).
- Ressources : chance indépendante par ressource, quantité entière `Min..Max`.
- Normal et Élite ont des tables distinctes. Zone 1 Normal : Commun / Peu commun / Rare ; Élite : Rare / Épique / Légendaire ;
  **jamais au-dessus de Légendaire** (plafond dur dans `LootRules.MAX_RARITY`, indépendant de la config).
- Ressources de la Zone 1 : familles `slime` et `horde` seulement ; `resource_010` et `resource_020` exclues.
- **x1 / x2 sans effet** (le tirage ne lit pas la vitesse). **Défaite : aucun loot** (RewardService n'est appelé que sur victoire).
  **Zone ou stage sans table** (zones 2+ à venir) : aucun loot, aucune erreur.
- `LootRules.problems` valide toute la config à l'`Init` : rareté inconnue ou hors zone, au-dessus de Légendaire, `ItemId` /
  `ResourceId` inconnu, famille hors zone, ressource exclue, doublon, chance hors `]0, 1]`, poids ou quantités invalides, plafond
  invalide, zone sans règle. **LootConfig invalide = warning + aucun loot** ; le First Clear et les monnaies ne sont jamais bloqués.

### Garanties

- Même section synchrone et même identité de completion que le First Clear : une completion = un seul butin (double remote,
  rappel, rejoin). Le Random est côté serveur.
- Une erreur du tirage ou du rangement est absorbée (`pcall`) : le First Clear et les monnaies déjà attribués restent acquis.
- Deux joueurs sont indépendants (inventaires, identifiants, mémoire des completions).

### Choix PROVISOIRES et points ouverts (ALPHA 0.0.2)

1. **Garantie du Roi Orc (Normal)** : 1 équipement garanti au **premier** clear de 1-5 Normal (`result.FirstClear`), tiré dans le pool
   Normal, **en plus** du tirage normal (donc 1 ou 2 à ce premier clear). Aucune garantie en Élite. Point ouvert : valeur et forme.
   Pas de rattrapage : si l'équipement garanti est refusé (plafond atteint, `Overflow`) ou si le rangement échoue, le First Clear
   est tout de même consommé et la garantie est perdue. Si le rangement lève en cours de route (cas théorique : fabrique
   d'identifiants en erreur), les exemplaires déjà créés restent, les ressources suivantes sont perdues et `Loot` vaut `nil` ;
   la completion reste marquée (aucun rejeu).
2. **`resource_030` (Corne du Roi Orc)** : x1 à **chaque** victoire de 1-5 Normal et de 1-5 Élite ; `resource_029` (Défense d'Orc) :
   chance placeholder en 1-5.
3. **`resource_010` et `resource_020`** (trophées de boss absents de la Zone 1) : **exclus** du loot Zone 1.
4. **Plafond d'équipement : 500 instances** (provisoire). Au-delà, l'équipement n'est pas créé (`Overflow = true`) ; ressources et
   monnaies toujours accordées. Point ouvert : valeur, ou autre mécanisme (la simulation mesure l'accumulation).
5. **`ItemPool`** : aucune extension du contrat `Drop`. « Butin possible » (`PotentialDrops`) ne liste que les ressources avec leurs
   chances réelles, plus d'éventuels items précis configurés (`Items`, vide aujourd'hui). L'équipement aléatoire n'est pas listé ligne
   par ligne.
6. **`SaveNow`** : pas de sauvegarde forcée (`Profile:Save`) après un loot ; ProfileStore sauvegarde à son rythme et à la
   fermeture. Point ouvert (risque : perte du dernier loot en cas d'arrêt brutal du serveur).
7. **Pas de poids par `ItemId`** : uniforme dans la rareté.
8. **Seuils de simulation** : aucun. Les placeholders ne sont pas calibrés, `tools/simulate-loot.ps1` ne contient aucun seuil
   d'acceptation. **Constat du catalogue** : aucun `gloves` dans le pool Normal, un seul dans le pool Élite (7/7 emplacements
   impossible en Normal, très lent en Élite) ; à arbitrer avant de fixer les chances.

### Simulation

```powershell
./tools/simulate-loot.ps1 -LuauPath <chemin-vers-luau.exe> -Seed 1 -Runs 200 -Mode Elite -Stage 5 [-Players 1000]
```

Rapport dans `build/loot-sim/` (non versionné) : premier équipement par emplacement (médiane, p10, p90), victoires jusqu'à 7/7,
répartition des raretés, instances après 10 / 50 / 100 / 500 victoires, ressources par `ResourceId`, part de victoires sans équipement.
Générateur mulberry32 propre : mêmes paramètres, mêmes chiffres. `-Stage 0` (défaut) cycle 1-1 à 1-5.

## Garanties

- **First Clear.** La section critique vérifie `FirstClears[key]`, le marque à `true`, puis ajoute les devises. Elle est synchrone, sans aucun yield. Deux appels ne peuvent donc pas voir tous les deux « pas encore cleared ».
- **Identité de completion.** C'est l'id de la session de stage de ZoneService, unique sur le serveur. Une même completion n'est récompensée qu'une fois : un rappel tardif ou dupliqué est refusé, ce qui empêche de recevoir à la fois `FirstClearReward` et `RepeatReward` pour une seule victoire. Les ids sont mémorisés par joueur et oubliés à son départ.
- **Persistance.** Les devises et `FirstClears` sont modifiés dans le profil DataService **avant** l'envoi de `CombatEnded` ; ProfileStore les sauvegarde. Rien n'est à « réclamer » : il n'existe aucune remote `ClaimReward`. Une déconnexion pendant l'écran de fin ne perd donc rien. Après un rejoin, le First Clear déjà sauvegardé fait que seule `RepeatReward` est donnée.
- **Déverrouillage.** `FirstClears["1-1"] = true` déverrouille 1-2 dans ZoneService (`"stage verrouillé"`), et ainsi de suite jusqu'à 1-5. Chaque stage DOIT donc avoir une entrée valide dans RewardConfig : sans elle, son First Clear n'est pas enregistré et le stage suivant reste verrouillé.
- **Progression.** `Progression.HighestStage` et `Progression.CurrentZone` ne sont ni lus ni écrits. Aujourd'hui, aucun code ne les utilise : seules leurs valeurs par défaut existent. #9 ne leur invente pas de règle.

## Client

`ArenaPlacementController` reçoit le `CombatEnded` enrichi. Après `RESULT_DELAY`, il appelle `RewardScreenController.Show({ Result, FirstClear, Rewards })`.

Aucun affichage permanent des devises n'existe encore : `CurrencyView` ne sert que dans l'aperçu UI. Le solde est visible dans les données du joueur.

## Fenêtre Expédition

La fenêtre montre les récompenses **réelles** du stage, sans rien inventer (`StagePreview`, voir `docs/ZONES.md`).

- **« Première victoire »** (badge « Une fois ») présente `FirstClearReward`.
  - Une fois le First Clear obtenu, la boîte reste visible, grisée, avec « ✓ Obtenue ».
  - Le titre suivant devient alors « À chaque victoire ».
- **« Ensuite, à chaque victoire »** présente l'XP par héros posé (`HeroProgressionConfig`), puis `RepeatReward`.
- **Tickets de replay (#80)** : 1-2 à 1-5 Normal et tous les stages Élite n'ont pas de First Clear, donc pas de boîte « Première victoire ». Leur boîte de replay affiche l'XP puis la tuile ticket (`CurrencyVisualConfig.SummonTicket`, « +n ») avec le montant de `TicketEconomy`. L'interface lit la vraie config et n'invente aucun montant. `Expedition.spec.lua` vérifie ces valeurs.
- **Bonus de quête** : jamais mélangé aux récompenses de stage. La quête garde son propre panneau.

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

**Loot et inventaire (#72)** : `RewardService.spec.lua` et `RewardFlow.spec.lua` couvrent aussi le loot (Normal et Élite, 1-5 Normal
premier clear, `resource_030`, plafond, `LootConfig` invalide, erreur de loot sans blocage du First Clear, anti-double completion,
x1 / x2, deux joueurs, rejoin, défaite sans loot).

```powershell
./tools/test-loot.ps1 -LuauPath <chemin-vers-luau.exe>       # LootRules + vraie LootConfig : invariants de zone, graine, garanties
./tools/test-inventory.ps1 -LuauPath <chemin-vers-luau.exe>  # InventoryRules + InventoryService : remotes en lecture seule
./tools/test-migrations.ps1 -LuauPath <chemin-vers-luau.exe> # profil v4 sans Inventory + vrai Reconcile
./tools/simulate-loot.ps1 -LuauPath <chemin-vers-luau.exe>   # outil à la demande, hors CI
```
