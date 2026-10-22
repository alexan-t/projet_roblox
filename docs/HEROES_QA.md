# Héros — contrôle des armes et des animations du 20 octobre 2026

**Verdict global : FIX.** Les 60 héros du catalogue passent sur la tenue des armes, au repos
et, pour l'Écuyer (seul héros animé), pendant ses animations. Quatre défauts ont été corrigés.
Les deux brouillons de Brise-Braise (socles 10 et 11, hors catalogue) restent non texturés.

## Environnement et portée

- Place Studio **test 3** (placeId `120616399792561`), mode Edit, aucune publication.
- 62 modèles posés sur `Workspace.Bestiaire.Heros` (socles 1 à 5 et 10 à 68 ; 6 à 9, 12 et 13
  sont vides). Copies de jeu : les 22 modèles de `ServerStorage.Assets.Heros`.
- Contrôle centré sur la grille `VISUAL_QA.md` lignes **Armes et accessoires**, **Clipping**,
  **Géométrie** et **Matériaux**. Les lignes de niveau de qualité, d'originalité et de
  comparaison côte à côte avec les références principales n'ont pas été rejouées : les héros
  existants n'ont pas été régénérés.
- Originaux archivés avant toute retouche dans `ServerStorage.Archive_Heros_QA` ; chaque
  retouche est une étape `ChangeHistoryService` (Ctrl+Z).

## Méthode

1. **Mesure de prise** pour chaque objet tenu : centre du poing estimé par les points intérieurs
   du bras les plus éloignés de l'épaule, puis test « dedans » (`GetPartsInPart` avec une sonde)
   de l'arme sur la zone du poing (`MONSTER_PRODUCTION.md`, Outils § D).
2. **Captures réelles** de chaque héros (trois-quarts, puis face, profil ou dessus pour les cas
   douteux), dont avant et après chaque correction.
3. **Animations** : copies de l'Écuyer de l'atelier posées à chaque clé d'Attente, Marche,
   Attaque et Ultime (poses appliquées aux `Motor6D` des copies, jamais au modèle du Bestiaire),
   direction de la pointe mesurée dans le repère du héros, points de la lame testés contre le
   bouclier, le buste, la tête, le bras gauche et les jambes. Copies supprimées après contrôle.

## Corrections appliquées

| Héros | Défaut vu | Correction | Après |
| --- | --- | --- | --- |
| #25 Prêtresse aux Lucioles | Bâton à côté du poing droit (0 point de contact) ; cristal au sommet = cube néon visible du dessus | Bâton déplacé de 0,28 stud sur le centre du poing ; cristal en sphère de 0,6 (Bestiaire et copie de jeu) | Poing fermé sur le manche de face et de profil |
| #47 Tisseur de Destins | Quenouille qui passe à côté du poing droit (3 points sur 28) | Déplacée de 0,26 stud perpendiculairement à son axe, pelote comprise | Manche dans le poing de face et de profil |
| #58 Reine du Firmament Doré | Sceptre qui frôle le côté du poing | Déplacé de 0,34 stud, cristal du sommet déplacé de même | Manche dans le poing de face |
| #01 Écuyer du Rempart, Ultime | « Grand estoc » dont la lame part vers le haut et la gauche à l'impact (pointe à 25 % vers l'avant) | `weaponRight` ajouté au style `Rempart` (AnimationKit) et à la séquence Studio | Pointe à 96–99 % vers l'avant à l'armé et pendant l'estoc ; poing toujours sur le manche |
| #01 Écuyer du Rempart, Attaque | À l'impact et juste après, la lame entre dans le bouclier (4 et 6 points) | `weaponRight` ajouté au style `Epee` (AnimationKit) et à la séquence Studio | Diagonale finie vers le bas-gauche, aucun point de lame dans le corps ou le bouclier, y compris à 0,25 s interpolé |

Les anciennes séquences sont archivées (`Archive_Heros_QA.EcuyerDuRempart_*_avant_QA`) ;
la copie de `ServerStorage.RBX_ANIMSAVES.EcuyerDuRempart` a reçu les mêmes poses.

## Résultats par héros (au repos)

**PASS** (arme dans le poing, orientation lisible de face et de profil, pas d'interpénétration
visible) : #01 à #05, #14 à #24, #25 (après correction), #26 à #46, #47 (après correction),
#48 à #57, #58 (après correction), #59 à #68.

Cas vérifiés de plus près et laissés tels quels, car voulus :
- #15, #21 : bouclier sanglé à l'avant-bras (pas dans le poing) ; #36 : cloche portée dans le dos ;
  #19 : luth au dos ; #17 : faucon sur le bras levé ; #22 : cartes en éventail entre les doigts.
- #30, #31, #61 : cristaux cubiques tournés à 45°, lus comme le losange de la DA.
- #44 : masse tenue en garde vers l'avant ; #45 : clé géante tenue en travers.

**FIX non traité** : #10 et #11 (`Heros_BriseBraise_Stylise_B` / `_A`). Six pièces sur huit
(et sept sur huit) n'ont aucune texture : le modèle s'affiche gris uni. Ce sont deux variantes
d'un héros absent de `HeroConfig`, en cours de travail (archives `Archive_BriseBraise`). Il faut
choisir la variante, puis la texturer (`generate_texture`) et repasser la grille complète.

## Animations de l'Écuyer

| Séquence | Clés | Pointe vers l'avant | Lame dans le corps ou le bouclier | Verdict |
| --- | --- | --- | --- | --- |
| Attente (aperçu) | 6 | comme l'Attaque | bouclier à 0,20 et 0,30 avant correction (mêmes poses que l'Attaque) ; même correction appliquée | PASS (mesure) |
| Marche | 17 | 0,54 à 0,80 | aucun (la lame passe devant le genou) | PASS |
| Attaque | 5 | lame en diagonale vers le bas-gauche | aucun après correction | PASS |
| Ultime | 5 | 0,72 au repos, 0,96 à 0,99 à l'armé et à l'estoc | aucun | PASS |

L'aperçu d'atelier `Apercu_EcuyerDuRempart.Attente` reprend les poses de l'attaque suivies
d'une pause (démonstration, pas du combat) : il a reçu les mêmes poses d'arme, ancienne version
archivée (`EcuyerDuRempart_ApercuAttente_avant_QA`).

Les 59 autres héros n'ont ni squelette ni animation : en combat, leur vrai modèle est posé
statique (voir `HEROES.md`). Leur contrôle « pendant les animations » sera à faire quand ils
seront articulés (`SKELETON.md`).

## Contre-contrôle

Deux tests gardent les corrections en place :

- `tools/studio-check-heroes.luau` (mode Edit, lecture seule, renvoie le nombre de problèmes) :
  poses de l'épée et marqueur Impact des cinq séquences de l'Écuyer (jeu, aperçu Attente,
  `RBX_ANIMSAVES`), prise de l'arme de #01, #25, #47 et #58, cristal en sphère de #25, copies
  de jeu identiques au Bestiaire (positions par rapport au buste : les pivots diffèrent). Les
  brouillons #10 et #11 sont signalés « CONNU » sans compter.
- `tests/heroes-weapons.test.mjs` (`node --test`) : le script Studio attend les mêmes poses
  qu'AnimationKit, le même impact que `UltimateEffectController`, et reste en lecture seule.

Résultats du 20 octobre 2026 (place test 3) :

| Contrôle | Résultat |
| --- | --- |
| Séquences de l'Écuyer : 5 séquences, 26 clés, 5 marqueurs Impact | PASS |
| Prise : épée 0 stud, bâton #25, quenouille #47, sceptre #58 dans le bras | PASS |
| Prise : bouclier de l'Écuyer, poing plaqué à la poignée (écart 0,14 stud, toléré 0,2) | PASS, vu en capture de profil |
| Cristal de #25 en sphère (Bestiaire et copie de jeu) | PASS |
| 22 copies de jeu identiques au Bestiaire | PASS |
| Captures de #01 (face, profil), #25 (face), #47 et #58 après corrections | PASS |
| Script Studio : 0 problème ; brouillons #10 (5/8 pièces sans texture) et #11 (7/8) | CONNU (FIX) |
| `node --test tests/heroes-weapons.test.mjs` : 7 tests | PASS (7/7) |
