# projet_roblox

Jeu Roblox, Alpha 0.0.1. Le code vit dans Git et est synchronisé dans Studio avec [Rojo](https://rojo.space). Les assets et le level design vivent dans Studio (Team Create).

## Qui fait quoi

| Quoi | Où | Comment |
| --- | --- | --- |
| Code Luau (scripts, modules) | `src/` dans Git | branche `feature/*` → PR vers `develop`, synchronisé par Rojo |
| Assets, maps, UI, modèles | Studio (Team Create, Packages) | pas de Git |
| Snapshot du Sandbox partenaire | `studio/sandbox/partner_sandbox_v3.rbxl` (version courante ; `partner_sandbox_v2.rbxl` et `partner_sandbox.rbxl` = anciennes versions) | fichier remplacé en entier, jamais fusionné, sans code Luau |

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

## Royaume (KingdomService)

Le serveur clone sur le plot du joueur le modèle de royaume qui correspond à
`Kingdom.VisualState`, puis un modèle par héros possédé. Les modèles et les
repères restent dans Studio : voir le [contrat d'assets, l'API et les tests](docs/KINGDOM.md).

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
`StageCompleted`) avec `QuestService:HandleGameplayEvent`. Voir le
[format de la config, l'API et les contrats avec les autres services](docs/QUESTS.md).

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
[placement des héros dans l'arène de test](docs/ARENA_PROTOTYPE.md) (hotbar, sacoche, E = Combattre).

## Héros possédés et hotbar (HeroService, Alpha)

Kit de départ, hotbar de 10 raccourcis sauvegardée et vérification de possession : voir
[les données, les règles et l'API](docs/HEROES.md).

## Animations (AnimationKit)

`tools/animation/AnimationKit.luau` est un outil Studio (non synchronisé par Rojo) qui pose un
squelette sur un héros ou un monstre généré par l'IA, génère sa marche et la montre en boucle à
côté du spawn au Play. Voir [l'utilisation, le format de modèle et les profils](docs/ANIMATION_TOOLS.md).

## Workflow Git

- On part toujours de `develop` à jour, sur une branche `feature/<sujet>`.
- Commits au format `type(scope): message` (`feat`, `fix`, `chore`, `docs`...).
- PR vers `develop`, jamais de push direct sur `develop` ni sur `main`.
- `main` ne reçoit que des versions validées depuis `develop`.
