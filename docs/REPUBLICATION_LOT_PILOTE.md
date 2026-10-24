# Republication — lot pilote `ReplicatedStorage.Assets.Combat`

Premier lot de `ASSET_OWNERSHIP_AUDIT.md` (opération 2), accordé par l'utilisateur le 23/10/2026.
Périmètre : les 4 modèles de combat à la DA du jeu, **62 AssetIds** (31 meshes + 31 textures), tous
publiés par `cypher1359`. Propriétaire cible : `nxtoma` (User `11714751172`). Les mannequins R15 de
`Assets.Combat` sont hors lot (provisoires, à remplacer plutôt qu'à republier).

État : voie C (Open Cloud). Lecture des 62 réussie ; **62/62 publiés sous nxtoma et approuvés** (24/10) ; **rien remplacé dans Studio**.

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
n'ouvre pas cette API.

**Voie C — Open Cloud, outil local (recommandée, à valider sur le n°44).** Détail : § Voie C plus bas.
Télécharger le fichier d'origine de chaque asset (Asset Delivery), le contrôler, le republier sous
`nxtoma` (Assets API) et produire le `MAPPING`, sans manipulation par asset.

**Voie B — export puis import, par l'utilisateur (`nxtoma`).** Repli si la voie C est refusée.
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

## Voie C — Open Cloud (étude du 23/10/2026)

### Verdict : faisable — lecture du n°44 réussie le 24/10/2026

Avec la clé `RepublicationAssets` de `nxtoma` (Assets lecture + écriture, Legacy Assets
`legacy-asset:manage`), `download --only 107504521703864` récupère l'original de l'asset de
`cypher1359` : PNG 1024 × 1024, RGBA 8 bits, 868 756 octets, SHA-256 `16dfb87f…ddc5f`, structure
PNG complète ; c'est bien la texture bleue du corps du slime (même taille que dans Studio). Aucune
publication. Points appris : une clé sans autorisations répond 403 « Scope not authorized »
(Asset Delivery) et « User not authenticated » (Assets) ; vérifier que la colonne « Mis à jour »
de la clé a changé après l'ajout des autorisations.

**Lecture des 62 (24/10/2026) : 62/62 téléchargés, aucun refus d'accès, aucune publication.**
- 31 meshes : format Roblox binaire `version 2.00` (celui qu'accepte l'Assets API pour un mesh
  issu d'Asset Delivery), taille de chaque fichier cohérente avec son en-tête (sommets et faces),
  69 937 triangles au total, de 18 à 319 Ko.
- 31 textures : PNG 1024 × 1024, de 0,8 à 1,6 Mo, structure complète (IHDR, IDAT, IEND). Douze
  d'entre elles portent 1 à 3 espaces après la fin de l'image (`IEND`), sans effet sur l'image :
  fichiers gardés tels quels.
- Aucun doublon de contenu (62 empreintes SHA-256 distinctes), 39,4 Mo au total, rien au-dessus
  de la limite de 20 Mo ; la clé n'apparaît ni dans le journal ni dans `state.json`.

**Exemplaire pilote publié (24/10/2026), avec l'accord de l'utilisateur : n°44 seul.**
`107504521703864` → **`119239276286265`**, nom `lot-pilote-combat_44_body_body_geom`. Opération
terminée en une lecture ; l'Assets API relit le propriétaire `11714751172` (`nxtoma`) et
`GetProductInfo` dans Studio le confirme (User `nxtoma`, type Image). Modération : `Approved` —
l'API renvoie cette valeur et non `MODERATION_STATE_APPROVED` comme l'indique sa doc ; l'outil
accepte les deux. Contenu : dans Studio, les deux images lues par `EditableImage` sont
**identiques au pixel près** (0 octet différent sur 4 194 304). Rien n'a été remplacé dans la place.

**Mesh pilote publié (24/10/2026), avec l'accord de l'utilisateur : n°43 seul.**
`98155401096105` → **`74639917575152`** : l'Assets API accepte bien le mesh `version 2.00` issu
d'Asset Delivery (`model/x-file-mesh-data`). Propriétaire `nxtoma` (API et `GetProductInfo`, type
Mesh), modération `Approved`. Géométrie comparée dans Studio par `EditableMesh` : 3 146 sommets et
5 398 faces des deux côtés, **écart nul** sur les positions et les UV, même `MeshSize`. Rien n'a été
remplacé dans la place. Les deux types du lot (Image, Mesh) sont donc validés de bout en bout.

**Lot complet publié (24/10/2026), avec l'accord de l'utilisateur : 60 restants, 62/62.**
`publish --limit 62` : 60 publiés, 0 échec, tous au propriétaire `nxtoma`. Vingt textures sont
d'abord revenues « Reviewing » ; `refresh` (relecture avec `readMask=moderationResult`) les donne
toutes `Approved` quelques minutes plus tard. Contrôle dans Studio, en lecture seule, des 62 paires :
propriétaire `nxtoma` (`GetProductInfo`), bon type (Mesh / Image), contenu **identique** à
l'original (pixels pour les textures ; sommets, faces, positions et UV pour les meshes) : **62/62**.
Mapping : `automation/republication/lot-pilote-combat.mapping.json` (62 paires, nouveaux
identifiants tous distincts) ; le bloc `MAPPING` prêt à coller est produit par
`node tools/republish-assets.mjs mapping …` dans `build/republication/lot-pilote-combat/mapping.luau`.
**Rien n'a été remplacé dans la place.** Prochaine étape : § 3 de la procédure (`DRY_RUN` d'abord).

La voie est prévue par Roblox : l'Assets API accepte un mesh « uniquement s'il a été téléchargé par
l'Asset Delivery API » et renvoie vers l'Importer « si vous n'essayez pas de télécharger puis
republier des meshes ». Les images se republient directement (PNG/JPEG). L'outil
`tools/republish-assets.mjs` fait tout le circuit ; il est testé contre un faux Roblox
(`tests/republish-assets.test.mjs`). Le seul point que la documentation ne tranche pas est le
droit de **télécharger un asset de `cypher1359`** avec une clé de `nxtoma` (voir plus bas) : c'est
ce que le test du n°44 établit.

### Endpoints officiels

| Étape | Endpoint | Scope | Quota |
|---|---|---|---|
| Télécharger l'original | `GET apis.roblox.com/asset-delivery-api/v1/assetId/{id}` → `location` (URL CDN temporaire, gzip possible) | `legacy-asset:manage` (clé d'un **compte**, pas de groupe) | 1 000/min |
| Publier | `POST apis.roblox.com/assets/v1/assets` (multipart : `request` JSON + `fileContent`) | `asset:read` + `asset:write` | 120/min |
| Suivre la publication | `GET apis.roblox.com/assets/v1/operations/{operationId}` (`done`, `response.assetId`, `moderationResult`) | `asset:read` | 300/min |
| Vérifier le propriétaire | `GET apis.roblox.com/assets/v1/assets/{id}` (`creationContext.creator`) | `asset:read` | 120/min |
| (Repli) Partager des assets | `PATCH apis.roblox.com/asset-permissions-api/v1/assets/permissions` (bêta, par lot) | `asset-permissions:write` | 100/min |

Limites : un asset par appel, 20 Mo, images < 8000 px ; Image et Mesh ne se mettent pas à jour
(chaque publication crée un nouvel identifiant) ; pas d'endpoint de lot pour le téléchargement.
Sans clé, les deux endpoints répondent 403 (vérifié). Sources :
[usage-assets](https://create.roblox.com/docs/cloud/guides/usage-assets),
[référence Assets](https://create.roblox.com/docs/en-us/cloud/reference/features/assets.md),
[Asset Delivery](https://create.roblox.com/docs/cloud/reference/domains/assetdelivery.md),
[confidentialité des assets](https://create.roblox.com/docs/en-us/projects/assets/privacy).

### Droit de lire les assets de `cypher1359`

- Roblox ne documente pas le contrôle d'accès d'Asset Delivery. Les images et meshes sont en
  « Open Use » par défaut, sauf si leur créateur a activé la confidentialité des assets (« Restricted ») ;
  un asset restreint ne se charge que pour les comptes ou expériences autorisés.
- Indice favorable : dans la session Studio de `nxtoma`, `CreateEditableMeshAsync` et
  `CreateEditableImageAsync` lisent ces assets (ils exigent pourtant un droit d'usage).
- Si le téléchargement répond 401/403/404 pour un identifiant valide, l'accès est refusé : passer
  au repli ci-dessous. Aucun cookie de session ni API privée.

### Ce que l'utilisateur (`nxtoma`) doit faire

1. **Créer la clé** : Creator Hub → Open Cloud → Clés API → *Créer une clé*, propriétaire `nxtoma`
   (compte personnel). Autorisations : *Assets* (lecture + écriture) et *Legacy Assets*
   (`legacy-asset:manage`). Restreindre à son adresse IP et mettre une expiration courte (7 jours).
2. **La rendre disponible localement, hors Git** : soit
   `$env:ROBLOX_OPEN_CLOUD_KEY = '<clé>'` dans le terminal où l'outil tourne, soit un fichier hors du
   dépôt (ex. `C:\Users\<toi>\.roblox\open-cloud-key.txt`) et `$env:ROBLOX_OPEN_CLOUD_KEY_FILE` vers
   ce fichier. Ne jamais la coller dans le chat, un fichier du dépôt ni la donner au collaborateur.
3. **Donner son accord** à chaque publication (pilote d'un asset, puis le lot).

### Ce qui est automatisé

```bash
node tools/republish-assets.mjs download automation/republication/lot-pilote-combat.json --only 107504521703864
```

Téléchargement (sans clé envoyée à l'URL CDN), décompression, contrôle du format (signature PNG/JPEG
et dimensions, en-tête de mesh `version x.yz`, taille), empreinte SHA-256, journal
`build/republication/<lot>/journal.jsonl`, état `state.json` (reprise : un asset déjà contrôlé
n'est pas retéléchargé). Aucune écriture côté Roblox.

```bash
node tools/republish-assets.mjs publish automation/republication/lot-pilote-combat.json --confirm --only 107504521703864
```

Publication sous `targetOwner.userId` du lot, **un seul asset par défaut** (`--limit N` pour plus),
attente de l'opération, relecture du propriétaire, doublons de contenu publiés une seule fois,
nouvel essai sur 429/5xx (avec `Retry-After`), espacement des appels selon les quotas, messages et
journal sans la clé. Puis `status` et `mapping` : `build/republication/<lot>/mapping.luau` contient
le bloc `MAPPING` de `tools/studio-replace-asset-ids.luau`, limité aux assets **approuvés** et au bon
propriétaire. Pour les lots suivants : `node tools/republish-assets.mjs lot <nom> <sortie.tsv> 11714751172`
construit le lot à partir de la sortie de `tools/studio-check-asset-ownership.luau`.

### Ordre de marche

1. Clé créée et chargée (utilisateur) → `download --only 107504521703864` : verdict d'accès et de format.
2. Si OK : `download` sur les 62 (lecture seule).
3. Accord de l'utilisateur → `publish --only 107504521703864` (un exemplaire) → contrôle sur le
   Creator Hub (propriétaire, modération) et en Studio sur une copie.
4. Accord → `publish --limit 62`, puis `mapping`.
5. Remplacement (§ 3 de la procédure, `DRY_RUN` d'abord) et contrôle (§ 4). Aucun AssetId n'est
   modifié dans Studio avant que les nouveaux fichiers soient vérifiés et approuvés.

### Replis si le téléchargement est refusé

1. **Le collaborateur partage ses assets avec `nxtoma`** : Creator Hub → asset → Permissions, ou en
   une requête avec sa propre clé (`asset-permissions:write`, `PATCH .../assets/permissions`). Puis
   reprendre l'ordre de marche.
2. **Le collaborateur télécharge lui-même** avec sa propre clé (`legacy-asset:manage` sur ses
   propres assets) : `download` seulement, puis il transmet le dossier
   `build/republication/<lot>/` (fichiers + `state.json`, **jamais la clé**) ; `nxtoma` lance
   `publish` sur ce dossier.
3. **Export Studio** (voie B), pièce par pièce : dernier recours.

## Inventaire du lot

« Autres usages » = nombre de propriétés hors `Assets.Combat` qui citent le même identifiant.

| # | Pièce (`ReplicatedStorage.Assets.Combat.`…) | Type | Ancien AssetId | Nouvel AssetId | Propriétaire | Autres usages | Contrôle |
|---|---|---|---|---|---|---|---|
| 1 | `Ennemi_Gobelin.right_arm.right_arm_geom` | Mesh | `101545816385322` | `118019987921845` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 2 | `Ennemi_Gobelin.right_arm.right_arm_geom` | Image (texture) | `94160075609716` | `122489477929295` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 3 | `Ennemi_Gobelin.torso.torso_geom` | Mesh | `126354225080629` | `81994296876896` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 4 | `Ennemi_Gobelin.torso.torso_geom` | Image (texture) | `133350402446247` | `70791096487300` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 5 | `Ennemi_Gobelin.spear.spear_geom` | Mesh | `96195836243902` | `113541974019585` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 6 | `Ennemi_Gobelin.spear.spear_geom` | Image (texture) | `132575861009692` | `133486600178508` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 7 | `Ennemi_Gobelin.left_arm.left_arm_geom` | Mesh | `113521611304500` | `71224312149669` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 8 | `Ennemi_Gobelin.left_arm.left_arm_geom` | Image (texture) | `137672384215371` | `92096196512119` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 9 | `Ennemi_Gobelin.left_leg.left_leg_geom` | Mesh | `110303809370235` | `96318158425033` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 10 | `Ennemi_Gobelin.left_leg.left_leg_geom` | Image (texture) | `127187795674374` | `118602135911120` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 11 | `Ennemi_Gobelin.right_leg.right_leg_geom` | Mesh | `93120410964817` | `117264937278211` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 12 | `Ennemi_Gobelin.right_leg.right_leg_geom` | Image (texture) | `91750919684836` | `114204984519881` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 13 | `Ennemi_Gobelin.shield.shield_geom` | Mesh | `76677295940265` | `87102039570610` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 14 | `Ennemi_Gobelin.shield.shield_geom` | Image (texture) | `103378694748388` | `117673756346208` | nxtoma | 4 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 15 | `Ennemi_Gobelin.head.head_geom` | Mesh | `78939162400478` | `130358316394140` | nxtoma | 3 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 16 | `Ennemi_Gobelin.head.head_geom` | Image (texture) | `86492434726784` | `74584973741577` | nxtoma | 3 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 17 | `Ennemi_RoiOrc.torso.torso_geom` | Mesh | `103169819371473` | `71478320323406` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 18 | `Ennemi_RoiOrc.torso.torso_geom` | Image (texture) | `89047233881409` | `131909660448260` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 19 | `Ennemi_RoiOrc.left_arm.left_arm_geom` | Mesh | `112642946362491` | `83508421781613` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 20 | `Ennemi_RoiOrc.left_arm.left_arm_geom` | Image (texture) | `71021063966201` | `94933030878190` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 21 | `Ennemi_RoiOrc.right_leg.right_leg_geom` | Mesh | `120345676747662` | `133999422924472` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 22 | `Ennemi_RoiOrc.right_leg.right_leg_geom` | Image (texture) | `104127734950939` | `116626633346484` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 23 | `Ennemi_RoiOrc.equipement.PicEpaule (×6)` | Mesh | `76920860898675` | `87636398611747` | nxtoma | 36 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 24 | `Ennemi_RoiOrc.equipement.PicEpaule (×6)` | Image (texture) | `106173864750963` | `78819040732523` | nxtoma | 36 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 25 | `Ennemi_RoiOrc.equipement.Banniere` | Mesh | `77672111260396` | `103913987872590` | nxtoma | 6 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 26 | `Ennemi_RoiOrc.equipement.Banniere` | Image (texture) | `127067342414177` | `109755086679920` | nxtoma | 6 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 27 | `Ennemi_RoiOrc.equipement.Crane_* (×6)` | Mesh | `128823418999050` | `118111566866008` | nxtoma | 31 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 28 | `Ennemi_RoiOrc.equipement.Crane_* (×6)` | Image (texture) | `137802160115556` | `137188753864806` | nxtoma | 31 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 29 | `Ennemi_RoiOrc.equipement.Bouclier` | Mesh | `103134695447206` | `128142825890732` | nxtoma | 6 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 30 | `Ennemi_RoiOrc.equipement.Bouclier` | Image (texture) | `109779900654607` | `123558863952095` | nxtoma | 6 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 31 | `Ennemi_RoiOrc.equipement.LanceHache` | Mesh | `92918638208135` | `123778557616030` | nxtoma | 6 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 32 | `Ennemi_RoiOrc.equipement.LanceHache` | Image (texture) | `110216625447839` | `106567354262713` | nxtoma | 6 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 33 | `Ennemi_RoiOrc.right_arm.right_arm_geom` | Mesh | `88212818943279` | `80447193740394` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 34 | `Ennemi_RoiOrc.right_arm.right_arm_geom` | Image (texture) | `132415709293143` | `133298584671003` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 35 | `Ennemi_RoiOrc.left_leg.left_leg_geom` | Mesh | `88564351715228` | `131351041069598` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 36 | `Ennemi_RoiOrc.left_leg.left_leg_geom` | Image (texture) | `107838959573949` | `125589359724732` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 37 | `Ennemi_RoiOrc.head_with_crown.body.body_geom` | Mesh | `74928021945535` | `136904240008351` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 38 | `Ennemi_RoiOrc.head_with_crown.body.body_geom` | Image (texture) | `90913400970426` | `91464284331965` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 39 | `Ennemi_Slime.eyes.eyes_geom` | Mesh | `129245853106269` | `103217877680272` | nxtoma | 9 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 40 | `Ennemi_Slime.eyes.eyes_geom` | Image (texture) | `94292621457911` | `75699595067669` | nxtoma | 9 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 41 | `Ennemi_Slime.leaves.leaf_* (×5)` | Mesh | `113765157023718` | `138349162345677` | nxtoma | 373 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 42 | `Ennemi_Slime.leaves.leaf_* (×5)` | Image (texture) | `133088852825329` | `84960667599065` | nxtoma | 193 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 43 | `Ennemi_Slime.body.body_geom` | Mesh | `98155401096105` | `74639917575152` | nxtoma | 9 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 44 | `Ennemi_Slime.body.body_geom` | Image (texture) | `107504521703864` | `119239276286265` | nxtoma | 2 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 45 | `Heros_EcuyerDuRempart.right_leg.right_leg_geom` | Mesh | `97234781530135` | `84910752867276` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 46 | `Heros_EcuyerDuRempart.right_leg.right_leg_geom` | Image (texture) | `93433962987135` | `131647612147877` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 47 | `Heros_EcuyerDuRempart.torso.torso_geom` | Mesh | `129637362589534` | `79255303375631` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 48 | `Heros_EcuyerDuRempart.torso.torso_geom` | Image (texture) | `89548083677613` | `90369966674713` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 49 | `Heros_EcuyerDuRempart.short_sword.short_sword_geom` | Mesh | `75240985056567` | `131862534557304` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 50 | `Heros_EcuyerDuRempart.short_sword.short_sword_geom` | Image (texture) | `120503126450909` | `74008864036987` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 51 | `Heros_EcuyerDuRempart.equipement.cor_geom` | Mesh | `95365998598761` | `115792453299450` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 52 | `Heros_EcuyerDuRempart.equipement.cor_geom` | Image (texture) | `71818071718386` | `136322679784475` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 53 | `Heros_EcuyerDuRempart.left_arm.left_arm_geom` | Mesh | `81109617321251` | `81802835707210` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 54 | `Heros_EcuyerDuRempart.left_arm.left_arm_geom` | Image (texture) | `139280197908279` | `134612434145275` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 55 | `Heros_EcuyerDuRempart.head.head_geom` | Mesh | `122530650491358` | `100432254535476` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 56 | `Heros_EcuyerDuRempart.head.head_geom` | Image (texture) | `126970221416552` | `114034593926138` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 57 | `Heros_EcuyerDuRempart.shield.shield_geom` | Mesh | `97369384895028` | `93325326276843` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 58 | `Heros_EcuyerDuRempart.shield.shield_geom` | Image (texture) | `98599059173902` | `86689452203531` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 59 | `Heros_EcuyerDuRempart.right_arm.right_arm_geom` | Mesh | `70497795151957` | `105735082961553` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 60 | `Heros_EcuyerDuRempart.right_arm.right_arm_geom` | Image (texture) | `104195334166006` | `119996842821543` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 61 | `Heros_EcuyerDuRempart.left_leg.left_leg_geom` | Mesh | `92317308860182` | `132987319390929` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
| 62 | `Heros_EcuyerDuRempart.left_leg.left_leg_geom` | Image (texture) | `75603117733240` | `111101512256717` | nxtoma | 5 | OK : Approved, contenu identique ; pas encore remplacé dans Studio |
