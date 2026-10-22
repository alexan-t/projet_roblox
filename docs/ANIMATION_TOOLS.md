# Outils d'animation — AnimationKit

Outil d'atelier pour l'issue #16 (animations combat et personnages). Il pose un squelette sur un
héros ou un monstre généré par l'IA de Studio, génère sa marche, la range là où le jeu la cherche et
la montre en boucle à côté du spawn au prochain Play.

`tools/animation/AnimationKit.luau` est un **outil Studio**, pas du code de jeu : il n'est pas
synchronisé par Rojo et ne tourne jamais en partie. Il modifie des assets Studio (modèles,
`KeyframeSequence`), comme un artiste le ferait à la main. Aucun script n'est ajouté au place.

**Squelette commun** : `Kit.rig` pose désormais le squelette partagé par tous les héros et monstres
(os `Buste`, `Tete`, `BrasGauche`... ; animations nommées d'après les os, jeux communs
`Squelette_Leger` / `Squelette_Lourd`). Les os, les fiches de modèles (« cette pièce = tel os ») et
la marche à suivre pour **brancher un nouveau héros ou monstre** sont dans
[`SKELETON.md`](SKELETON.md). AnimationKit lit ces modules dans `ReplicatedStorage.Shared` : la
place doit être synchronisée par Rojo.

## Utilisation

Studio en mode **Edit**.

1. Ouvrir `tools/animation/AnimationKit.luau`, tout copier, coller dans la barre de commande
   (View → Command Bar), Entrée. Cela définit `_G.AnimationKit` pour la session Studio.
2. Lancer :

   ```lua
   _G.AnimationKit.prepare({
   	Source = workspace.Bestiaire.Heros.Socle_03.LancierDesChamps,
   	Set = "LancierDesChamps", -- ReplicatedStorage.Assets.Animations.<Set>
   	Profile = "Leger",        -- "Leger" ou "Lourd"
   })
   ```

3. Lire la ligne `[AnimationKit]` de la sortie : elle dit quelle pièce est tenue par quelle main.
4. Play : le personnage marche en boucle devant le `SpawnLocation`, à côté des autres.

Un agent fait la même chose avec `execute_luau` (contenu du fichier, puis l'appel).

## Ce que fait `prepare`

| Étape | Fonction | Résultat |
| --- | --- | --- |
| Copie | `Kit.copy` | clone dans `Workspace.AtelierAnimation`. **Le modèle source n'est jamais modifié** (le Bestiaire contient les références de DA). |
| Squelette | `Kit.rig` | `HumanoidRootPart` invisible et ancrée, os invisibles communs (dossier `Os`), `AnimationController` + `Animator`, articulations `Motor6D` ; attribut `Os` sur chaque pièce ; chaque arme recollée à son `Poing`, os de l'arme pivotant au centre du poing (voir `SKELETON.md` § Prise) |
| Marche | `Kit.walk` | `KeyframeSequence` « Marche » en boucle, priorité `Movement`, `Pose` nommées d'après les os |
| Rangement | `Kit.share` / `Kit.install` | marche dans le jeu commun de la fiche (`Assets.Animations.Squelette_Leger`...), attaque et ultime dans `Assets.Animations.<Set>` (jeu propre) ; copie dans `ServerStorage.RBX_ANIMSAVES.<modèle>` pour l'Animation Editor |
| Aperçu | `Kit.preview` | jeu `Apercu_<Set>` + tag `ApercuAnimation` (voir plus bas) |
| Placement | `Kit.arrange` | tous les modèles de l'atelier en ligne à 14 studs du spawn, tournés vers lui, pieds au sol, axe du spawn laissé libre |

Tout est enregistré comme une seule étape d'annulation quand Studio l'accepte. Chaque fonction peut
aussi être appelée seule (par exemple `Kit.arrange()` après avoir déplacé des modèles).

## Format de modèle attendu

Le format des modèles générés par l'IA de Studio : une pièce par membre, nommée `<membre>_geom`.

| Rôle | Noms acceptés | Articulation |
| --- | --- | --- |
| buste | `torso_geom`, `body_geom`, `chest_geom` | `Racine` (depuis la racine) |
| tête | `head_geom`, `mask_head_geom`, `skull_geom` | `Cou` |
| bras | `left_arm_geom`, `right_arm_geom` | `EpauleGauche`, `EpauleDroite` |
| jambes | `left_leg_geom`, `right_leg_geom` | `HancheGauche`, `HancheDroite` |

- Le repère est déduit des bras : X = du bras gauche vers le bras droit, -Z = avant. Les pivots
  sont placés en haut des membres (épaules, hanches) et en bas de la tête.
- **Autres pièces** : une pièce dont le nom évoque un objet tenu (`sword`, `weapon`, `spear`,
  `buckler`, `staff`, `marteau`, `etendard`...) suit la main la plus proche (os `ArmeGauche` /
  `ArmeDroite`, `Tenu_<nom>`). Tout le reste est fixé au buste (`Fixe_<nom>` : cape, ceinture, cor,
  cristal...). Corriger de préférence dans la fiche du modèle (`SkeletonConfig`, voir `SKELETON.md`)
  ou par l'attribut `Os` de la pièce ; `Held` reste accepté pour un essai rapide :

  ```lua
  _G.AnimationKit.prepare({ Source = ..., Set = ..., Profile = "Leger",
  	Held = { lantern_geom = "left", cape_geom = "torso" } })
  ```

- Constaté le 01/10/2026 dans Test 3 : 20 héros sur 30 suivent ce format. Les autres (et la
  plupart des slimes et des monstres non humanoïdes) demandent un squelette adapté : `Kit.rig`
  s'arrête avec un message qui nomme la pièce manquante.

## Prise des armes

Avant de brancher le squelette sur un héros, ses armes doivent avoir leur `Prise` et ses bras leur `Poing`
(`SKELETON.md` § Prise). Les 62 héros du Bestiaire et les 22 copies de jeu les ont depuis le
22/10/2026. Pour un nouveau héros (sur le modèle source, dans le Workspace) :

```lua
local Kit = _G.AnimationKit
print(table.concat(Kit.grip(model), "\n"))   -- pose Prise et Poing, recentre le manche
Kit.showGrips(model)                          -- capture de la main de face et de profil
print(table.concat(Kit.checkGrips(model), "\n")) -- vide = PASS
Kit.hideGrips(model)
```

Une ligne « À VÉRIFIER EN CAPTURE » ou un manche qui longe le poing se corrige avec `Kit.aim`
(direction du manche, glissement le long du manche), puis nouvelle capture.

## Profils de marche

La marche est une **courbe continue** (sinus) échantillonnée en 16 clés linéaires par cycle. Un
easing `Cubic InOut` par clé fait marquer un arrêt au corps à chaque clé : c'est ce qui rendait la
première version saccadée. Les bras et la tête suivent les jambes avec un léger retard.

| Profil | Pour | Cycle | Pas | Caractère |
| --- | --- | --- | --- | --- |
| `Leger` | héros, petit monstre (validé sur l'Écuyer du Rempart) | 0,6 s (≈ 7 studs/s) | ±28° | pas militaire, buste penché, arme basse |
| `Lourd` | tréant, colosse (validé sur le Tréant masqué) | 1,2 s (≈ 5 studs/s) | ±22° | rebond retardé, balancement d'épaules, bras qui traînent |

Pour une variante, passer une table au lieu du nom, en partant d'un profil existant :

```lua
local p = table.clone(_G.AnimationKit.Profiles.Lourd)
p.Cycle, p.Stride = 1.5, 18 -- plus lent, plus court
_G.AnimationKit.prepare({ Source = ..., Set = ..., Profile = p })
```

Paramètres (degrés, studs, secondes) : `Cycle`, `Stride` (jambes), `Lean`/`LeanPulse` (buste
penché), `Yaw`/`Roll`/`RollLag` (rotation et roulis du buste), `BobBase`/`Bob`/`BobLag` (rebond),
`ArmForward`/`ArmSwingRight`/`ArmSwingLeft`/`ArmLag`/`ArmSpread*` (bras), `Head*` (tête).
Les `Lag` sont des retards de phase en radians. Garder la vitesse de pas proche de `MoveSpeed`
de `CombatConfig` pour limiter le glissement des pieds.

## Attaque de base

`Kit.attack(model, style)` crée la `KeyframeSequence` « Attaque » (non bouclée, priorité `Action`)
à partir de poses clés. Sur un modèle déjà riggé dans l'atelier :

```lua
local Kit = _G.AnimationKit
local m = workspace.AtelierAnimation.EcuyerDuRempart
Kit.install(m, "EcuyerDuRempart", Kit.attack(m, "Epee"))
Kit.preview(m, "EcuyerDuRempart", "Attaque") -- au Play : l'attaque, puis 0,8 s de pause, en boucle
```

Ou d'un coup à la préparation : `prepare({ ..., Attack = "Epee", Preview = "Attaque" })`.

| Style | Pour | Durée | Impact | Mouvement |
| --- | --- | --- | --- | --- |
| `Epee` | arme à une main + bouclier (validé sur l'Écuyer) | 0,6 s | 0,2 s | armé de côté, coup en diagonale à travers le corps, petit pas en avant, bouclier gardé devant ; l'arme tourne dans la main à l'impact pour finir vers le bas-gauche sans entrer dans le bouclier (`HEROES_QA.md`) |
| `Griffe` | gros monstre à mains nues (validé sur le Tréant) | 1,0 s | 0,35 s | gros revers de la main droite : bras armé en arrière, buste tourné, balayage à travers le corps, bras gauche en contrepoids |
| `Ecrasement` | variante (non retenue pour le Tréant) | 1,0 s | 0,32 s | deux bras levés, abattus au sol devant lui, buste plié, rebond lourd |

**Synchronisation avec le combat** : `CombatViewController` joue « Attaque », affiche les dégâts et
fait réagir la cible **à la même image** (événement `Attack`). Le coup doit donc tomber tôt :
préparation courte, puis frappe. L'instant du coup est marqué par un `KeyframeMarker` « Impact »
(et l'attribut `Impact` de la séquence) : le code de combat pourra s'en servir pour retarder les
chiffres de dégâts et « Touche » jusqu'au coup (`AnimationTrack:GetMarkerReachedSignal("Impact")`).
Garder la durée sous l'`AttackInterval` le plus court qui utilisera l'animation (`CombatConfig`).

Un nouveau style se décrit comme une table `{ Length, Impact, Keys = { { Time, Easing, Poses } } }`
(voir `Kit.Attacks`) : poses par rôle (`torso`, `head`, `leftArm`, `rightArm`, `leftLeg`,
`rightLeg`) en `{ rx, ry, rz, y }`, dans le repère racine : +rx = membre vers l'avant, +ry = buste
vers la gauche, +rz = bras droit vers l'extérieur (bras gauche : -rz). Les jambes étant attachées au
buste, compenser sur les jambes une inclinaison ou une rotation du buste pour garder les pieds au sol.
L'`Easing` d'une clé règle le trajet vers la clé suivante (`In` = accélère vers le coup).

## Aperçu au Play

`MonsterAnimationController` anime en boucle tout modèle tagué `ApercuAnimation` (Attente, puis
Marche, Attaque, Touche, Mort). Il coupe la marche toutes les 2,4 s. Pour l'éviter sans toucher au
code, l'aperçu utilise un jeu séparé `Apercu_<Set>` où l'animation étudiée est rangée sous le nom
`Attente`, jouée en continu. Le vrai jeu (`<Set>`, attribut `JeuAnimationsCombat` du modèle) reste
celui du combat.

Quand un personnage aura plusieurs animations (Attente, Attaque...), remettre son attribut
`JeuAnimations` sur le vrai jeu pour voir l'enchaînement complet.

## Attaque du Roi Orc (boss) et effet d'impact

Préparé à l'origine avec `Parts` / `Held` ; ces réglages sont maintenant la fiche
`SkeletonConfig.Models.RoiOrc` (tête `body_geom`, bannière au buste, pics et crânes d'épaule au bras
le plus proche, profil `Lourd`, attaque `Fendoir`, couvercles de bras). La DEV n'a pas de Roi Orc au
Bestiaire : la source est une copie désarticulée de l'asset de combat (voir `SKELETON.md`, exemples).

```lua
local source = game.ReplicatedStorage.Assets.Combat.Ennemi_RoiOrc:Clone()
_G.AnimationKit.unrig(source)
source.Name = "RoiOrc"
_G.AnimationKit.prepare({ Source = source, Set = "RoiOrc", Name = "RoiOrc_Squelette", Arrange = false })
source:Destroy()
```

`Kit.closeArms` peut être relancé : il remplace les couvercles et toutes les articulations qui les
tenaient (aucun `Motor6D` orphelin).

- `Membres` (ex-`Parts`) désigne la pièce d'un membre au nom inhabituel ; `BrasProche`
  (ex-`"nearest"`) une pièce portée par le bras le plus proche. Voir `SKELETON.md`.
- Les styles peuvent animer l'**arme elle-même** (`weaponRight`, `weaponLeft` : os `ArmeDroite`,
  `ArmeGauche`, pivot dans la main). L'angle de la lame est la somme bras + arme.
- `Fendoir` (1,4 s, impact 0,7 s) : armé lent, le bras lève la lance-hache au-dessus de la tête,
  court temps suspendu, puis l'abat devant lui ; la lame mord le sol. Demande `Kit.closeArms`.
- **Effet d'impact** : poser l'attribut texte `EffetAttaque = "Seisme"` sur le modèle (asset). Au
  coup de son « Attaque », `src/client/Controllers/AttackEffectController.lua` soulève un anneau de
  terre irrégulier sous l'arme, projette des éclats, soulève de la poussière et secoue un peu la
  caméra du joueur proche. Démonstration Studio : tag `ApercuAttaque` (attaque + effet en boucle).
- Le combat retarde les chiffres de dégâts et la disparition de la cible jusqu'à l'impact de toute
  attaque dont la séquence a un attribut `Impact` (héros 0,2 s, Roi Orc 0,7 s).

## Ultime du héros de départ

`Kit.ultimate(model, "Rempart")` crée la séquence « Ultime » de l'Écuyer du Rempart (0,9 s, impact
0,3 s) : ramassé derrière le bouclier, épée tirée en arrière, puis grand estoc. L'arme est tournée
dans la main (`weaponRight`) pour que la pointe vise l'avant pendant l'estoc ; ces angles sont
mesurés sur l'Écuyer : les remesurer pour un autre modèle (`HEROES_QA.md`).

```lua
local Kit = _G.AnimationKit
local m = workspace.AtelierAnimation.EcuyerDuRempart
Kit.install(m, "EcuyerDuRempart", Kit.ultimate(m, "Rempart"))
```

L'effet visuel (lueur, lame dorée, anneau au sol) est du code de jeu :
`src/client/Controllers/UltimateEffectController.lua`, appelé par `CombatViewController` sur
`UltimateUsed`. Garder `ANIMATION_IMPACT` de ce fichier égal à l'`Impact` du style. Pour le voir au
Play, taguer le héros riggé `ApercuUltime` (Studio) : ultime en boucle vers un point à 10 studs
devant lui.

## Disparition à la mort (pas de réaction aux dégâts)

Le jeu est surtout en one-shot : pas d'animation de douleur (« Touche »). À la mort, l'unité se
dissout : c'est du code de jeu, `src/client/Controllers/DefeatEffectController.lua`, appelé par
`CombatViewController` sur `UnitDied` (voir `docs/COMBAT.md`). Il marche sur tout modèle, riggé ou
non, sans réglage.

Pour le voir au Play, taguer un modèle de l'atelier `ApercuDisparition` (Studio uniquement) : une
copie figée du modèle se dissout, puis il réapparaît, en boucle (attribut `ApercuPause`). Les réglages
(durée, sursaut, bascule, poussière, étincelles) sont les constantes en tête du fichier.

## Voir le rendu en x2

Attribut numérique `ApercuVitesse` sur `Workspace.AtelierAnimation` (ou sur un modèle) : toutes les
démonstrations (marche, attaque, ultime, effets) jouent à cette vitesse. `2` = rendu du combat en x2,
supprimer l'attribut pour revenir en x1. En combat, la vitesse vient de `SpeedChanged` (voir
`docs/COMBAT.md`).

## État actuel DEV

Après la migration pilote sur le squelette commun (Écuyer et Roi Orc, voir `SKELETON.md`) :

| Jeu (`ReplicatedStorage.Assets.Animations`) | Séquences | Squelette | `AssetId` |
| --- | --- | --- | --- |
| `EcuyerDuRempart` | Attaque, Ultime | commun | absent |
| `RoiOrc` | Attaque (Fendoir) | commun | absent |
| `Squelette_Leger` | Marche (Écuyer, futurs héros légers) | commun | absent |
| `Squelette_Lourd` | Marche (Roi Orc, futurs modèles lourds) | commun | absent |
| `Gobelin` | Attente, Marche, Attaque, Touche, Mort | ancien | absent |
| `TreantMasque` | Marche, Attaque (pas d'Ultime) | ancien | absent |
| `Apercu_EcuyerDuRempart`, `Apercu_TreantMasque`, `Apercu_RoiOrc` | Attente (démonstration d'atelier, pas pour le combat) | — | absent |

Modèles de combat (`ReplicatedStorage.Assets.Combat`) : `Heros_EcuyerDuRempart` et `Ennemi_RoiOrc`
sur le squelette commun ; `Ennemi_Gobelin` sur l'ancien squelette (les deux coexistent en combat).
Les anciennes versions (assets et séquences) sont dans `ServerStorage.AnimationKitArchive`.

`Workspace.AtelierAnimation` : `EcuyerDuRempart_Squelette` et `RoiOrc_Squelette` (squelette commun,
aperçu de la Marche) ; `Treant_Masque` (ancien squelette, inchangé) ; `EcuyerDuRempart` et `RoiOrc`,
anciennes copies de l'ancien squelette, **obsolètes** (leurs jeux contiennent maintenant des séquences
du squelette commun : à retirer de l'atelier). Les modèles du Bestiaire et de
`ServerStorage.Assets.Heros` ne sont pas articulés. Bestiaire et atelier sont des références / outils
de design, pas une source de vérité gameplay.

- **Studio : fonctionnel.** Vérifié en combat réel (stages 1-1 et 1-5, x1 / x2) et au Play pour
  l'atelier ; les séquences sont enregistrées à la volée.
- **Production : `AssetId` requis.** Aucune `KeyframeSequence` n'a encore d'`AssetId` publié, pas
  même celles du Gobelin. Hors Studio, une séquence sans `AssetId` ne joue pas. Chaque séquence de
  combat doit être publiée **par le propriétaire de l'expérience** (sinon Roblox refuse de la jouer
  dans cette expérience), puis son identifiant mis dans l'attribut `AssetId` de la séquence.
- Avant publication : sortir `Workspace.AtelierAnimation` de la place jouée (aperçus en boucle,
  voir `SKELETON.md` § « Atelier et publication »). Les jeux `Apercu_*` ne se publient pas.
- Dans la DEV, deux `SpawnLocation` existent (`Lobby.Monde.SpawnLobby` actif, ancien
  `Workspace.SpawnLocation` de test désactivé). `Kit.arrange` prend le premier `SpawnLocation`
  trouvé : vérifier lequel avant de ranger l'atelier.

## Limites

- Les animations sont enregistrées à la volée, **uniquement en Studio**. Pour le jeu publié :
  publier chaque `KeyframeSequence` depuis l'Animation Editor, puis mettre son identifiant dans
  l'attribut `AssetId` de la séquence (lu par `MonsterAnimationController`).
- Pas de genoux ni de pieds articulés : les modèles IA ont une seule pièce par jambe.
- Les capes et tabards sont fixés au buste, sans mouvement secondaire.
- Marche, attaque de base et ultime (Écuyer) sont générés ; pas encore d'Attente (repos).
- **Bras en coque** (Roi Orc) : ses bras sont ouverts sur toute leur face intérieure (côté buste).
  Au repos le buste cache l'ouverture ; dès que le bras s'écarte, on voit l'intérieur, noir.
  `Kit.closeArms(model, couleurPeau)` ferme cette face avec un ellipsoïde couleur peau porté par le
  bras, qui reste dans l'aisselle au repos. Roi Orc : `Color3.fromRGB(76, 111, 41)` (moyenne des pixels
  de peau de la texture du bras, via `AssetService:CreateEditableImageAsync`). Pour un autre modèle,
  régler d'abord en rouge vif : bras seul vu du buste (plus de noir), puis modèle entier au repos de
  face, de dos et de dessus (rien ne dépasse), puis en gros plan aux instants clés de l'animation.
  Erreur à ne pas refaire : une sphère centrée sur l'épaule (dépasse au repos sans boucher le trou).
- Les épaules des modèles IA sont des pièces creuses : un bras levé très haut ou très écarté laisse
  voir le dessous sombre de l'épaulière. Garder les bras sous ~80° (rx) et ~30° (rz). Le pivot
  d'épaule est placé près du bord intérieur du bras pour limiter l'effet ; `Kit.unrig` puis
  `Kit.rig` reposent le squelette d'un modèle riggé (sur le squelette commun : régénérer ensuite
  les séquences d'un modèle de l'ancien squelette).
