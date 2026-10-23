# Propriété des assets Roblox — règle obligatoire

Règle permanente, valable pour toute fonctionnalité, tout asset et toute PR. Elle s'ajoute aux
contrôles visuels (`VISUAL_QA.md`) : un rendu PASS avec un asset mal possédé reste un **FIX**.

## 1. Propriétaire cible

- L'expérience appartient au compte **`nxtoma`** (User `11714751172`), universe `10767916745`,
  place DEV « Projet Roblox - Alpha » (placeId `78875801703886`). Vérifié dans Studio :
  `game.CreatorType = User`, `game.CreatorId = 11714751172`.
- Si l'expérience passe un jour dans un groupe, le propriétaire cible devient **ce groupe** :
  relire `game.CreatorType` / `game.CreatorId` au lieu de supposer.
- Ne jamais écrire en dur un propriétaire ailleurs que dans ce paragraphe : les outils lisent
  `game.CreatorId`.

## 2. La règle

1. Tous les assets **définitifs** du projet (images, icônes, decals, textures, meshes,
   `SurfaceAppearance`, animations, sons, modèles, packages) appartiennent au propriétaire de
   l'expérience (compte ou groupe).
2. Un asset publié sous le compte personnel d'un collaborateur (ex. `cypher1359`) **n'est pas
   intégré** au jeu, même s'il s'affiche dans sa session Studio.
3. Le collaborateur peut créer et tester ses assets sous son compte ; avant la validation finale,
   ils sont publiés sous le bon propriétaire.
4. Sans droit de publier sous le propriétaire cible, il prépare les **fichiers sources** (PNG,
   FBX/OBJ, `.rbxm`, `KeyframeSequence`) et des **instructions** pour que le propriétaire publie
   depuis sa propre session Roblox Studio. Il ne demande **jamais** d'identifiants.
5. Après republication, remplacer les anciens AssetIds par les nouveaux **partout** : configs
   (`src/shared/Config`), catalogues et revues (`automation/`), modèles Studio, textures, meshes,
   `SurfaceAppearance`, animations (attribut `AssetId` des `KeyframeSequence`), sons, icônes, docs.
6. Vérifier les **dépendances internes** : republier un modèle ne change pas le propriétaire de
   ses meshes, textures et `SurfaceAppearance`. Chaque identifiant interne se contrôle séparément.
7. Tester le chargement dans **l'expérience propriétaire réelle** (place DEV, session du
   propriétaire ou serveur Play de cette place), pas seulement dans la session du collaborateur.
8. Vérifier les **permissions** Roblox (Creator Hub → asset → Permissions) et le **statut de
   modération** (un asset en attente ou refusé s'affiche vide ou gris).
9. Tenir l'**inventaire** des assets concernés (format § 5).
10. Propriété ou permissions incorrectes → **blocage signalé avant le merge** (verdict FIX dans
    la PR, avec la liste des opérations restantes).

### Exceptions admises (à lister dans l'inventaire)

- **Audio sous licence Roblox** (Creator Store, comptes officiels `APMOfficial`,
  `ProSoundEffects`, `Roblox`) : non republiables, utilisables par toutes les expériences.
  Statut `TIERS-LICENCE`, pas de blocage.
- **Assets temporaires d'atelier** (`Workspace.AtelierAnimation`, `Workspace.AtelierIcones`,
  `ServerStorage.Archive_*`, variantes non retenues) : hors jeu, ils ne bloquent pas un merge.
  Ils doivent être republiés s'ils deviennent définitifs (sortie d'archive, copie en combat).

Tout autre asset d'un tiers est un **FIX** tant que l'utilisateur ne l'a pas explicitement accepté.

## 3. Quand le contrôle s'applique

- Toute PR qui ajoute ou modifie un AssetId dans `src/`, `automation/` ou `docs/`.
- Tout modèle, icône, animation, son, texture ou mesh validé dans Studio (monstre, boss, héros,
  décor, royaume, zone, UI), y compris les modèles construits avec `generate_mesh`,
  `generate_texture`, `generate_material` ou `upload_image` : ces outils publient **sous le compte
  de la session Studio** qui les appelle.
- Tout import Toolbox / Creator Store.

## 4. Procédure de contrôle

1. Dans la place DEV, en Edit, exécuter `tools/studio-check-asset-ownership.luau` (lecture seule).
   Il relève les AssetIds des configs (`ReplicatedStorage.Shared.Config`) et des instances
   Studio (meshes, textures, images, sons, animations…) et interroge
   `MarketplaceService:GetProductInfo` (champ `Creator`). Statuts : `OK`, `TIERS-LICENCE`,
   `FIX-PROPRIETAIRE`, `ERREUR`. Le paramètre `ROOTS` limite le contrôle à un modèle précis.
2. Contrôler le chargement en Play dans la place DEV : capture réelle de l'écran concerné, et
   console sans `User is not authorized to access Asset`, `Asset is not approved for the
   requester` ni `Failed to load`. Ne pas se fier à `ContentProvider:PreloadAsync` sur un
   identifiant : il renvoie `Failure` même pour des images qui s'affichent (constaté le 23/10/2026).
3. Ouvrir sur le Creator Hub les assets nouveaux : statut de modération « Approved »,
   permissions de l'expérience correctes.
4. Reporter le résultat dans l'inventaire et dans la PR (case « Propriété des assets »).

## 5. Inventaire

Un tableau par lot, dans la doc de la fonctionnalité ou dans la PR :

| Nom | Type | Ancien AssetId | Nouvel AssetId | Propriétaire | Contrôle |
|---|---|---|---|---|---|
| `item_001.png` | Image | `123…` (cypher1359) | `456…` | nxtoma | OK — chargé en Play DEV |

Contrôle = `OK`, `TIERS-LICENCE`, ou `FIX` + raison (propriétaire, permission, modération,
chargement). Le dernier audit complet est dans `ASSET_OWNERSHIP_AUDIT.md`.

## 6. Republication (par le propriétaire ou un compte autorisé)

1. Limiter la liste aux seuls assets `FIX-PROPRIETAIRE` effectivement utilisés par le jeu.
2. Pour chaque asset : republier depuis la source (PNG du dépôt, `.rbxm`, Animation Editor) sous
   le propriétaire cible ; noter l'ancien et le nouvel AssetId dans l'inventaire.
3. Remplacer les références : configs dans une branche `feature/*` (PR vers `develop`), instances
   Studio avec `tools/studio-replace-asset-ids.luau` (essai `DRY_RUN`, puis une étape Ctrl+Z) ; rechercher l'ancien identifiant dans tout le
   dépôt (`git grep <ancien>`) et dans Studio avant de conclure.
4. Relancer `tools/studio-check-asset-ownership.luau` : zéro `FIX` sur le périmètre.
5. Ne rien supprimer côté Roblox (les anciens assets restent en place jusqu'au merge).

Interdits sans accord explicite de l'utilisateur : republication en masse, changement de
permissions, remplacement d'identifiants avant confirmation du propriétaire cible et des accès,
publication de l'expérience en production.
