# Items 2D

Les items sont des **icônes 2D**, pas des modèles 3D. Ce document dit ce qui existe déjà,
comment la liste est répartie, **où le worker doit poser chaque item créé** et comment produire
une icône.

## 1. État actuel

- **Catalogue de production** : `items_equipment.json` (format des tâches du pipeline, une
  entrée par item). C'est la source de vérité pour l'identifiant, le nom, la rareté, le type
  d'emplacement et l'idée de l'icône (`icon_hook`).
- **Catalogue en jeu** : `src/shared/Config/ItemConfig.lua` (partagé serveur et client). Mêmes
  identifiants, noms, raretés (Id de `RarityConfig`) et emplacements que la vitrine, plus l'icône
  livrée (`Icon`, `nil` tant qu'elle n'existe pas). C'est ce module que liront la Sacoche et l'écran
  de récompenses. Test : `./tools/test-items.ps1 -LuauPath <chemin-vers-luau.exe>` (répartition du
  § 2).
- **Aucun système d'items en jeu** pour l'instant : `PlayerData` ne stocke que les monnaies,
  les héros, l'équipe, le royaume, les quêtes et les réglages
  (`src/shared/Types/PlayerDataTypes.lua`). Les statistiques, le stockage et l'obtention des
  items restent à définir côté gameplay.
- La **Sacoche** du joueur (`HeroBarController`, PR #44) prévoit déjà les onglets
  **Équipement** et **Ressources**, encore vides (« Bientôt disponible »).
- Les règles visuelles viennent du design system UI : cartes et slots (§ 6), icônes (§ 7).

## 2. Répartition du catalogue

**100 items, tous des équipements** (`item_001` à `item_100`, `"type": "item"`). Aucune
ressource pour l'instant.

Les identifiants suivent la **rareté croissante**, en 10 paliers contigus :

| Rareté | Items | Nombre |
| --- | --- | --- |
| Commun | 001 – 004 | 4 |
| Peu commun | 005 – 010 | 6 |
| Rare | 011 – 020 | 10 |
| Épique | 021 – 034 | 14 |
| Légendaire | 035 – 052 | 18 |
| Mythique | 053 – 070 | 18 |
| Maudit | 071 – 082 | 12 |
| Suprême | 083 – 090 | 8 |
| Calamité | 091 – 096 | 6 |
| Transcendant | 097 – 100 | 4 |

Types d'emplacement (`slot_type`) : arme `weapon` 26, relique `relic` 21, accessoire
`accessory` 17, armure `armor` 15, casque `helmet` 14, bottes `boots` 5, gants `gloves` 2.

La rareté des items est **celle du catalogue**. On ne l'invente pas et on ne la modifie pas.
Ses couleurs ne sont pas encore définies dans `UITheme` : ne pas en créer dans les icônes ni
dans les cartes (cadre neutre `Ink`, comme les héros).

## 3. Où poser les items créés (directives pour le worker)

**Règle : chaque item créé est posé dans la vitrine `Inventaire` de la place Studio « test »,
dans son emplacement réservé. Un item qui n'y est pas n'est pas livré.**

Plus tard, le même item s'affichera en jeu dans la **Sacoche** (onglet Équipement) et sur
l'**écran de récompenses** (#9). Ces écrans liront le catalogue ; le worker n'a rien à y faire.

### Vitrine `Inventaire`

`Workspace.Bestiaire.Inventaire`, à gauche de la section Héros du Bestiaire : un grand panneau
en bois « Équipement · 100 items », **une rangée par rareté**, dans l'ordre du tableau § 2.
Les 100 emplacements existent déjà, avec nom et attributs pré-remplis depuis le catalogue.

Correspondance tâche → emplacement :

```
"target_studio_slot": "Items #NNN [Rareté]"
  → Workspace.Bestiaire.Inventaire.Equipement.Panneau.Affichage.Fond.Emplacements.Item_NNN
```

Exemple : `item_037` (« Items #037 [Légendaire] ») →
`…Emplacements.Item_037`, rangée Légendaire.

Chaque `Item_NNN` est une carte standard de la Sacoche :

| Élément | État | Le worker fait |
| --- | --- | --- |
| `Illustration.Icone` (ImageLabel) | vide | `Image` = `rbxassetid://…` de l'icône |
| attribut `AssetId` | vide | même identifiant d'asset que `Icone.Image` |
| `Nom` (TextLabel) | rempli | rien (corriger seulement s'il diffère du catalogue) |
| attributs `ItemId`, `Index`, `Rarete`, `SlotType` | remplis | rien |

Interdits : déplacer, renommer, supprimer ou réordonner un emplacement ; poser un item dans
l'emplacement d'un autre ; changer la taille des cartes ; ajouter une couleur de rareté. Si un
item est refait, remplacer seulement `Icone.Image` et `AssetId` ; l'ancienne icône reste
référencée dans la tâche (`notes`).

Captures pour la review : la carte seule (de près) et la rangée de sa rareté (pour comparer
avec ses voisines).

Quand de nouveaux items (ou des ressources) seront ajoutés au catalogue, on ajoute leurs
emplacements à la vitrine (nouvelle rangée ou nouveau panneau à côté) **avant** de lancer
leurs tâches.

## 4. Produire une icône

Règles du design system (§ 7), résumées :

- Une icône est **un petit objet du monde**, pas un pictogramme : formes chunky arrondies,
  couleurs de la palette matière (bois, sable, pierre, or…), lumière chaude venant d'en haut à
  gauche, légère ombre propre.
- **Silhouette lisible à 32 px** : l'objet occupe environ 80 % du cadre, aucun détail sous 6 %,
  une couleur dominante + un accent.
- **Contour `Ink` (`#1F1A17`) cuit dans l'image**, environ 6 % de la taille.
- Vue de **trois quarts**, **fond transparent**, PNG **512 × 512** (256 minimum).
- Partir de l'`icon_hook` de la tâche : c'est l'idée principale à rendre lisible.
- Interdits : emoji, icônes plates génériques, traits fins, style futuriste, photoréalisme.

Nommage du fichier source : `<item_id>.png` (ex. `item_037.png`).

## 5. Contrôle avant de livrer un item

1. L'icône est dans **son** emplacement `Item_NNN`, `Icone.Image` et `AssetId` remplis.
2. Elle se lit de loin (rangée entière) et de près (carte seule).
3. Elle a le même rendu que ses voisines : contour, lumière, saturation, taille de l'objet.
4. Elle correspond à l'`icon_hook` et au `slot_type` du catalogue.
5. Aucune couleur de rareté ni statistique inventée dans l'image.

## 6. Vitrine et catalogue du code

`tools/studio-items-vitrine.luau` (Studio EDIT, Rojo connecté, lecture seule) compare la vitrine à
`ItemConfig` : emplacement présent, attributs, `Nom`, `Icone.Image` égal à `AssetId`. Il imprime les
écarts, puis les lignes `item(...)` à reporter dans `ItemConfig.lua` pour les icônes livrées
(cinquième argument `rbxassetid://…`). Le lancer après chaque lot d'icônes, reporter ces lignes
dans une PR, et ne rien livrer tant qu'il signale un écart.

Un nouvel item s'ajoute **dans le même ordre** aux deux endroits : son emplacement dans la vitrine
(§ 3) et sa ligne dans `ItemConfig.lua` ; mettre à jour la répartition du § 2 et le test.
