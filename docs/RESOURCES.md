# Ressources 2D

Les ressources sont des **icônes 2D**, comme les items (`docs/ITEMS.md`, PR #52) : même carte, même
fabrication d'icône, même vitrine `Inventaire`. Ce document dit ce qui existe, comment les 60
ressources sont réparties, **où le worker pose chaque icône** et comment la produire.

## 1. État actuel

| | État |
| --- | --- |
| Catalogue défini (60 ressources, `ResourceConfig`, `resources.json`) | **OUI** |
| Icônes 2D livrées (AssetId publié, vitrine remplie) | **OUI : 60/60** ; chaque ressource a un `Icon` publié et un PNG 512 × 512 validé (bilan : `docs/RESOURCE_ICONS_QA.md`) |
| Stockage dans `PlayerData` | **NON** |
| Obtention (récompenses, butin, récolte) | **NON** |
| Recettes, crafting | **NON** |

Catalogue défini ≠ asset 2D livré ≠ système de jeu implémenté. Les ressources n'ont **aucune
rareté**.

- **Catalogue de production** : `automation/catalogues/resources.json`, au format des tâches du
  pipeline (`automation/TASK_FORMAT.md`), une tâche par ressource. Source de vérité pour
  l'identifiant, le nom, la famille et l'idée de l'icône (`icon_hook`). Ce fichier n'est pas la
  file `automation/tasks.json` : on y copie les tâches par lots, une fois la vitrine en place (§ 3).
- **Catalogue en jeu** : `src/shared/Config/ResourceConfig.lua` (partagé serveur et client). Mêmes
  identifiants, noms et familles, plus l'icône livrée (`Icon`, `nil` tant qu'elle n'existe pas).
  C'est ce module que liront l'onglet **Ressources** de la Sacoche et l'écran de récompenses quand le stockage / loot de #72 sera implémenté.
- **Aucun système de ressources en jeu** pour l'instant : pas de stockage dans `PlayerData`
  (`src/shared/Types/PlayerDataTypes.lua`), pas d'obtention (`RewardConfig`), pas de recette. Ces
  choix restent à faire côté gameplay. Les monnaies (or, gemmes, tickets) **ne sont pas** des
  ressources : elles gardent leurs icônes de monnaie (`UI_DESIGN_SYSTEM.md` § 7).
- Tests : `node tests/resources.test.mjs` (sans Luau ni Studio : compare `ResourceConfig` au tableau
  du § 2 et à `resources.json`) et `./tools/test-resources.ps1 -LuauPath <chemin-vers-luau.exe>`.

## 2. Répartition du catalogue

**60 ressources** (`resource_001` à `resource_060`, `"type": "resource"`), **6 familles de 10**,
tirées de ce que le monde et ses créatures fournissent réellement : les tréants, les slimes, la
faction gobelins et orcs, les rochers et la rivière de la map, la magie des cristaux, le royaume.

| Famille | Id | Ressources | Nombre |
| --- | --- | --- | --- |
| Forêt et tréants | `foret` | 001 – 010 | 10 |
| Slimes | `slime` | 011 – 020 | 10 |
| Gobelins et orcs | `horde` | 021 – 030 | 10 |
| Pierres et minerais | `mine` | 031 – 040 | 10 |
| Cristaux et magie | `arcane` | 041 – 050 | 10 |
| Royaume et artisanat | `royaume` | 051 – 060 | 10 |

Les trois premières familles finissent par une pièce de boss de référence : `resource_010` (Bois du
King Tréant), `resource_020` (Couronne Fondue, Slime King) et `resource_030` (Corne du Roi Orc).

**Les ressources n'ont aucune rareté.** Ne pas en inventer, ni dans le catalogue, ni dans les
icônes, ni sur les cartes (cadre neutre `Ink`). Si le gameplay en demande une plus tard, elle sera
décidée par l'équipe et ajoutée ici d'abord.

## 3. Où poser les ressources créées (directives pour le worker)

**Règle : chaque icône de ressource est posée dans la vitrine `Inventaire` de la place Studio
« test », dans son emplacement réservé. Une ressource qui n'y est pas n'est pas livrée.**

### Vitrine `Ressources`

`Workspace.Bestiaire.Inventaire.Ressources` : un second panneau en bois « Ressources · 60
ressources », à côté du panneau `Equipement`, **une rangée par famille** dans l'ordre du § 2.

Il est créé une fois par `tools/studio-resources-vitrine.luau` (Studio EDIT, Rojo connecté) : le
script clone le panneau `Equipement` (mêmes cartes, mêmes styles), le pose à côté sur le premier
côté libre, remplace les rangées de rareté par les familles et pré-remplit les 60 cartes. Une
seule étape d'annulation (Ctrl+Z) ; il ne remplace jamais une vitrine existante. Les 6 rangées
n'occupent que le haut du panneau (le panneau `Equipement` en a 10). Après création : capture,
contrôle `VISUAL_QA.md`, et prolonger au besoin `Dallage` et `Bordure` de l'`Inventaire` à la main.

Correspondance tâche → emplacement :

```
"target_studio_slot": "Ressources #NNN [Famille]"
  → Workspace.Bestiaire.Inventaire.Ressources.Panneau.Affichage.Fond.Emplacements.Ressource_NNN
```

Exemple : `resource_036` (« Ressources #036 [Pierres et minerais] ») → `…Emplacements.Ressource_036`,
rangée Pierres et minerais.

Chaque `Ressource_NNN` est une carte standard de la Sacoche :

| Élément | État | Le worker fait |
| --- | --- | --- |
| `Illustration.Icone` (ImageLabel) | vide | `Image` = `rbxassetid://…` de l'icône |
| attribut `AssetId` | vide | même identifiant d'asset que `Icone.Image` |
| `Nom` (TextLabel) | rempli | rien (corriger seulement s'il diffère du catalogue) |
| attributs `ResourceId`, `Index`, `Famille` | remplis | rien |

Interdits : déplacer, renommer, supprimer ou réordonner un emplacement ; poser une ressource dans
l'emplacement d'une autre ; changer la taille des cartes ; ajouter une couleur de rareté. Si une
ressource est refaite, remplacer seulement `Icone.Image` et `AssetId` ; l'ancienne icône reste
référencée dans la tâche (`notes`).

Captures pour la review : la carte seule (de près) et la rangée de sa famille (pour comparer avec
ses voisines).

## 4. Produire une icône

Mêmes règles que les items (`UI_DESIGN_SYSTEM.md` § 7, `ITEMS.md` § 4) :

- Une icône est **un petit objet du monde**, pas un pictogramme : formes chunky arrondies,
  couleurs de la palette matière, lumière chaude venant d'en haut à gauche, légère ombre propre.
- **Silhouette lisible à 32 px** : l'objet occupe environ 80 % du cadre, aucun détail sous 6 %,
  une couleur dominante + un accent.
- **Contour `Ink` (`#1F1A17`) cuit dans l'image**, environ 6 % de la taille.
- Vue de **trois quarts**, **fond transparent**, PNG **512 × 512** (256 minimum).
- Partir de l'`icon_hook` de la tâche : c'est l'idée principale à rendre lisible.
- Interdits : emoji, icônes plates génériques, traits fins, style futuriste, photoréalisme.

Propre aux ressources, repris de la DA des créatures (`ART_DIRECTION.md` § 7, § 8) :

- **Matières des créatures validées** : écorce brun chaud avec mousse et lierre, os et ivoire
  crème, cuir brun sombre, fer gris usé et riveté (jamais chromé), tissu rouge déchiré, pierre
  grise gravée de losanges et de spirales, gelée claire en haut et foncée en bas avec gros reflet
  blanc, cristal cyan, or.
- **Un seul point lumineux** au plus (rune, cœur, cristal), comme les créatures. La plupart des
  ressources n'en ont pas.
- **Base terreuse désaturée, accents rares** : le rouge reste un accent ; le cyan et l'or
  lumineux sont réservés au point focal.
- Les trophées de boss (`resource_010`, `020`, `030`) reprennent **une pièce reconnaissable** du
  boss (bois ramifié, couronne, corne), sans copier le modèle entier.
- Une famille se lit comme un ensemble : les gelées sont le même objet décalé en teinte, comme les
  slimes élémentaires (« même design, autre teinte »).

Nommage du fichier source : `<resource_id>.png` (ex. `resource_036.png`).

## 5. Contrôle avant de livrer une ressource

1. L'icône est dans **son** emplacement `Ressource_NNN`, `Icone.Image` et `AssetId` remplis.
2. Elle se lit de loin (rangée entière) et de près (carte seule).
3. Elle a le même rendu que ses voisines et que les icônes d'items : contour, lumière, saturation,
   taille de l'objet.
4. Elle correspond à l'`icon_hook` et à la famille du catalogue.
5. Aucune couleur de rareté, statistique ou quantité inventée dans l'image.

## 6. Vitrine et catalogue du code

`tools/studio-resources-vitrine.luau`, relancé après chaque lot d'icônes, compare la vitrine à
`ResourceConfig` (sans rien modifier une fois la vitrine créée) : emplacement présent, attributs,
`Nom`, `Icone.Image` égal à `AssetId`. Il imprime les écarts, puis les lignes `resource(...)` à
reporter dans `ResourceConfig.lua` pour les icônes livrées (quatrième argument `rbxassetid://…`).
Reporter ces lignes dans une PR ; ne rien livrer tant qu'il signale un écart.

Une nouvelle ressource s'ajoute **dans le même ordre** aux trois endroits : sa tâche dans
`resources.json`, sa ligne dans `ResourceConfig.lua` et son emplacement dans la vitrine ; mettre à
jour la répartition du § 2 et les tests.
