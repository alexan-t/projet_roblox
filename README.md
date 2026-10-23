# projet_roblox

Jeu Roblox, Alpha 0.0.1. Le code vit dans Git et est synchronisé dans Studio avec [Rojo](https://rojo.space). Les assets et le level design vivent dans Studio (Team Create).

## Qui fait quoi

| Quoi | Où | Comment |
| --- | --- | --- |
| Code Luau (scripts, modules) | `src/` dans Git | branche `feature/*` → PR vers `develop`, synchronisé par Rojo |
| Assets, maps, UI, modèles | Studio (Team Create, Packages) | pas de Git |
| Snapshot du Sandbox partenaire | `studio/sandbox/partner_sandbox_v4.rbxl` (version courante, place « test 3 » qui réunit « test » et « test 2 » ; `partner_sandbox_v3.rbxl`, `_v2` et `partner_sandbox.rbxl` = anciennes versions) | fichier remplacé en entier, jamais fusionné, sans code Luau |

Ne jamais écrire de code directement dans Studio : Rojo écrase les scripts qu'il gère à chaque synchronisation.

## Installation (une fois)

1. Installer [Rokit](https://github.com/rojo-rbx/rokit) (`winget install Rojo.Rokit`), puis dans le dossier du projet :
   ```bash
   rokit install
   ```
   Cela installe la version de Rojo fixée dans `rokit.toml`.
2. Installer le plugin Rojo dans Studio :
   ```bash
   rojo plugin install
   ```
   Si la commande échoue, installer le plugin **Rojo** depuis la Toolbox de Studio (onglet Plugins).

## Travailler avec Rojo

1. Lancer le serveur Rojo à la racine du projet :
   ```bash
   rojo serve
   ```
2. Dans Studio, ouvrir le place, onglet **Rojo** → **Connect**.
3. Modifier les fichiers dans `src/` : Studio se met à jour tout seul.

Pour générer un place de test hors Studio : `rojo build -o build/test.rbxl`.

## Arborescence

```
src/
  server/            -> ServerScriptService.Server
    Bootstrap.server.lua   charge Services/ (Init puis Start)
    Services/              un module par service : <Nom>Service.lua
  client/            -> StarterPlayer.StarterPlayerScripts.Client
    Bootstrap.client.lua   charge Controllers/ (Init puis Start)
    Controllers/           un module par contrôleur : <Nom>Controller.lua
  shared/            -> ReplicatedStorage.Shared
    Config/                constantes (GameConfig)
    Types/                 types partagés (Lifecycle)
    Utils/                 Log, Loader
```

Seuls ces trois dossiers sont gérés par Rojo. Tout le reste de ReplicatedStorage, ServerScriptService et StarterPlayerScripts, ainsi que Workspace, reste géré dans Studio.

### Ajouter un service ou un contrôleur

Créer `src/server/Services/<Nom>Service.lua` (ou `src/client/Controllers/<Nom>Controller.lua`) :

```lua
--!strict
local MonService = {}

function MonService:Init()
	-- préparation, sans appeler les autres modules
end

function MonService:Start()
	-- démarrage, tous les modules sont initialisés
end

return MonService
```

Le bootstrap le charge automatiquement. Tous les fichiers commencent par `--!strict`.

## Données joueur (DataService)

Basé sur [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (verrou de session, sauvegarde auto). Copie figée dans `src/server/Vendor/ProfileStore.luau` (commit `45c9847`, licence dans `licenses/`) : ne pas la modifier.

- Structure : `src/shared/Types/PlayerDataTypes.lua`. Valeurs de départ : `src/server/Data/DefaultPlayerData.lua`.
- Ajouter un champ : l'ajouter aux deux fichiers, il apparaît tout seul dans les profils existants.
- Renommer, déplacer ou convertir un champ : ajouter une migration dans `src/server/Data/Migrations.lua`.
- Les autres services attendent le profil avec `DataService:WaitForData(player)` ou `DataService:OnPlayerReady(fn)`.
- En Studio, les données vont dans un store séparé (`PlayerData_Studio`). Pour qu'elles persistent entre deux Play, activer *Game Settings → Security → Enable Studio Access to API Services* ; sinon ProfileStore travaille en mémoire.

## Plots joueur (PlotService)

Le serveur attribue un plot libre après le chargement des données, y replace le
joueur au respawn, puis libère l'emplacement et ses objets temporaires au départ.
Les 8 à 12 emplacements restent créés dans Studio : voir le
[contrat de map, l'API serveur et les tests](docs/PLOTS.md).

## Monde Alpha

Lobby commun de la DEV : place centrale, 8 plots (royaume, portail d'invocation, arène personnelle),
spawn commun `Lobby.Monde.SpawnLobby`, forêt de bordure et limites. Intégré depuis la place
partenaire « test 3 » et validé à deux joueurs : voir [le plan, les distances et la validation](docs/WORLD.md).

## Royaume (KingdomService)

Le serveur clone sur le plot du joueur le modèle de royaume qui correspond à
`Kingdom.VisualState`, puis un modèle par héros possédé. Les modèles et les
repères restent dans Studio : voir le [contrat d'assets, l'API et les tests](docs/KINGDOM.md).
Dans la DEV : états 1 et 2 et 22 héros réels présents ; les profils joueurs utilisent les HeroId réels.

## Audio (SFX et ambiance)

`AudioController` (client) joue les sons décrits dans `src/shared/Config/AudioConfig.lua`, à l'instant
des effets visuels, avec des garde-fous contre le spam. Voir [la liste des sons, leur provenance et
les déclencheurs](docs/AUDIO.md).

## Invocation (effet d'apparition)

Au portail d'invocation, `SummonEffectController` (client) joue la charge du vortex, l'éclat et la
sortie du héros obtenu, avec son nom et le badge « Nouveau ». Voir [le déroulé, l'API et la
démonstration Studio](docs/SUMMON.md).

## Quêtes (QuestService)

Les quêtes sont décrites dans `src/server/Config/QuestConfig.lua` et suivies dans
`PlayerData.Quests`. Les services de gameplay signalent les événements (par exemple
`StageCompleted`) avec `QuestService:HandleGameplayEvent`. Le client suit la quête par
`Remotes.GetActiveQuest` / `QuestChanged` et la réclame par `ClaimQuest` (`QuestController`). Voir le
[format de la config, l'API et les contrats avec les autres services](docs/QUESTS.md).

## Interface de la vertical slice (#11)

Le client n'affiche que des vues en lecture seule du serveur : quête, monnaies
(`Remotes.GetCurrencies`, `PlayerStateService`), héros, arène, combat, invocation. Tout le parcours
Join → Quête → Stage → Combat → Récompenses → Portail → Invocation → Collection → Royaume se fait à
l'interface, sans commande développeur. Voir [les états UI et la correspondance avec la checklist
#11](docs/UI_DESIGN_SYSTEM.md#13-états-ui-et-branchement-de-la-vertical-slice-issue-11).

## Zones et stages (ZoneService)

Les stages sont décrits dans `src/server/Config/StageConfig.lua`. Le joueur lance un stage
depuis son plot via `ReplicatedStorage.Remotes.RequestStartStage` ; le serveur vérifie ses
droits et crée une session, que le combat (#8) terminera. Voir les
[règles d'accès, l'API et les contrats](docs/ZONES.md).

## Combat (CombatService)

Le serveur simule tout le combat par pas fixes (`src/server/Combat/CombatEngine.lua`),
avec des stats temporaires dans `src/server/Config/CombatConfig.lua`. Il annonce la victoire ou
la défaite à ZoneService. Les ultimes sont automatiques ; le client ne peut que choisir la
vitesse x1/x2. Voir [le moteur, les événements et la sécurité](docs/COMBAT.md) et le
[placement des héros dans l'arène personnelle du plot](docs/ARENA_PROTOTYPE.md) (hotbar, sacoche,
E = Placer / Reprendre, pancarte du stage → Lancer).

**Progression Alpha** : dans chaque zone, X-1 à X-4 sont des combats d'ennemis communs et X-5 est le
boss de zone. Zone 1 : 1-1 à 1-5, boss = Roi Orc. Le Stage 1-1 se gagne avec le seul héros de départ ;
l'Écuyer + n'importe quel deuxième héros (premier tirage payant, aucun garanti) terminent la zone.
**Mode Élite** (#69) : après le Roi Orc (1-5 Normal), 1-1 à 1-5 Élite, mêmes stages et ennemis, PV / ATK
ennemis multipliés, progression (`EliteFirstClears`) et XP distinctes (ALPHA 0.0.2 provisoire).
Voir [la Zone 1](docs/ZONES.md).

## Récompenses et First Clear (RewardService)

À la victoire, ZoneService prévient QuestService puis RewardService. RewardService marque le First
Clear et ajoute les récompenses de `src/server/Config/RewardConfig.lua` (premier clear de 1-1 :
+1 ticket d'invocation ; valeurs Alpha provisoires). Le tout est sauvegardé avant l'écran de fin,
sans action « réclamer ». Voir [la config, le flux et les garanties](docs/REWARDS.md).

Depuis #72, la même victoire tire aussi un butin serveur (ressources et éventuel équipement des catalogues existants
`ItemConfig` / `ResourceConfig`), rangé dans `PlayerData.Inventory` et lisible en lecture seule (`GetInventory`). Valeurs
**ALPHA 0.0.2 PROVISOIRE** (`src/server/Config/LootConfig.lua`) ; voir [le loot, ses choix provisoires et la simulation](docs/REWARDS.md#loot-72-v1-serveur).

## Héros et invocation (HeroService)

Le premier héros est obtenu pendant l'invocation tutorielle (`Remotes.RequestStarterSummon`, gratuite,
une seule fois : `ecuyer_du_rempart`). Hotbar de 10 raccourcis sauvegardée, invocation au portail de
son plot (`Remotes.RequestSummon`, un `SummonTicket`, tirage par rareté et bannière dès la première
invocation payante : aucun héros garanti après l'Écuyer), `Remotes.HeroObtained`, migrations des
anciens profils (DataVersion 2, 3, 4). Niveaux Lv1 → Lv20 et XP par exemplaire (victoire seulement,
héros engagés, +5 % PV / ATK par niveau ; ALPHA 0.0.2 provisoire, voir HEROES.md § Niveaux et XP).
HeroId réel ≠ profil de combat temporaire : voir [les données, les règles et l'API](docs/HEROES.md).

## Items 2D (ItemConfig)

Catalogue de 100 équipements en icônes 2D (10 paliers de rareté, 7 types d'emplacement), partagé
dans `src/shared/Config/ItemConfig.lua`, relevé sur la vitrine `Workspace.Bestiaire.Inventaire`.
100 icônes livrées : 58 du partenaire (PR #74, `item_035`–`044` et `item_053`–`100`) et 42 produites
(`assets/icons/items/`, tâches `done` dans `automation/catalogues/items.json`). Pas encore de stockage, d'obtention ni d'équipement en jeu. Voir
[la provenance, la répartition, la vitrine Studio et la production des icônes](docs/ITEMS.md).

## Ressources 2D (ResourceConfig)

Catalogue de 60 ressources en icônes 2D (6 familles de 10, aucune rareté), partagé dans
`src/shared/Config/ResourceConfig.lua`, avec une tâche de production par icône dans
`automation/catalogues/resources.json`. Pas encore de stockage, d'obtention ni de recette en jeu.
Voir [la répartition, la vitrine Studio et la production des icônes](docs/RESOURCES.md).

## Animations (AnimationKit)

`tools/animation/AnimationKit.luau` est un outil Studio (non synchronisé par Rojo) qui pose un
squelette sur un héros ou un monstre généré par l'IA, génère sa marche et la montre en boucle à
côté du spawn au Play. Voir [l'utilisation, le format de modèle et les profils](docs/ANIMATION_TOOLS.md).
Héros et monstres humanoïdes partagent un même squelette (os communs, animations partagées comme la
marche, fiche « cette pièce = tel os » dans `SkeletonConfig`) : l'Écuyer du Rempart et le Roi Orc
l'utilisent, le Gobelin reste sur l'ancien squelette et les deux coexistent. Voir
[comment brancher ou migrer un modèle](docs/SKELETON.md).
Les animations de la DEV jouent en Studio ; aucune n'a encore d'`AssetId` publié (requis en production).

## Workflow Git

- On part toujours de `develop` à jour, sur une branche `feature/<sujet>`.
- Commits au format `type(scope): message` (`feat`, `fix`, `chore`, `docs`...).
- PR vers `develop`, jamais de push direct sur `develop` ni sur `main`.
- `main` ne reçoit que des versions validées depuis `develop`.
- Toute PR qui ajoute ou modifie un AssetId (image, mesh, texture, animation, son, modèle) remplit la
  case « Propriété des assets » du modèle de PR (`.github/pull_request_template.md`) : assets sous le
  propriétaire de l'expérience, chargés dans la place DEV, inventaire joint. Sinon, blocage avant le
  merge (`docs/ASSET_OWNERSHIP.md`).
