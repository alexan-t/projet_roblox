---
name: roblox-character-artist
description: Première version du workflow de création d'un personnage jouable (héros) dans Roblox Studio (MCP), dans exactement la même direction artistique que les monstres et boss validés. Dérivé uniquement de ART_DIRECTION.md et CHARACTER_ART_DIRECTION.md, sans aucun personnage existant comme référence.
---

# Roblox character artist (v1)

**Aucun personnage existant du jeu n'est une référence** : ni `Heros_Base`, ni les mannequins R15, ni les avatars Roblox standards. Les seules références sont les monstres et boss validés, et les deux documents de DA. Cette règle tient jusqu'à ce que l'utilisateur désigne explicitement un héros comme référence.

## 1. Lire

1. Le brief : classe, genre, niveau de puissance, arme, éléments imposés.
2. `docs/ART_DIRECTION.md` (surtout § 3 à 13 et § 16).
3. `docs/CHARACTER_ART_DIRECTION.md` en entier.
4. `docs/MONSTER_PRODUCTION.md` : les étapes de construction et les « Outils » s'appliquent à l'identique.

## 2. Inspecter

1. Studio en mode Edit sur la place `test`.
2. Relever la taille et le découpage de `KingTreant`, `RoiOrc` et `GobLanceT_A` : ce sont les points de comparaison de style et d'échelle. On compare le **style** à ces références, pas leur anatomie.
3. Une capture de ces références si besoin, puis réinitialiser la caméra.

## 3. Concevoir

- **Idée visuelle principale** en une phrase.
- **Contour supérieur de classe** (casque, chapeau, capuche, coiffure) et arme qui prolonge la silhouette.
- **Proportions :** hauteur d'environ 6 studs (jusqu'à 7,5 pour un héros très puissant), épaules de 1,3 à 1,5 fois les hanches, grandes mains, jambes à environ 40 % de la hauteur, tête d'environ 1/5.
- **Matériaux et palette :** base terreuse, accent bleu royal et or du royaume, un point lumineux si le héros est magique.
- **Liste des couches** : tunique, cuir, armure, accessoires.

## 4. Construire

1. Deux variantes en parallèle (`generate_mesh`, `async: true`) avec la segmentation `["head", "torso", "left arm", "right arm", "left leg", "right leg", "<arme>", "<bouclier ou accessoire>"]`.
   Base de prompt : « Stylized hand-painted fantasy hero, same art style as a chunky painterly forest treant and orc warlord: rich painterly textures, earthy palette with royal blue and gold accents, heroic proportions with broad shoulders, big hands and gauntlets, oversized shoulder pads, slightly short legs, thick chunky readable silhouette, not realistic, not cute, no smile, no blush. » Puis la description de la classe.
2. Armes, bouclier et éléments qui dépassent générés à part si la génération les simplifie, puis assemblés par mesure (centre du poing, accroches par raycast).
3. Vérifier que la peau a une teinte unique (tête, cou et mains), et que les cheveux forment de grosses mèches (sinon retexturer la tête).

## 5. Capturer et contrôler

1. Captures de `VISUAL_QA.md` § 1, **plus une capture côte à côte avec `KingTreant` et `GobLanceT_A`** (test de `CHARACTER_ART_DIRECTION.md` § 14).
2. Grille `VISUAL_QA.md` : PASS ou FIX. En cas de FIX, corriger, recapturer, puis repasser la grille.
3. Réinitialiser la caméra après les captures.

## 6. Rendre compte

Verdict, emplacement, taille, idée visuelle, comparaison avec les références, limites restantes. Présenter les deux variantes si elles sont toutes deux valables.

## Interdits

- Prendre un personnage existant comme référence sans demande explicite.
- Proportions réalistes, style avatar Roblox, pièces en couleurs unies, métal chromé.
- Sourire marqué, joues roses, style chibi.
- Terminer sans capture ni PASS.
