# Direction artistique — personnages jouables

Ce document explique comment appliquer aux **futurs héros** la direction artistique extraite de nos monstres et boss validés (`ART_DIRECTION.md`). **Il ne s'appuie sur aucun personnage existant du jeu**, qui ne sont pas des références. Il ne s'appuie pas non plus sur les avatars Roblox standards.

**Objectif :** placer un héros sur un socle à côté de `KingTreant`, `RoiOrc` ou `GobLanceT_A` doit donner l'impression d'une seule et même planche de concept art.

## 1. Principe

Un héros, c'est **notre langage de monstre appliqué à un humain soigné** :
- mêmes formes gonflées, mêmes couches superposées, mêmes matériaux peints, même lisibilité ;
- mais une posture fière au lieu d'être voûtée, une expression déterminée au lieu d'hostile, et des matériaux entretenus au lieu d'être usés et sauvages.

## 2. Proportions humaines

- **Hauteur de référence : environ 6 studs.** Un boss de 13 à 21 studs le domine donc de 2 à 3,5 fois, et un gobelin de 4 studs lui arrive à la poitrine.
- **Haut du corps renforcé :** épaules de 1,3 à 1,5 fois la largeur des hanches, cage thoracique pleine. Même logique que nos monstres, en moins extrême.
- **Mains et avant-bras forts :** les mains sont nettement plus grandes que la réalité, pour tenir une arme de façon lisible (même règle que les poings du Roi Orc).
- **Jambes plus courtes que la normale** (environ 40 % de la hauteur, contre 33 % chez les monstres), pieds massifs dans des bottes épaisses.
- **Tête légèrement grande** (environ 1/5 à 1/5,5 de la hauteur). Jamais chibi (1/3 ou plus) : c'est la dérive refusée sur le gobelin.
- **Posture :** droite, poitrine ouverte, genoux légèrement fléchis, poids sur une jambe. Prêt au combat sans être voûté.

## 3. Silhouettes

- Même règle que les monstres : **3 masses et 1 à 2 éléments qui dépassent**.
- **Contour supérieur identitaire par classe** : casque à cimier ou cornes courtes pour un guerrier, chapeau pointu ou capuche haute pour un mage, capuche et écharpe pour un voleur, auréole de cristaux flottants pour un héros très puissant.
- **Asymétrie par l'équipement**, comme les monstres : arme d'un côté, bouclier, livre ou main libre de l'autre, une seule épaulière surdimensionnée…
- L'**arme prolonge la silhouette** : un bâton de mage peut dépasser la tête, comme la lance-hache de l'orc.

## 4. Visages

- **Traits simplifiés et marqués :** mâchoire nette, sourcils épais et expressifs, nez simple et droit (jamais de groin, jamais de nez retroussé « mignon »).
- **Yeux :** en amande, bien lisibles. Un héros magique peut avoir des **yeux lumineux** (cyan, or) : c'est le même point focal que les tréants et le King Slime.
- **Expression par défaut :** déterminée ou concentrée, bouche fermée ou légèrement entrouverte. **Pas de grand sourire, pas de joues roses, pas de fossettes**, comme pour les monstres. Un léger sourire en coin est toléré pour un héros « malin ».
- **Peau d'une teinte unique** entre visage, cou et mains, peinte avec de légers dégradés, comme nos textures.

## 5. Cheveux

- **Mèches volumineuses et groupées**, en 3 à 7 grosses masses, comme nos touffes de feuilles, jamais en fils fins.
- **Forme qui participe à la silhouette** : mèches qui débordent du casque, tresse épaisse, crête…
- Couleurs de notre palette : bruns, roux, blond paille, noirs chauds, gris. Pas de pastel ni de néon, sauf pour un héros magique, et alors limité à des reflets.
- Les cheveux sont peints dans la texture, avec des reflets en bandes larges.

## 6. Vêtements

- **Tissus épais** peints avec plis larges, bords effilochés ou ourlés, coutures visibles. Même famille que la capuche et la bannière rouges des gobelins, en plus soigné (bord cousu au lieu de déchiré).
- **Couches :** tunique, puis ceinture et sangles de cuir, puis pièces d'armure, puis accessoires (bourse, fiole, parchemin). C'est la même superposition que sur nos monstres.
- **Couleur de faction des héros :** bleu royal et or (bannières du royaume) en accent. Le reste en tons terreux : cuir brun, lin crème, laine sombre.

## 7. Armures

- **Métal épais, riveté, aux arêtes adoucies**, peint et patiné, jamais chromé. Épaulières et gantelets **surdimensionnés** (même logique que les épaulières de l'orc et du King Tréant).
- **Mélange de matériaux** : fer et cuir, bois et fer (boucliers en planches cerclées), os ou pierre gravée pour les classes plus sauvages.
- **Langage de formes :** losange (emblème du royaume) sur les plastrons et boucliers, spirales runiques gravées, pointes discrètes. Les pointes agressives restent réservées aux monstres ou aux héros sombres.

## 8. Armes

- **Taille exagérée** : épée de 3,5 à 4,5 studs pour un héros de 6, bouclier couvrant le torse, bâton plus grand que le héros.
- **Construction** comme les armes de nos monstres : manche enroulé de cuir ou de tissu, pommeau marqué, garde épaisse, lame à dos épais, gemme ou cristal lumineux pour les armes magiques.
- **Tenue réelle** : manche au centre du poing, orientation vérifiée de profil (mêmes règles et mêmes mesures que `MONSTER_PRODUCTION.md` étape 8).

## 9. Accessoires

- 2 à 4 accessoires **identitaires et accrochés** : bourse et fioles à la ceinture, grimoire sur la hanche, cape, carquois, trophée discret…
- **Jamais d'accessoire qui flotte**, sauf un effet magique volontaire et régulier (cristaux en orbite, comme le King Slime).
- Aucun détail essentiel sous 0,5 stud.

## 10. Matériaux et volumes

- Même rendu que les monstres : **MeshParts texturés, peints main**, `Plastic` sous la texture, `Neon` réservé aux yeux et gemmes lumineux, une `PointLight` discrète au maximum.
- Volumes **arrondis et gonflés**, couches lisibles. Aucune pièce en bloc de couleur unie, aucune facette low-poly apparente.

## 11. Densité de détail

- **Concentrée sur le haut du corps et la tête** (épaules, plastron, coiffure ou casque, arme), plus calme sur les jambes, comme nos monstres.
- **Grandes zones de repos** (tunique, cape, plaque de plastron) entre les groupes de détails.
- Petits groupes impairs : 3 rivets, 3 sangles, 5 mèches.

## 12. Hommes et femmes

- **Même proportion de base, même carrure héroïque** : une héroïne a aussi des épaules, des gantelets et des bottes surdimensionnés. On différencie par la coiffure, le visage (traits plus fins, cils marqués) et une taille un peu plus fine, **pas** par une armure « bikini » ni par des proportions de mannequin.
- Mêmes armures couvrantes, mêmes matériaux, même niveau de menace et de présence.
- Hauteur possiblement un peu plus basse (5,6 à 5,8 contre 6), silhouette tout aussi massive.

## 13. Héros très puissants ou impressionnants

On augmente la présence **avec les mêmes outils que les boss**, pas en changeant de style :
- **Élément qui dépasse** plus grand : cornes de heaume, couronne, ailes de cape, halo de cristaux flottants.
- **Point lumineux** plus fort : yeux, gemme d'arme, runes gravées qui brillent. Toujours une seule couleur d'accent lumineux.
- **Matériaux plus nobles** : or gravé, cristal, tissu brodé. Ce sont les mêmes matériaux, dans une version plus riche.
- **Taille** jusqu'à 7 à 7,5 studs, avec des épaulières et une arme encore plus grandes.
- Ce qu'il faut éviter : des effets de particules partout, des couleurs néon multiples, une armure de plaques réaliste lisse.

## 14. Test de cohérence rapide

Placer le héros à côté de `KingTreant` et de `GobLanceT_A`, puis faire une capture de face et une de loin. Ils doivent partager :
1. le même type de texture peinte (pas de pièces unies ni lisses) ;
2. le même poids visuel en haut du corps ;
3. des matériaux de la même famille (bois, cuir, fer, tissu, os ou cristal) ;
4. une palette terreuse avec un seul accent saturé ;
5. un point focal (yeux, gemme ou emblème) ;
6. une lisibilité équivalente à 30 à 60 studs.

Si le héros paraît plus « propre », plus réaliste ou plus « avatar Roblox » que les monstres, il est hors DA. Le verdict se donne avec `VISUAL_QA.md`.
