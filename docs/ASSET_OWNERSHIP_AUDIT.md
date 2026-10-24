# Audit de propriété des assets — 23/10/2026

Règle : `ASSET_OWNERSHIP.md`. Place DEV « Projet Roblox - Alpha » (placeId `78875801703886`),
session Studio de `nxtoma`, `develop` à `6c81a73` (PR #96, #98, #99, #101, #102 fusionnées).

## Verdict : **FIX**

- **Configs du code** (`src/shared/Config`) : **PASS**. 223 images sur 223 appartiennent à `nxtoma`
  (republication de PR #90, commit `bf9c7f9`) ; 20 sons sous licence Roblox (`ProSoundEffects`,
  `APMOfficial`) = `TIERS-LICENCE`. Rendu contrôlé en Play (HUD, monnaies, menu : capture réelle).
- **Assets Studio** : **FIX**. Sur 3 490 AssetIds référencés par les instances de la place,
  3 383 appartiennent au compte du collaborateur **`cypher1359`** (1 208 images, 2 175 meshes),
  58 à `nxtoma` (icônes de `Bestiaire.Inventaire`), 49 à des tiers. **2 097** identifiants de
  `cypher1359` sont utilisés par des conteneurs du jeu (héros, ennemis de combat, royaume, plots,
  lobby, vitrine des royaumes).
- **Animations** : aucune `KeyframeSequence` n'a d'`AssetId` publié (32 séquences) ; elles ne
  jouent qu'en Studio (déjà noté dans `ANIMATION_TOOLS.md`). À publier sous `nxtoma`.
- **Modération** : en Play, `rbxassetid://108856662437506` (mesh `left_arm_geom` de
  `Workspace.GargouilleDormeuse`) échoue avec « Asset is not approved for the requester ».
  `rbxassetid://203785492` échoue avec « Asset type does not match requested type » (origine non
  trouvée dans Workspace, ReplicatedStorage, ServerStorage, Lighting ni StarterGui).

Méthode : `MarketplaceService:GetProductInfo` (`Creator`) sur chaque identifiant (configs + toutes
les propriétés de contenu des instances), Play dans la place DEV avec lecture de la console, capture
du HUD. `ContentProvider:PreloadAsync` sur un identifiant n'est **pas** fiable (il renvoie `Failure`
pour des images de `nxtoma` qui s'affichent) : ses résultats ne sont pas retenus ici.

## Inventaire

### Configs du code — PASS

| Fichier | Type | Nombre | Propriétaire | Contrôle |
|---|---|---|---|---|
| `ItemConfig.lua` | Image | 100 | nxtoma | OK |
| `ResourceConfig.lua` | Image | 60 | nxtoma | OK |
| `InvocationVisualConfig.lua` | Image | 21 | nxtoma | OK |
| `SacocheVisualConfig.lua` | Image | 14 | nxtoma | OK |
| `MenuIconConfig.lua` | Image | 13 | nxtoma | OK — rendu en Play |
| `CurrencyVisualConfig.lua` | Image | 9 | nxtoma | OK — rendu en Play |
| `ExpeditionVisualConfig.lua` | Image | 6 | nxtoma | OK |
| `AudioConfig.lua` | Audio | 17 + 3 | ProSoundEffects, APMOfficial | TIERS-LICENCE |

Aucun AssetId de ces configs n'a besoin d'être republié ni remplacé.

### Assets Studio utilisés par le jeu — FIX

Un identifiant partagé par plusieurs modèles est compté une fois, sur le premier modèle (ordre
alphabétique). Liste détaillée, identifiant par identifiant : relancer
`tools/studio-check-asset-ownership.luau` avec `ROOTS` = le conteneur.

| Conteneur (Studio) | Assets | Ancien propriétaire | Nouvel AssetId | Contrôle |
|---|---|---|---|---|
| `ServerStorage.Assets.Heros` (60 héros, hors Écuyer compté ci-dessous) | 1 042 (≈ 9 images + 9 meshes par héros) | cypher1359 | à publier | FIX-PROPRIETAIRE |
| `ReplicatedStorage.Assets.Combat` : `Heros_EcuyerDuRempart` (même assets que le héros) | 18 | cypher1359 | à publier | FIX-PROPRIETAIRE |
| `ReplicatedStorage.Assets.Combat` : `Ennemi_Gobelin`, `Ennemi_RoiOrc`, `Ennemi_Slime` | 44 | cypher1359 | à publier | FIX-PROPRIETAIRE |
| `ServerStorage.Assets.RoyaumeEtats` (`Royaume_Etat1`, `Royaume_Etat2`) | 574 meshes | cypher1359 | à publier | FIX-PROPRIETAIRE |
| `Workspace.VitrineRoyaumes` (meshes qui ne sont pas déjà dans `RoyaumeEtats` ; les niveaux 1-2 et 4-20 n'en ajoutent pas) | 323 meshes | cypher1359 | à publier | FIX-PROPRIETAIRE |
| `Workspace.Lobby.Plots` | 82 meshes | cypher1359 | à publier | FIX-PROPRIETAIRE |
| `ServerStorage.Assets.Royaume` (6 décors) | 12 | cypher1359 | à publier | FIX-PROPRIETAIRE |
| `ServerStorage.Assets.Decor.GrandArbre` | 2 | cypher1359 | à publier | FIX-PROPRIETAIRE |
| Mannequins R15 de `Assets.Combat` (`Heros_Archer`… `MannequinSlime`) | 27 animations `Roblox`, 14 meshes `RBLXImagineer`, 1 mesh `tombluedog84`, 1 image `AvLab` | tiers | — | à arbitrer (modèles provisoires, pas de la DA) |
| `Lighting.Sky` | 4 images `DodgerJavi`, 1 image `meow_pizza` | tiers | — | à arbitrer |
| `Workspace.Baseplate.Texture` | 1 image `meow_pizza` | tiers | — | à arbitrer (baseplate de test) |

`Workspace.PlotsZones.*.Royaume`, `Workspace.PlotTravail.Royaume` et `PortailInvocation`
réutilisent les identifiants ci-dessus : ils se règlent avec eux.

### Hors jeu (références, ateliers, archives) — non bloquant tant qu'ils restent hors jeu

| Conteneur | Assets de cypher1359 | Statut |
|---|---|---|
| `Workspace.Bestiaire.Heros` | 1 124 | référence de design ; FIX si un modèle en sort pour le jeu |
| ~85 modèles de monstres posés dans `Workspace` (KingTreant, RoiOrc, KingSlime, Treant_Masque, gobelins, slimes, …) | 1 058 | idem ; les monstres branchés en combat passent par `ReplicatedStorage.Assets.Combat` |
| `Workspace.AtelierAnimation`, `ServerStorage.Archive_*` | 925 | atelier / archive |

## Opérations restantes

Aucune n'a été faite : elles demandent l'accord de l'utilisateur (republication en masse,
remplacement d'identifiants) et une session Studio de `nxtoma`.

1. **Décider** (utilisateur) : republier sous `nxtoma` les ~2 100 assets du jeu, ou demander
   d'abord à `cypher1359` de **transférer** ses créations (pas de transfert d'asset entre comptes
   sur Roblox à ce jour : republication obligatoire) ; ou passer l'expérience et les assets dans un
   **groupe** commun (le propriétaire cible devient alors le groupe, à republier aussi).
2. **Lot pilote** (accordé le 23/10, **préparé**) : `ReplicatedStorage.Assets.Combat` (62
   identifiants : Écuyer du Rempart, Gobelin, Roi Orc, Slime). Inventaire et procédure :
   `REPUBLICATION_LOT_PILOTE.md` ; remplacement : `tools/studio-replace-asset-ids.luau`.
3. **Héros** : même procédure pour les 60 modèles de `ServerStorage.Assets.Heros` (1 060
   identifiants avec l'Écuyer), par lots de 5 à 10 héros, en recopiant les nouveaux identifiants dans la copie
   `Workspace.Bestiaire.Heros` si elle doit rester alignée.
4. **Royaume** : `RoyaumeEtats` (574), `Royaume` (12), `Lobby.Plots` (82), `VitrineRoyaumes`
   (323), `GrandArbre` (2) ; les copies dans `PlotsZones`, `PlotTravail` et `PortailInvocation`
   se mettent à jour par le même remplacement (chercher l'ancien identifiant dans toute la place).
5. **Animations** : publier les `KeyframeSequence` de combat depuis la session de `nxtoma`
   (Animation Editor), renseigner leur attribut `AssetId` (`ANIMATION_TOOLS.md`).
6. **Modération** : remplacer ou republier le mesh `108856662437506` de `GargouilleDormeuse`
   (refusé) ; trouver l'origine de `203785492` (mauvais type d'asset).
7. **Tiers à arbitrer** : ciel (`Lighting.Sky`), texture de la baseplate, mannequins R15 de
   `Assets.Combat` (provisoires, à remplacer par les modèles du jeu plutôt qu'à republier).
8. **Contrôle final** : `tools/studio-check-asset-ownership.luau` sur chaque conteneur du jeu
   (0 FIX), Play dans la place DEV sans erreur d'asset dans la console, capture de chaque écran
   touché ; mettre à jour ce fichier (colonne « Nouvel AssetId » et contrôle).
