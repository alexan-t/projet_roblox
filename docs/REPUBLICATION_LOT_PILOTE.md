# Republication — lot pilote `ReplicatedStorage.Assets.Combat`

Premier lot de `ASSET_OWNERSHIP_AUDIT.md` (opération 2), accordé par l'utilisateur le 23/10/2026.
Périmètre : les 4 modèles de combat à la DA du jeu, **62 AssetIds** (31 meshes + 31 textures), tous
publiés par `cypher1359`. Propriétaire cible : `nxtoma` (User `11714751172`). Les mannequins R15 de
`Assets.Combat` sont hors lot (provisoires, à remplacer plutôt qu'à republier).

État : **préparé, rien de publié ni de remplacé.**

## Ce qui a été vérifié dans la place DEV (session de `nxtoma`)

- Les 4 modèles ne contiennent que des `MeshPart` (45 pièces, 31 meshes distincts) : pas de
  `SurfaceAppearance`, de `Decal` ni de `SpecialMesh` à republier. Leurs animations ne sont pas
  publiées (`AnimationController` + `KeyframeSequence` locales, opération 5 de l'audit).
- `MeshPart.MeshId` n'est pas modifiable par script ; `AssetService:CreateMeshPartAsync` +
  `MeshPart:ApplyMesh` fonctionnent (taille, CFrame, matériau, fidélités et transparence conservés).
  `TextureID` se modifie directement. Testé sur une copie hors place.
- Les 62 identifiants servent aussi ailleurs (1 067 propriétés au total) : copies de travail
  (`Workspace.AtelierAnimation`, `Workspace.Gobelin`, `Workspace.RoiOrc`, slimes), le Bestiaire,
  les archives et `Workspace.Treant_Arbre`, qui réutilise 249 fois la feuille du slime. Le
  remplacement se fait donc sur toute la place, pour que les copies restent identiques.
- La session de `nxtoma` peut lire la géométrie et les pixels de ces assets
  (`CreateEditableMeshAsync` / `CreateEditableImageAsync` réussissent).

## Procédure

### 1. Publier sous `nxtoma` (au choix)

**Voie A — depuis Studio, sans fichier (à essayer sur un seul asset d'abord).** Dans la session
Studio de `nxtoma`, lire le mesh ou la texture (`CreateEditableMeshAsync` / `CreateEditableImageAsync`)
puis le publier avec `AssetService:CreateAssetAsync` (Mesh / Image) : l'asset créé appartient à la
session. **Essayée le 23/10/2026 sur la texture n°44 (`107504521703864`) : échec.** La lecture
réussit (image 1024 × 1024), mais `CreateAssetAsync` répond « CreateAssetAsync and
CreateAssetVersionAsync are not available yet ». Rien n'a été publié. Voie A fermée tant que Roblox
n'ouvre pas cette API : passer par la voie B.

**Voie B — export puis import, par l'utilisateur (`nxtoma`).**
1. Studio, session `nxtoma`. Pour chaque pièce du tableau : la sélectionner dans
   `ReplicatedStorage.Assets.Combat`, clic droit → **Exporter la sélection** (`.obj` + texture).
   Nommer le fichier d'après la pièce (ex. `Gobelin_right_arm`).
2. **Gestionnaire d'assets → Importer** (ou *Fichier → Importer 3D*) : importer les fichiers
   exportés. Les meshes et images créés appartiennent à `nxtoma`.
3. Copier chaque nouvel identifiant dans la colonne « Nouvel AssetId » du tableau.

Ne jamais transmettre de mot de passe ni de cookie : tout se fait dans la session de `nxtoma`.

### 2. Vérifier les nouveaux assets

`tools/studio-check-asset-ownership.luau` ne sait contrôler que des identifiants déjà posés ; avant
le remplacement, vérifier sur le Creator Hub que chaque nouvel asset est **Approved** (modération)
et appartient à `nxtoma`.

### 3. Remplacer les identifiants

1. Ouvrir `tools/studio-replace-asset-ids.luau`, remplir `MAPPING` avec les 62 paires
   `["ancien"] = "nouveau"` du tableau.
2. Le lancer dans la barre de commande avec `DRY_RUN = true` : il doit annoncer environ 1 067
   propriétés et 0 identifiant introuvable.
3. Le relancer avec `DRY_RUN = false` : une seule étape Ctrl+Z, place **non sauvegardée**.

### 4. Contrôler (avant d'enregistrer la place)

1. `tools/studio-check-asset-ownership.luau` avec `ROOTS = { game.ReplicatedStorage.Assets.Combat }` :
   les 62 lignes doivent passer à `OK` (seuls les mannequins R15 restent en tiers).
2. Play dans la place DEV : un combat avec l'Écuyer contre Gobelin, Slime et le Roi Orc (stages 1-1
   et 1-5) ; console sans « not authorized » ni « not approved » ; captures, `VISUAL_QA.md` : PASS.
3. Réinitialiser la caméra après les captures (`MONSTER_PRODUCTION.md`, Outils § A).
4. Reporter les nouveaux identifiants et le contrôle dans le tableau ci-dessous, puis enregistrer.

En cas de problème : Ctrl+Z (une étape) ou rouvrir la place sans enregistrer. Les anciens assets
restent en place sur Roblox : rien n'est supprimé.

## Inventaire du lot

« Autres usages » = nombre de propriétés hors `Assets.Combat` qui citent le même identifiant.

| # | Pièce (`ReplicatedStorage.Assets.Combat.`…) | Type | Ancien AssetId | Nouvel AssetId | Propriétaire | Autres usages | Contrôle |
|---|---|---|---|---|---|---|---|
| 1 | `Ennemi_Gobelin.right_arm.right_arm_geom` | Mesh | `101545816385322` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 2 | `Ennemi_Gobelin.right_arm.right_arm_geom` | Image (texture) | `94160075609716` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 3 | `Ennemi_Gobelin.torso.torso_geom` | Mesh | `126354225080629` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 4 | `Ennemi_Gobelin.torso.torso_geom` | Image (texture) | `133350402446247` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 5 | `Ennemi_Gobelin.spear.spear_geom` | Mesh | `96195836243902` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 6 | `Ennemi_Gobelin.spear.spear_geom` | Image (texture) | `132575861009692` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 7 | `Ennemi_Gobelin.left_arm.left_arm_geom` | Mesh | `113521611304500` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 8 | `Ennemi_Gobelin.left_arm.left_arm_geom` | Image (texture) | `137672384215371` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 9 | `Ennemi_Gobelin.left_leg.left_leg_geom` | Mesh | `110303809370235` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 10 | `Ennemi_Gobelin.left_leg.left_leg_geom` | Image (texture) | `127187795674374` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 11 | `Ennemi_Gobelin.right_leg.right_leg_geom` | Mesh | `93120410964817` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 12 | `Ennemi_Gobelin.right_leg.right_leg_geom` | Image (texture) | `91750919684836` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 13 | `Ennemi_Gobelin.shield.shield_geom` | Mesh | `76677295940265` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 14 | `Ennemi_Gobelin.shield.shield_geom` | Image (texture) | `103378694748388` | — | cypher1359 | 4 | FIX-PROPRIETAIRE |
| 15 | `Ennemi_Gobelin.head.head_geom` | Mesh | `78939162400478` | — | cypher1359 | 3 | FIX-PROPRIETAIRE |
| 16 | `Ennemi_Gobelin.head.head_geom` | Image (texture) | `86492434726784` | — | cypher1359 | 3 | FIX-PROPRIETAIRE |
| 17 | `Ennemi_RoiOrc.torso.torso_geom` | Mesh | `103169819371473` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 18 | `Ennemi_RoiOrc.torso.torso_geom` | Image (texture) | `89047233881409` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 19 | `Ennemi_RoiOrc.left_arm.left_arm_geom` | Mesh | `112642946362491` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 20 | `Ennemi_RoiOrc.left_arm.left_arm_geom` | Image (texture) | `71021063966201` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 21 | `Ennemi_RoiOrc.right_leg.right_leg_geom` | Mesh | `120345676747662` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 22 | `Ennemi_RoiOrc.right_leg.right_leg_geom` | Image (texture) | `104127734950939` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 23 | `Ennemi_RoiOrc.equipement.PicEpaule (×6)` | Mesh | `76920860898675` | — | cypher1359 | 36 | FIX-PROPRIETAIRE |
| 24 | `Ennemi_RoiOrc.equipement.PicEpaule (×6)` | Image (texture) | `106173864750963` | — | cypher1359 | 36 | FIX-PROPRIETAIRE |
| 25 | `Ennemi_RoiOrc.equipement.Banniere` | Mesh | `77672111260396` | — | cypher1359 | 6 | FIX-PROPRIETAIRE |
| 26 | `Ennemi_RoiOrc.equipement.Banniere` | Image (texture) | `127067342414177` | — | cypher1359 | 6 | FIX-PROPRIETAIRE |
| 27 | `Ennemi_RoiOrc.equipement.Crane_* (×6)` | Mesh | `128823418999050` | — | cypher1359 | 31 | FIX-PROPRIETAIRE |
| 28 | `Ennemi_RoiOrc.equipement.Crane_* (×6)` | Image (texture) | `137802160115556` | — | cypher1359 | 31 | FIX-PROPRIETAIRE |
| 29 | `Ennemi_RoiOrc.equipement.Bouclier` | Mesh | `103134695447206` | — | cypher1359 | 6 | FIX-PROPRIETAIRE |
| 30 | `Ennemi_RoiOrc.equipement.Bouclier` | Image (texture) | `109779900654607` | — | cypher1359 | 6 | FIX-PROPRIETAIRE |
| 31 | `Ennemi_RoiOrc.equipement.LanceHache` | Mesh | `92918638208135` | — | cypher1359 | 6 | FIX-PROPRIETAIRE |
| 32 | `Ennemi_RoiOrc.equipement.LanceHache` | Image (texture) | `110216625447839` | — | cypher1359 | 6 | FIX-PROPRIETAIRE |
| 33 | `Ennemi_RoiOrc.right_arm.right_arm_geom` | Mesh | `88212818943279` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 34 | `Ennemi_RoiOrc.right_arm.right_arm_geom` | Image (texture) | `132415709293143` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 35 | `Ennemi_RoiOrc.left_leg.left_leg_geom` | Mesh | `88564351715228` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 36 | `Ennemi_RoiOrc.left_leg.left_leg_geom` | Image (texture) | `107838959573949` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 37 | `Ennemi_RoiOrc.head_with_crown.body.body_geom` | Mesh | `74928021945535` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 38 | `Ennemi_RoiOrc.head_with_crown.body.body_geom` | Image (texture) | `90913400970426` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 39 | `Ennemi_Slime.eyes.eyes_geom` | Mesh | `129245853106269` | — | cypher1359 | 9 | FIX-PROPRIETAIRE |
| 40 | `Ennemi_Slime.eyes.eyes_geom` | Image (texture) | `94292621457911` | — | cypher1359 | 9 | FIX-PROPRIETAIRE |
| 41 | `Ennemi_Slime.leaves.leaf_* (×5)` | Mesh | `113765157023718` | — | cypher1359 | 373 | FIX-PROPRIETAIRE |
| 42 | `Ennemi_Slime.leaves.leaf_* (×5)` | Image (texture) | `133088852825329` | — | cypher1359 | 193 | FIX-PROPRIETAIRE |
| 43 | `Ennemi_Slime.body.body_geom` | Mesh | `98155401096105` | — | cypher1359 | 9 | FIX-PROPRIETAIRE |
| 44 | `Ennemi_Slime.body.body_geom` | Image (texture) | `107504521703864` | — | cypher1359 | 2 | FIX-PROPRIETAIRE |
| 45 | `Heros_EcuyerDuRempart.right_leg.right_leg_geom` | Mesh | `97234781530135` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 46 | `Heros_EcuyerDuRempart.right_leg.right_leg_geom` | Image (texture) | `93433962987135` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 47 | `Heros_EcuyerDuRempart.torso.torso_geom` | Mesh | `129637362589534` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 48 | `Heros_EcuyerDuRempart.torso.torso_geom` | Image (texture) | `89548083677613` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 49 | `Heros_EcuyerDuRempart.short_sword.short_sword_geom` | Mesh | `75240985056567` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 50 | `Heros_EcuyerDuRempart.short_sword.short_sword_geom` | Image (texture) | `120503126450909` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 51 | `Heros_EcuyerDuRempart.equipement.cor_geom` | Mesh | `95365998598761` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 52 | `Heros_EcuyerDuRempart.equipement.cor_geom` | Image (texture) | `71818071718386` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 53 | `Heros_EcuyerDuRempart.left_arm.left_arm_geom` | Mesh | `81109617321251` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 54 | `Heros_EcuyerDuRempart.left_arm.left_arm_geom` | Image (texture) | `139280197908279` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 55 | `Heros_EcuyerDuRempart.head.head_geom` | Mesh | `122530650491358` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 56 | `Heros_EcuyerDuRempart.head.head_geom` | Image (texture) | `126970221416552` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 57 | `Heros_EcuyerDuRempart.shield.shield_geom` | Mesh | `97369384895028` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 58 | `Heros_EcuyerDuRempart.shield.shield_geom` | Image (texture) | `98599059173902` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 59 | `Heros_EcuyerDuRempart.right_arm.right_arm_geom` | Mesh | `70497795151957` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 60 | `Heros_EcuyerDuRempart.right_arm.right_arm_geom` | Image (texture) | `104195334166006` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 61 | `Heros_EcuyerDuRempart.left_leg.left_leg_geom` | Mesh | `92317308860182` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
| 62 | `Heros_EcuyerDuRempart.left_leg.left_leg_geom` | Image (texture) | `75603117733240` | — | cypher1359 | 5 | FIX-PROPRIETAIRE |
