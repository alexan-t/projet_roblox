# Outils d'animation — AnimationKit

Outil d'atelier pour l'issue #16 (animations combat et personnages). Il pose un squelette sur un
héros ou un monstre généré par l'IA de Studio, génère sa marche, la range là où le jeu la cherche et
la montre en boucle à côté du spawn au prochain Play.

`tools/animation/AnimationKit.luau` est un **outil Studio**, pas du code de jeu : il n'est pas
synchronisé par Rojo et ne tourne jamais en partie. Il modifie des assets Studio (modèles,
`KeyframeSequence`), comme un artiste le ferait à la main. Aucun script n'est ajouté au place.

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
| Squelette | `Kit.rig` | `HumanoidRootPart` invisible et ancrée, `AnimationController` + `Animator`, articulations `Motor6D` |
| Marche | `Kit.walk` | `KeyframeSequence` « Marche » en boucle, priorité `Movement` |
| Rangement | `Kit.install` | `ReplicatedStorage.Assets.Animations.<Set>.Marche` (jeu de combat) + copie dans `ServerStorage.RBX_ANIMSAVES.<modèle>` pour l'Animation Editor |
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
  `buckler`, `staff`, `marteau`, `etendard`...) suit la main la plus proche (`Tenu_<nom>`). Tout le
  reste est fixé au buste (`Fixe_<nom>` : cape, ceinture, cor, cristal...). Corriger un cas avec
  `Held` :

  ```lua
  _G.AnimationKit.prepare({ Source = ..., Set = ..., Profile = "Leger",
  	Held = { lantern_geom = "left", cape_geom = "torso" } })
  ```

- Constaté le 01/10/2026 dans Test 3 : 20 héros sur 30 suivent ce format. Les autres (et la
  plupart des slimes et des monstres non humanoïdes) demandent un squelette adapté : `Kit.rig`
  s'arrête avec un message qui nomme la pièce manquante.

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

## Aperçu au Play

`MonsterAnimationController` anime en boucle tout modèle tagué `ApercuAnimation` (Attente, puis
Marche, Attaque, Touche, Mort). Il coupe la marche toutes les 2,4 s. Pour l'éviter sans toucher au
code, l'aperçu utilise un jeu séparé `Apercu_<Set>` où l'animation étudiée est rangée sous le nom
`Attente`, jouée en continu. Le vrai jeu (`<Set>`, attribut `JeuAnimationsCombat` du modèle) reste
celui du combat.

Quand un personnage aura plusieurs animations (Attente, Attaque...), remettre son attribut
`JeuAnimations` sur le vrai jeu pour voir l'enchaînement complet.

## Limites

- Les animations sont enregistrées à la volée, **uniquement en Studio**. Pour le jeu publié :
  publier chaque `KeyframeSequence` depuis l'Animation Editor, puis mettre son identifiant dans
  l'attribut `AssetId` de la séquence (lu par `MonsterAnimationController`).
- Pas de genoux ni de pieds articulés : les modèles IA ont une seule pièce par jambe.
- Les capes et tabards sont fixés au buste, sans mouvement secondaire.
- Seule la marche est générée pour l'instant ; Attente, Attaque, Touche, Mort et Ultime restent à faire.
- `CombatViewController` lance « Marche » sur `MoveStarted` mais ne l'arrête pas ensuite, et ne
  tient pas compte de la vitesse x2 : à corriger avant de brancher ces modèles sur le combat.
