# Direction artistique — créatures (monstres et boss)

Ce document décrit ce que **nos monstres et boss validés** ont réellement en commun. Il est tiré de l'inspection des modèles dans Studio (tailles mesurées, découpage, matériaux, palettes de texture échantillonnées) et des retours de validation et de refus de l'équipe. Ce n'est pas un guide générique de modélisation.

## 1. Références validées

Place Studio « test » (Sandbox), `Workspace`. Les modèles sont posés sur les socles du `Workspace.Bestiaire`.

| Modèle (Workspace) | Rôle | Socle | Taille mesurée (L × H × P, studs) | Moodboard |
|---|---|---|---|---|
| `Slime_Eau` | monstre, base des slimes | Monstres #03 | 4,8 × 4,7 × 3,4 (corps seul 3,8 × 2,9) | `slime_source.webp` |
| `Slime_Lave`, `Slime_Plante`, `Slime_Champignon` | variantes élémentaires | Monstres #04 à #06 | idem (champignon 4,4 × 3,3 avec chapeau 5,6 de large) | `slime_source.webp` (bas de planche) |
| `Treant_Masque` | monstre | Monstres #07 | 6,1 × 8,0 × 2,8 | `treant.webp` |
| `Treant_Arbre` | monstre | Monstres #08 | 9,8 × 9,8 × 6,9 | `treant.webp` (variante) |
| `GobLanceT_A` | monstre, gobelin à lance | Monstres #12 | 4,2 × 4,1 × 3,0 | `gobelin.webp` (équipement seulement, voir § 9) |
| `GobDagueT_B` | monstre, gobelin à dague | Monstres #15 | 4,0 × 4,2 × 2,7 | — |
| `RoiOrc` | boss | Boss #01 | 12,4 × 13,0 (lance-hache 13) | `boss_roi_orc.webp` |
| `KingSlime` | boss | Boss #02 | 14 × 12 corps, 19,9 de haut avec couronne | `boss_king_slime.webp` |
| `KingTreant` | boss | Boss #03 | 16,2 × 16 corps, 21,3 avec bois | `boss_king_treant.webp` |

**Les gobelins de référence sont `GobLanceT_A` et `GobDagueT_B`** (style « tréant »). Ne sont **pas** des références, parce qu'ils ont été refusés comme hors DA : `Gobelin` (#02, chibi), `GobelinDague_A/B` (#01, #09), `GobelinLance_A/B` (#10, #11), et le premier tréant `Treant_Arbre` avant son feuillage refait. `GobLanceT_B` et `GobDagueT_A` (#13, #14) sont dans le bon style, mais n'ont pas été retenus.

Les versions refusées et les pièces d'origine sont rangées dans `ServerStorage.Archive_*` (`Archive_Gobelin`, `Archive_Slime`, `Archive_RoiOrc`, `Archive_KingSlime`, `Archive_KingTreant`). Elles montrent ce qu'il **ne faut pas** faire.

Les moodboards de l'équipe sont dans `docs/references/moodboards/`. Ce sont des planches de personnage (face, profil, dos, pose d'attaque, portrait, détails, expressions, palette). Nos modèles 3D en sont l'interprétation validée.

## 2. En une phrase

Des créatures de **fantasy stylisée peinte à la main**, aux **silhouettes massives et lisibles**, **adultes et menaçantes** (jamais mignonnes par défaut, sauf le slime de base), faites de **matériaux naturels et artisanaux superposés** (écorce, os, cuir, fer, tissu rouge, mousse, cristal), avec **un seul point lumineux** fort (yeux ou cœur), et une palette **terreuse** relevée d'**accents rouges, cyan ou dorés**.

## 3. Proportions

Mesures réelles, en proportion de la hauteur du corps (sans arme ni couronne) :

- **Haut du corps lourd, jambes courtes.** Sur `RoiOrc` : torse de 8,9 et bras de 7,6 pour des jambes de 4,5. Sur `KingTreant` : bras de 11,3 et jambes de 7,3. Les jambes font environ **un tiers** de la hauteur, jamais la moitié.
- **Bras longs et épais.** Chez le tréant et les boss humanoïdes, les mains descendent presque aux genoux. Les bras sont aussi larges, voire plus larges, que les jambes (`GobLanceT_A` : bras droit 1,9 × 2,1 contre jambes 0,9 × 1,5).
- **Épaules très larges.** Largeur totale entre 1,0 et 1,3 fois la hauteur du corps pour les humanoïdes massifs (`RoiOrc` 12,4 × 13 ; `KingTreant` 16,2 × 16).
- **Tête relativement petite pour les créatures fortes** (tréants, orc), environ 1/5 à 1/6 de la hauteur, souvent **enfoncée dans les épaules** (dos voûté, tête projetée vers l'avant). **Plus grande chez les gobelins** (≈ 1/3 : tête de 1,4 à 2,3 pour 4,1 de haut). C'est leur marque, mais sans aller jusqu'au chibi.
- **Posture voûtée, genoux fléchis, centre de gravité bas.** Les créatures sont prêtes à bondir, jamais droites comme un piquet.
- **Slimes :** dôme plus large que haut, lobes arrondis à la base. Le King Slime fait 14 de large pour 12 de haut (corps).

### Échelle entre créatures (en jeu)

| Catégorie | Hauteur visée | Socle |
|---|---|---|
| Petit monstre (gobelin, slime) | 4 à 5 studs | Monstres, Ø 9,6 |
| Monstre moyen (tréant) | 8 à 10 studs | Monstres, Ø 9,6 |
| Boss | 13 à 21 studs, dont 16 pour le corps | Boss, Ø 18 |

Un boss doit dominer un héros d'environ 6 studs d'au moins **deux fois sa hauteur**, et occuper la majeure partie de son socle de 18 studs.

## 4. Niveau de stylisation

- **Stylisé peint à la main, façon jeu d'action fantasy stylisé** (proche de l'esprit Warcraft et Hearthstone), et **non pas** low-poly à facettes, réaliste ou « jouet » à couleurs unies. Les modèles sont des **MeshParts texturés** (textures 1024 × 1024 peintes), pas des Parts de couleur unie.
- **Formes exagérées mais crédibles :** mains énormes, épaulières surdimensionnées, défenses et griffes grossies, sans jamais de gag.
- **Adulte et dangereux.** Les refus répétés portaient tous sur l'aspect enfantin : sourires, joues roses, fossettes, grosse tête chibi, visage rond et gentil. **Ce qui est validé :** sourcils froncés, yeux plissés ou lumineux, crocs, grimaces.
- **Exception :** le slime de base (`Slime_Eau`) reste attachant. Il a deux yeux ovales verticaux, **aucune bouche, aucune joue**. Le côté mignon passe uniquement par la forme, jamais par un sourire.

## 5. Construction des silhouettes

Chaque créature validée se lit par **3 masses principales et 1 à 2 éléments qui dépassent** :

- `RoiOrc` : masse du torse et des épaules, bouclier, lance-hache verticale. Ce qui dépasse : cornes et pics d'os de la couronne.
- `KingTreant` : torse et épaules de pierre, deux bras-griffes, jambes-racines. Ce qui dépasse : **deux grands bois ramifiés** qui augmentent la hauteur d'un tiers.
- `KingSlime` : dôme de gelée, couronne de lianes, couronne dorée. Ce qui dépasse : grands cristaux de la couronne et **6 cristaux flottants** qui élargissent la silhouette (19,8 de large pour un corps de 14).
- Gobelins : grosse tête à capuche et longues oreilles, torse voûté, arme.

Règles observées :

- **Le haut de la silhouette porte l'identité :** couronne, bois, cornes, capuche, feuilles. On doit reconnaître la créature à son contour supérieur seul.
- **Asymétrie par l'équipement :** arme d'un côté, bouclier de l'autre. Le corps reste globalement symétrique.
- **Les armes prolongent la silhouette** (lance de 13 pour un orc de 13) et sont tenues **vraiment dans le poing** (§ 7).
- **Rien ne flotte par accident.** Les breloques et la bannière posées « dans le vide » sur le King Tréant ont été refusées puis retirées. Seul flottement accepté : les cristaux **magiques** en orbite du King Slime, qui sont clairement volontaires, régulièrement espacés et identiques.

## 6. Volumes et géométrie

- **Volumes arrondis et gonflés, arêtes adoucies.** Pas de facettes low-poly visibles, pas de boîtes. Le feuillage en cubes du premier `Treant_Arbre` a été refusé, puis remplacé par un dôme de **163 grandes feuilles peintes**.
- **Superposition de couches :** peau ou matière, puis armure ou écorce, puis sangles et cordes, puis trophées, feuilles et champignons. C'est ce qui donne du « travaillé » sans multiplier les formes principales.
- **Découpage technique** (constaté sur tous les modèles) : un `Model` par membre (`head`, `torso`, `left_arm`, `right_arm`, `left_leg`, `right_leg`, plus l'arme, le bouclier ou `crystal_core`), chacun avec un seul `MeshPart`. Les ajouts vont dans un `Model` `equipement` ou `accessoires`. Ce découpage permet l'animation.
- **Formes dominantes par famille :** losanges et pointes (masques, runes, cristaux, lames), crocs et cornes courbes, spirales (runes du tréant, emblème du King Slime), cercles cerclés de métal (boucliers, boucles de ceinture).

## 7. Matériaux, armes et accessoires

Matériaux présents sur les validés, tous **peints dans la texture** (pas de matériau Roblox réaliste) :

- **Écorce et bois** brun chaud, veinés, avec **lierre et mousse** (tréants, manches, planches de bouclier).
- **Os et ivoire crème** : masques, pics, défenses, crânes, pommeaux.
- **Cuir brun sombre** : sangles, ceintures, brassards, bottes.
- **Fer gris riveté** : cerclages, épaulières, lames. Toujours usé, jamais chromé.
- **Tissu rouge déchiré** : capuches, écharpes, pagnes, bannières, rubans d'arme. C'est le fil rouge de la faction gobelins et orcs.
- **Pierre grise gravée** : épaulières et brassards du King Tréant, avec runes en losange.
- **Cristal cyan lumineux** et **or** : cœurs, couronnes, cristaux flottants.
- **Gelée brillante** (slimes) : dégradé clair en haut et foncé en bas, gros reflets blancs, bulles.

Matériaux Roblox utilisés : `Plastic` par défaut sous la texture, et **`Neon` uniquement pour les yeux lumineux** (yeux du King Slime). Lumières : `PointLight` discrètes (cœur du King Tréant : luminosité 0,8, portée 7 ; slime de lave : 1,2 / 9 ; King Slime : 1,5 / 16). Une lueur trop forte, qui teintait les épaules du tréant en bleu, a été refusée.

**Armes et boucliers (règles apprises sur `RoiOrc` et les gobelins) :**
- Le manche passe **dans le creux du poing**. On trouve le centre du poing par mesure, jamais à vue.
- Arme d'hast (lance-hache, lance) : **perpendiculaire au corps**, tenue devant soi, lames dans le plan vertical (une en haut, une en bas).
- Dague : pointe vers l'avant, **plat de la lame visible de profil**. La prise inversée, lame sous le poing, a été refusée (« ça rend comme la continuité de la main »).
- Bouclier : sa face arrière est **plaquée contre le poing**, face peinte vers l'avant. Il ne doit pas flotter à côté du bras.
- Aucun accessoire ne doit traverser un autre élément : crâne dans le bouclier, lame dans l'avant-bras… Contrôle par mesure (voir `MONSTER_PRODUCTION.md`).

## 8. Couleurs

Couleurs dominantes mesurées dans les textures validées (quantifiées) :

| Famille | Couleurs observées | Où |
|---|---|---|
| Bruns chauds | `#8C643C`, `#643C3C`, `#643C14` | écorce, cuir, bois (tréants 40 à 50 % de la texture) |
| Olives sombres | `#64643C`, `#3C3C14` | peau des gobelins et orcs dans l'ombre, mousse |
| Verts feuille | `#8CDC64`, `#64B464`, `#64B43C` | feuilles, lierre, peau éclairée des gobelins |
| Rouge tissu | `#B41414`, `#8C3C3C` | capuches, écharpes, bannières, rubans |
| Fer | `#8C8C8C`, `#646464` | cerclages, lames |
| Os et crème | `#B4B48C`, `#DCB48C` | masques, pics, crânes |
| Bleus gelée | `#8CB4DC`, `#648CDC`, `#64B4DC` | slimes, cristaux |
| Accents lumineux | cyan (yeux et cœur du tréant), jaune (yeux des gobelins), or (couronnes) | 1 seul point focal par créature |

Règles :
- **Base terreuse désaturée, accents saturés rares.** Le rouge ne dépasse jamais environ 10 % de la surface visible. Le cyan et le jaune lumineux sont réservés au point focal.
- **La peau d'une créature est de la même teinte partout.** Tête, bras et mains ne doivent pas différer (une tête plus vive que le corps a été refusée sur le Roi Orc). On corrige par recoloration HSV sur la teinte moyenne du torse.
- **Variantes élémentaires = même design, autre teinte.** Les slimes lave, plante et champignon sont le slime d'eau décalé en HSV. Seule la coiffe change : feuilles de feu, touffe fournie, chapeau à pois.

## 9. Répartition et densité des détails

- **Densité forte en haut du corps, calme en bas.** Couronne, épaules et torse concentrent trophées, pics, runes et feuilles. Jambes et bas des bras sont plus simples : bandes de tissu, un brassard.
- **Grandes zones de repos** (peau, gelée, planches du bouclier) entre les groupes de détails. La lisibilité vient de ces respirations.
- **Détails répétés en petits groupes impairs :** 3 pics par épaulière, 5 à 7 feuilles par touffe, 6 cristaux en couronne, 2 à 3 champignons par épaule.
- **Détails accrochés à la matière :** champignons qui poussent sur l'écorce, crânes pendus à une corde, feuilles glissées sous les sangles.
- **Le moodboard est plus chargé que ce qu'on peut modéliser.** On garde les 3 à 5 détails les plus identitaires, en gros : pour l'orc, crânes, pics d'os, bannière du dos, losange du bouclier. Les breloques trop petites, qui se lisent mal et flottent, ont été retirées.
- Le moodboard gobelin (`gobelin.webp`) est trop chibi pour notre DA. On n'en garde que l'équipement : capuche et écharpe rouges, lance, bouclier rond, trophées. Les proportions viennent des gobelins validés.

## 10. Visages et yeux

- **Yeux :** soit **lumineux** (cyan sur les tréants et le King Slime, jaune sur les gobelins), soit sombres et **plissés sous des sourcils froncés** (orc). Jamais de gros yeux ronds brillants et innocents, sauf sur le slime de base, avec des ovales verticaux sombres et sans reflet de « kawaii ».
- **Bouche :** grimace, dents serrées, crocs, défenses qui remontent (orc). **Jamais de sourire, jamais de joues roses, jamais de fossettes.** Les générateurs en ajoutent spontanément : ils ont été retirés à la main à chaque fois (gobelin, slime).
- **Nez :** d'orc et de gobelin, large, plat et **humanoïde**. Le groin de cochon a été refusé et a demandé de régénérer toute la tête.
- **Masques :** les tréants n'ont pas de visage mais un **masque en os crème en forme de losange pointu**, avec une spirale brune gravée et deux orbites lumineuses. C'est l'identité de la famille tréant.
- **Oreilles :** longues et pointues chez les gobelins et orcs, souvent percées d'anneaux dorés ou en os.

## 11. Membres, griffes, cornes, végétation, armures

- **Mains :** énormes, poings fermés prêts à tenir une arme. Griffes pâles en bois ou en os, courbes et épaisses (tréants : 3 griffes par main, griffes aussi aux pieds).
- **Pieds :** nus et griffus (gobelins), en racines (tréants) ou en bottes cerclées de fer (orc). Toujours massifs et posés à plat, jamais pointus.
- **Cornes et bois :** courbes, épaisses à la base, ivoire ou bois. Les bois du King Tréant sont ramifiés en plusieurs pointes et couverts de feuilles. Ils sont accrochés au sommet du masque et **inclinés vers l'extérieur** d'environ 20°.
- **Végétation :** feuilles **larges et arrondies en cuillère**, jamais des brins d'herbe (une touffe en brins a été refusée). Lierre qui s'enroule sur les membres. Petites fleurs blanches à cœur jaune. Champignons rouges à pois blancs.
- **Armures :** artisanales et tribales, faites de planches de bois cerclées de fer, d'épaulières en os ou en pierre gravée et de sangles de cuir croisées. Jamais d'armure de plaques propre de chevalier sur un monstre.

## 12. Stylisé mais travaillé : comment on l'obtient

1. **Texture peinte riche sur des formes simples :** le détail fin (veines du bois, rivets, coutures, mousse) est dans la texture, et les formes restent massives.
2. **Accessoires générés à part, puis assemblés.** Un modèle demandé « avec tout » sort simplifié. Le Roi Orc n'est devenu assez riche qu'avec 15 pièces ajoutées : lance-hache, bouclier, crânes, pics, bannière.
3. **Retouches ciblées plutôt que régénération totale :** effacer un sourire, raccorder une teinte de peau, retexturer seulement le corps d'un slime.
4. **Contrôle mesuré** des prises en main, des contacts et des interpénétrations.

## 13. Lisibilité à distance dans Roblox

Les combats se jouent **en arrière-plan, sans zoom caméra**, pendant que le joueur farme. Une créature doit donc se lire à 30 à 60 studs :
- **Contour supérieur unique** : couronne, bois, capuche, cristaux.
- **Un point lumineux** qui attire l'œil : yeux ou cœur.
- **Contraste de valeur** entre le corps (sombre et terreux) et un accent (rouge, cyan, or).
- **Taille relative claire :** petit monstre de 4 à 5, moyen de 8 à 10, boss de 13 à 21.
- **Aucun détail essentiel sous 0,5 stud :** il disparaît à distance et fait « bruit ».

## 14. Ce qui rend une créature « de notre jeu »

Une créature appartient à notre jeu si elle coche au moins 5 de ces points :

1. Silhouette massive, haut du corps lourd, posture voûtée.
2. Texture peinte main avec des matériaux naturels et artisanaux superposés.
3. Palette terreuse avec un accent rouge tissu, cyan ou or.
4. Un point lumineux : yeux ou cœur.
5. Losanges, spirales, crocs ou cornes dans le langage de formes.
6. Matière vivante accrochée au corps : mousse, feuilles, champignons, lierre.
7. Expression hostile, sans sourire.
8. Équipement tribal ou artisanal fait de bois, d'os, de cuir et de fer.

## 15. Ce qui est hors DA

- **Trop enfantin ou chibi :** grosse tête ronde, sourire, joues roses, fossettes, gros yeux brillants, couleurs pastel (gobelin #02 refusé).
- **Trop générique :** gobelin vert en pagne sans équipement identitaire, slime simple sans coiffe ni idée, golem de pierre en cubes, orc « de base » sans trophées ni bannière (premières versions du Roi Orc refusées : « trop léger »).
- **Trop réaliste :** anatomie détaillée, peau pore par pore, métal brillant, proportions humaines normales.
- **Trop simple :** Parts de couleur unie, low-poly à facettes (DA des décors, pas des créatures), aucune couche d'équipement.
- **Mal fini :** accessoires qui flottent, armes à côté de la main, teintes de peau différentes entre la tête et le corps, textures grises ou noires non chargées, couture sombre visible (bord de texture), lueur qui déborde sur le reste du corps.

## 16. Application de cette DA aux personnages jouables

Les héros doivent sembler **sortir du même atelier** que les monstres. Ils ne doivent pas copier l'anatomie des monstres. Ils doivent partager leur **langage** :

- **Mêmes proportions de principe :** haut du corps renforcé, mains et avant-bras forts, jambes plus courtes que la normale, tête légèrement grande. Moins voûtés que les monstres, mais **jamais des proportions humaines réalistes**.
- **Même traitement des volumes :** formes gonflées et arrondies, épaulières et gants surdimensionnés, couches superposées (tissu, cuir, métal, trophée).
- **Mêmes matériaux peints :** bois veiné, cuir sombre, fer riveté usé, tissu épais, os et cristal, avec des textures peintes main et aucun métal chromé.
- **Même logique de couleur :** base terreuse, **un** accent de faction (le bleu royal et l'or du royaume jouent pour les héros le rôle du rouge des gobelins), un point lumineux quand le héros est magique.
- **Même langage de formes :** losanges (emblème du royaume), spirales runiques, pointes et courbes. Les armes des héros répondent à celles des monstres par leur taille exagérée, leurs manches enroulés et leurs pommeaux marqués.
- **Même lisibilité :** contour supérieur identitaire (casque, coiffure, capuche, chapeau de mage), accessoire principal qui prolonge la silhouette.
- **Différence héros et monstres :** posture plus droite et fière, expression déterminée plutôt que hostile, matériaux plus soignés (tissus bordés, métal travaillé, or). Ce sont **les mêmes matériaux**, simplement mieux entretenus.

Le détail par élément (cheveux, vêtements, armures, femmes et hommes, héros puissants) est dans `docs/CHARACTER_ART_DIRECTION.md`.
