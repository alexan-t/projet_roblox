# Plan d'intégration des assets du collaborateur (non exécuté)

Préparé le 02/11/2026 d'après [`ASSETS_COLLABORATEUR_AUDIT.md`](ASSETS_COLLABORATEUR_AUDIT.md) et
[`ASSETS_COLLABORATEUR_INVENTAIRE.md`](ASSETS_COLLABORATEUR_INVENTAIRE.md). **Rien n'est lancé.**
Chaque lot attend l'accord explicite de l'utilisateur, et chaque publication sous `nxtoma` suit
`ASSET_OWNERSHIP.md` § 6.

## 1. Classement

| Cat. | Définition | Contenu |
|---|---|---|
| **A** — réutilisable | présent, propriétaire compatible, références correctes | 62 assets du lot pilote (`Heros_EcuyerDuRempart`, `Ennemi_Gobelin`, `Ennemi_Slime`, `Ennemi_RoiOrc`) ; décor `Zone1_PlaineDuRoyaume` (0 AssetId) ; code de #103 |
| **B** — intégration Studio | absent de DEV, sans problème de propriété identifié | 5 décors `ZonesArene.Zone2..6` (outil Git, aucun AssetId) ; pancartes ; code de #100 et #104–#106 |
| **C** — propriété à régulariser | référence `cypher1359` ou tiers | 712 AssetIds `cypher1359` déjà dans DEV (38 monstres sources → 38 `Ennemi_*`, `PlotsZones`) ; ~1 042 AssetIds des héros (lots `lot-heros-01..08`) ; 72 séquences à publier sous `nxtoma` |
| **D** — bloqué ou inconnu | données manquantes, permissions | tout objet propre à test 3 (59 `Heros_<Modèle>`, 72 séquences, valeurs `EffetUltime`) ; modération des 817 ; 43 assets tiers des mannequins R15 |

## 2. Préalables (une fois)

1. **Ouvrir test 3 dans Studio (session de `cypher1359`) et relancer l'inventaire en lecture
   seule** : même script que pour DEV, sur `ReplicatedStorage.Assets.Combat`,
   `ReplicatedStorage.Assets.Animations`, `ServerStorage.RBX_ANIMSAVES`, `ServerStorage.Assets`.
   Ce relevé fait passer les objets D en B ou C. Sans lui, aucun import.
2. Fusionner la PR #110 (registre `published-registry.json`, `rollback.json`, commande `plan`),
   pour réutiliser les assets déjà publiés et garder les associations d'origine.
3. Synchroniser `develop` dans DEV (Rojo), y compris le store de recette (`StoreRecette`).
4. Décider du sort des mannequins R15 (43 assets tiers) : après #104, aucun héros ne les utilise.

## 3. Contrôles communs à chaque lot

| Étape | Contenu |
|---|---|
| Snapshot | **Avant** le lot : *Fichier → Enregistrer dans un fichier* de la place DEV (`studio/backups/DEV_<date>_<lot>.rbxl`, hors Git), plus une version de place sur Roblox (historique des versions). Ctrl+Z n'est qu'un filet de dernier recours. |
| Références | `tools/studio-check-asset-ownership.luau` avec `ROOTS` = objets du lot : 0 `FIX` attendu (ou FIX connus et listés). Contrôle des attributs requis (`HauteurPieds`, `EffetUltime`, `JeuAnimations`, `Impact`). |
| Recette | Play dans DEV **sur un store de recette** (`SECURITY.md` § Recettes Studio), jamais `PlayerData_Studio` ; console sans « not authorized » ni « not approved » ; captures ; `VISUAL_QA.md` PASS ; caméra réinitialisée. |
| Retour arrière | Code : `git revert` de la fusion. Studio : rouvrir le snapshot `.rbxl` ou restaurer la version de place. Identifiants : `rollback.json` du lot (nouveau → ancien) avec `tools/studio-replace-asset-ids.luau`. Aucun asset Roblox n'est supprimé. |
| Inventaire | Ancien et nouvel AssetId, propriétaire, résultat ; mapping commité ; une étape `ChangeHistoryService`. |

## 4. Ordre recommandé

### Lot 0 — code seul (sans Studio)
Fusionner #103 (documentation). Préparer une branche d'intégration `develop` + #104 → #105 → #106
avec résolution du conflit `ArenaService.lua` (garder `progressOf` / `objectiveOf` / `chosenOf` de
`develop` **et** le paramètre `fallbackHeroId` de #104). Rejouer `test-heroes`, `test-arena`,
`test-presentation` (Luau CLI requis). Sans les modèles dans DEV, le repli montre les vrais
modèles des héros : fusion possible, sans régression visible.

### Lot 1 — modèles et animations des héros du jeu actuel
Héros de départ et premiers obtenus : Écuyer (déjà A), Tireuse des Faubourgs, puis les héros de
`lot-heros-01`.
- Export `.rbxm` depuis test 3 (par le collaborateur) : `Heros_<Modèle>`, jeux `Animations.<Modèle>`,
  `Squelette_Leger`. Import dans DEV par l'utilisateur, dans un dossier de quarantaine
  (`ServerStorage.Import_<date>`), **jamais** directement à la place de `Heros_EcuyerDuRempart`.
- Régularisation : republication du lot héros correspondant (meshes et textures, voie C) ;
  publication des séquences sous `nxtoma` (Animation Editor ou Open Cloud) et pose de l'attribut
  `AssetId`.
- Recette : combat 1-1 avec chaque héros du lot, attaque visible hors Studio (serveur de test de
  l'expérience), pas seulement en Play Studio.

### Lot 2 — ultimes Communs (#104 : #01, #02)
#01 : ne garder du modèle de test 3 que l'attribut `EffetUltime` et la séquence `Ultime`
« Rempart Fermé » ; le modèle `nxtoma` reste. #02 : modèle du lot 1 + `EffetUltime` + `Ultime`.

### Lot 3 — ultimes Peu communs (#105 : #03 à #06)
Après le lot 2. À arbitrer avant : #06 sans cor (geste et ondes).

### Lot 4 — ultimes Rares (#106 : #07 à #12)
Après le lot 3. À arbitrer : #08 (lanterne en main gauche), #12 (pas de déplacement).
#09 : vérifier que le faucon est bien dans le modèle importé.

### Lot 5 — décors de la Zone 2 (#100)
Fusion de #100, puis `tools/studio-zones-assets.luau` **dans DEV** (procédural, une étape Ctrl+Z,
snapshot avant). Il crée aussi les `Ennemi_*` : leurs AssetIds sont ceux des monstres sources
(`cypher1359`) → republication des monstres de la Zone 2 (VaseDesSables, ChacalParchemin,
ScarabeeForgeSoleil, MangeDune, GardienSansVisage, ColosseEnseveli : 54 AssetIds) **avant** la
validation finale. Recette : stages 2-1 à 2-5, repères `SourcesEnnemis`, limites de l'arène,
collisions, boss sur 2-5, capture à comparer à `zone2-sables-*.jpg`.

### Lot 6 — zones 3 à 6
Même outil, déjà joué au lot 5 pour toutes les zones ; recette et republication zone par zone.
À traiter en même temps : les 8 `Ennemi_*` que `develop` attend déjà (KingSlime, KingTreant,
Treant…) et `PlotsZones` (252 AssetIds `cypher1359`, vitrine à remplacer par celle de
`studio-zones-vitrine.luau` ou à republier).

## 5. Risques

| Risque | Parade |
|---|---|
| Import de test 3 qui écrase un modèle `nxtoma` | quarantaine, comparaison des AssetIds avant de déplacer |
| Deux objets de même nom, contenu différent | comparer descendants, attributs et AssetIds, jamais le nom seul |
| Animations jouées en Studio mais pas en ligne | `AssetId` obligatoire avant de valider ; recette sur un serveur de l'expérience |
| Assets `cypher1359` refusés hors de sa session | contrôle console en Play DEV ; republication du lot concerné |
| Conflit `ArenaService` mal résolu | tests `test-arena` et combat réel 1-1, 1-5, 2-1 |
| Perte des associations d'origine | `published-registry.json` (déduplication par ancien id puis SHA-256) et `rollback.json` commités à chaque lot |

## 6. Décisions attendues de l'utilisateur

1. Ouvrir test 3 (ou demander au collaborateur un export `.rbxm`) pour l'inventaire réel.
2. Feu vert pour le lot 0 (code), puis lot par lot pour les imports et les republications.
3. Mannequins R15 : retirer, archiver ou garder.
4. Arbitrages de gameplay de #105 et #106 (#06, #08, #12).
