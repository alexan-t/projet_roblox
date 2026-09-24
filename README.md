# projet_roblox

Jeu Roblox, Alpha 0.0.1. Le code vit dans Git et est synchronisé dans Studio avec [Rojo](https://rojo.space). Les assets et le level design vivent dans Studio (Team Create).

## Qui fait quoi

| Quoi | Où | Comment |
| --- | --- | --- |
| Code Luau (scripts, modules) | `src/` dans Git | branche `feature/*` → PR vers `develop`, synchronisé par Rojo |
| Assets, maps, UI, modèles | Studio (Team Create, Packages) | pas de Git |
| Snapshot du Sandbox partenaire | `studio/sandbox/partner_sandbox.rbxl` | fichier remplacé en entier, jamais fusionné, sans code Luau |

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

## Workflow Git

- On part toujours de `develop` à jour, sur une branche `feature/<sujet>`.
- Commits au format `type(scope): message` (`feat`, `fix`, `chore`, `docs`...).
- PR vers `develop`, jamais de push direct sur `develop` ni sur `main`.
- `main` ne reçoit que des versions validées depuis `develop`.
