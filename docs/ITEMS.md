# Items 2D

Les items sont des **icônes 2D**, pas des modèles 3D. Ce document dit ce qui existe déjà,
comment la liste est répartie, **où le worker doit poser chaque item créé** et comment produire
une icône.

## 1. État actuel

| | État |
| --- | --- |
| Catalogue défini (100 items, `ItemConfig`) | **OUI** |
| Icônes 2D livrées (AssetId publié, vitrine remplie) | **OUI : 100 / 100** : 58 du partenaire (PR #74, `item_035` à `item_044`, `item_053` à `item_100`) et 42 produites ici (`item_001` à `item_034`, `item_045` à `item_052`, PNG dans `assets/icons/items/`) |
| Stockage dans `PlayerData` | **OUI (#72, V1 serveur)** : `PlayerData.Inventory.Equipment`, une entrée par exemplaire (`{ ItemId, UpgradeLevel = 0 }`, clé = `ItemInstanceId` « I_T… ») |
| Obtention (récompenses, butin) | **OUI (#72, V1 serveur)** : loot de victoire de la Zone 1, `LootConfig` (valeurs **ALPHA 0.0.2 PROVISOIRE**) ; voir `docs/REWARDS.md` § Loot |
| Équipement des héros et statistiques | **OUI (#73, V1)** : un objet s'équipe sur un **exemplaire** de héros (`HeroEquipment`), bonus plats PV / ATK au combat ; voir § 7 (valeurs **ALPHA 0.0.2 PROVISOIRE**, #112) |
| Forge, amélioration (`UpgradeLevel`) | **NON** : `UpgradeLevel` stocké sans aucun effet |

Catalogue défini ≠ asset 2D livré ≠ système de jeu implémenté.

- **Provenance du catalogue** : il n'existe **pas** de catalogue de production
  `items_equipment.json` dans le dépôt (introuvable, voir la PR #52). Identifiants, noms, raretés et
  emplacements ont été relevés sur la vitrine `Workspace.Bestiaire.Inventaire` du snapshot
  `studio/sandbox/partner_sandbox_v4.rbxl` (attributs `ItemId`, `Index`, `Rarete`, `SlotType` et
  texte `Nom` des cartes). Ce snapshot est **historique** : la référence des assets est la vitrine
  de la **DEV Studio actuelle**, contrôlée par `tools/studio-items-vitrine.luau` (§ 6).
- **Catalogue de production** : `automation/catalogues/items.json`, au format des tâches du
  pipeline (`automation/TASK_FORMAT.md`, `"type": "item"`), une tâche par icône hors de la
  livraison du partenaire (PR #74, 58 icônes `item_035`–`044` et `item_053`–`100`), soit
  `item_001`–`034` et `item_045`–`052`. Les 42 sont `done` : PNG dans `screenshots`, review PASS
  dans `automation/reviews/<item_id>_iteration_00.json`, AssetId dans `notes`. Source de vérité pour l'idée de
  l'icône (`icon_hook`) ; nom et emplacement (`slot_type`) recopiés de `ItemConfig`, rareté seulement
  dans `target_studio_slot`. Ce fichier n'est pas la file `automation/tasks.json` : on y copie les
  tâches par lots.
- **Catalogue en jeu** : `src/shared/Config/ItemConfig.lua` (partagé serveur et client). Mêmes
  identifiants, noms, raretés (Id de `RarityConfig`) et emplacements que la vitrine, plus l'icône
  livrée (`Icon`, `nil` tant qu'elle n'existe pas). C'est ce module que liront la Sacoche et l'écran
  de récompenses. Test : `./tools/test-items.ps1 -LuauPath <chemin-vers-luau.exe>` (répartition du
  § 2). Sans Luau ni Studio : `node tests/items-vitrine.test.mjs` compare aussi `ItemConfig` au
  tableau du § 2 et, comme **contrôle historique**, à la vitrine du snapshot
  `studio/sandbox/partner_sandbox_v4.rbxl` (il ne prouve pas l'état de la DEV actuelle).
- **Possession et loot (#72, V1 serveur)** : les catalogues existent déjà (100 items, 7 emplacements, 10 raretés) et
  **ne sont pas réinventés** : le gameplay n'ajoute, ne renomme et ne réordonne aucun `ItemId`, rareté ni emplacement ; il les
  **référence**. Un équipement possédé est une **instance** (`ItemInstanceId` unique généré par le serveur, patron `HeroService.newId`,
  préfixe `I_T`) qui pointe vers un `ItemId` du catalogue : plusieurs exemplaires d'un même `ItemId` sont autorisés et ne sont **jamais
  fusionnés**. `UpgradeLevel = 0` est stocké dès V1 sans aucun effet ; pas d'affixe, pas d'item hors catalogue. Règles pures :
  `src/server/Inventory/InventoryRules.lua` ; vue en lecture seule : `GetInventory` / `InventoryChanged` (`InventoryService`, aucun
  remote d'écriture). Un exemplaire ne s'équipe que sur un seul héros à la fois (#73, § 7). Tirage : rareté d'abord, puis item uniforme parmi les items
  de cette rareté ; Zone 1 Normal ⊂ Commun / Peu commun / Rare, Élite ⊂ Rare / Épique / Légendaire, jamais au-dessus de Légendaire.
- **Choix PROVISOIRES et points ouverts** (ALPHA 0.0.2, à arbitrer après simulation, voir `docs/REWARDS.md` § Loot) : plafond de
  **500 instances** (au-delà, l'équipement n'est pas créé et `Overflow = true`) ; équipement garanti du premier clear de 1-5 Normal ;
  pas de poids par `ItemId` ; `ItemPool` (équipement aléatoire non listé dans « Butin possible »). **Constat sur le catalogue** : le
  pool Normal de la Zone 1 ne contient aucun `gloves` et un seul `armor` / `boots`, et le pool Élite un seul `gloves` / `boots` ; un 7/7
  emplacements est donc impossible en Normal et très lent en Élite, quelles que soient les chances (`tools/simulate-loot.ps1` le signale).
- La **Sacoche** du joueur (`HeroBarController`, PR #44) prévoit les onglets **Équipement** et **Ressources** ; leur affichage est
  fourni côté client (#72, UI) à partir de `GetInventory`.
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
Arbitrage du 18 octobre (`docs/UI_DESIGN_SYSTEM.md` § 2, « Rendu des raretés ») : les items
prennent **les couleurs des héros** (`UITheme.Rarity`, aucune seconde palette), posées sur la
carte (zone d'illustration teintée et cerclée, plus le repère de forme) et **jamais dans
l'icône**. Tant que la PR #61 n'est pas fusionnée, les cartes gardent le cadre neutre `Ink` et
personne n'ajoute de couleur de rareté à la main (ni dans les icônes, ni dans la vitrine).

## 3. Où poser les items créés (directives pour le worker)

**Règle : chaque item créé est posé dans la vitrine `Inventaire` de la place Studio « test »,
dans son emplacement réservé. Un item qui n'y est pas n'est pas livré.**

Plus tard, le même item s'affichera en jeu dans la **Sacoche** (onglet Équipement) et sur
l'**écran de récompenses** (#9). Ces écrans liront le catalogue ; le worker n'a rien à y faire.

### Vitrine `Inventaire`

`Workspace.Bestiaire.Inventaire`, à gauche de la section Héros du Bestiaire : un grand panneau
en bois « Équipement · 100 items », **une rangée par rareté**, dans l'ordre du tableau § 2.
Les 100 emplacements existent déjà, avec nom et attributs remplis (ce sont eux qui ont servi à
écrire `ItemConfig`, voir § 1).

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
- Partir de l'`icon_hook` de la tâche (`automation/catalogues/items.json`, § 1) : c'est l'idée
  principale à rendre lisible. Sans tâche, pas de production.
- Interdits : emoji, icônes plates génériques, traits fins, style futuriste, photoréalisme.

Nommage du fichier source : `<item_id>.png` (ex. `item_037.png`), versionné dans
`assets/icons/items/`. `tools/icon-render.mjs` en produit le PNG à partir de deux captures Studio
de l'objet (fond transparent, cadrage à 80 %, contour `Ink` cuit) et dessine la planche de contrôle
à 128 et 32 px (`sheet`) ; l'objet 3D se construit dans `Workspace.AtelierIcones`, vidé après le lot.

Les images publiées n'apparaissent que dans les expériences autorisées par leur propriétaire. Toute
icône définitive est publiée sous le propriétaire de l'expérience (compte `nxtoma`) : règle et
contrôle dans `docs/ASSET_OWNERSHIP.md`.

## 5. Contrôle avant de livrer un item

1. L'icône est dans **son** emplacement `Item_NNN`, `Icone.Image` et `AssetId` remplis.
2. Elle se lit de loin (rangée entière) et de près (carte seule).
3. Elle a le même rendu que ses voisines : contour, lumière, saturation, taille de l'objet.
4. Elle correspond à l'`icon_hook` de sa tâche et au `SlotType` de `ItemConfig`.
5. Aucune couleur de rareté ni statistique inventée dans l'image.

## 6. Vitrine et catalogue du code

`tools/studio-items-vitrine.luau` (Studio EDIT, Rojo connecté, lecture seule) compare la vitrine à
`ItemConfig` : emplacement présent, attributs, `Nom`, `Icone.Image` égal à `AssetId`. Il imprime les
écarts, puis les lignes `item(...)` à reporter dans `ItemConfig.lua` pour les icônes livrées
(cinquième argument `rbxassetid://…`). Le lancer après chaque lot d'icônes, reporter ces lignes
dans une PR, et ne rien livrer tant qu'il signale un écart.

Un nouvel item s'ajoute **dans le même ordre** aux deux endroits : son emplacement dans la vitrine
(§ 3) et sa ligne dans `ItemConfig.lua` ; mettre à jour la répartition du § 2 et le test.

## 7. Équipement V1 (#73) — ALPHA 0.0.2 PROVISOIRE

**Boucle** : victoire → objet dans la Sacoche → héros choisi → objet équipé → PV / ATK de CET exemplaire augmentés au
combat suivant (Normal et Élite) → retrouvé tel quel après reconnexion.

- **Données** : `PlayerData.HeroEquipment = { [HeroInstanceId] = { [SlotType] = ItemInstanceId } }`, clé fixe ajoutée aux
  anciens profils par Reconcile (aucune migration, `DataVersion` reste 4). L'équipement appartient à l'**exemplaire** de héros :
  deux exemplaires d'un même `HeroId` portent des objets différents.
- **Invariants** : un `ItemInstanceId` n'est porté que par **un** héros, dans **un** slot, qui est le `SlotType` de son `ItemId`
  (lu dans `ItemConfig`, jamais choisi par le client). Équiper sur un slot occupé **remplace** : l'ancien objet reste dans
  l'inventaire, disponible. Retirer libère le slot, l'objet reste. Un objet porté par un autre héros est **refusé** (le retirer
  d'abord). Aucun objet n'est jamais créé, supprimé ni dupliqué par l'équipement.
- **Données invalides** (héros supprimé, objet absent ou inconnu, slot incompatible, objet porté deux fois) : ignorées à la lecture
  et nettoyées au chargement du joueur et avant chaque mutation (`EquipmentRules.normalize`) ; en cas de doublon, le premier porteur
  dans l'ordre `HeroInstanceId` croissant puis ordre des slots garde l'objet. Un héros supprimé libère ses objets.
- **Bonus** (`src/server/Config/EquipmentConfig.lua`) : plats, `MaxHealth` et `AttackDamage` seulement, selon **slot × rareté**
  (pas par `ItemId`) : `arrondi(base du slot × multiplicateur de rareté)`. `UpgradeLevel` sans effet.

| Slot | Base (Commun) |
| --- | --- |
| Arme (`weapon`) | +3 ATK |
| Casque (`helmet`) | +20 PV |
| Armure (`armor`) | +30 PV |
| Gants (`gloves`) | +2 ATK |
| Bottes (`boots`) | +15 PV |
| Accessoire (`accessory`) | +10 PV, +1 ATK |
| Relique (`relic`) | +15 PV, +2 ATK |

| Rareté | Commun | Peu commun | Rare | Épique | Légendaire | Mythique | Maudit | Suprême | Calamité | Transcendant |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Multiplicateur | 1 | 1,5 | 2 | 3 | 4 | 5 | 6 | 7,5 | 9 | 11 |

  Exemples : Lame des Ronces (Rare, arme) +6 ATK ; Cuirasse du Domaine (Peu commun, armure) +45 PV ; Cisaille des Portes Oubliées
  (Légendaire, arme) +12 ATK. Repères : Épéiste niveau 1 = 150 PV / 16 ATK. Ces valeurs sont **provisoires** jusqu'à
  l'équilibrage #112 ; le constat du § 1 tient toujours (aucun `gloves` en Zone 1 Normal : un 7/7 n'est pas garanti en Zone 1).
- **Ordre de calcul** (serveur) : profil de combat → niveau (#68, +5 % / niveau) → **+ bonus plats d'équipement** → stats finales de
  l'exemplaire. Rien d'autre ne change (cadence, portée, vitesse, énergie, ultime). Voir `docs/COMBAT.md` et `docs/HEROES.md`.
- **Serveur** : règles pures `src/server/Inventory/EquipmentRules.lua` ; seul point d'écriture `EquipmentService`, remote
  `EquipmentAction` : `("Equip", HeroInstanceId, ItemInstanceId)` et `("Unequip", HeroInstanceId, SlotType)`. Refus : héros ou objet
  inconnu / non possédé (dont ceux d'un autre joueur), slot inconnu, objet porté par un autre héros, emplacement vide, **combat en
  cours** (roster figé au lancement), rafale (0,2 s, `ActionCooldown`), argument en trop. Aucune stat n'est acceptée du client.
- **Vues** : `GetHeroes` / `HeroesChanged` donnent par exemplaire `MaxHealth` / `AttackDamage` **finales**, `BaseMaxHealth` /
  `BaseAttackDamage` (niveau seul), `EquipmentBonus` et `Equipment` ; `GetInventory` / `InventoryChanged` donnent par objet `Bonus`,
  `EquippedBy` et `EquippedSlot`. La Sacoche n'en fait que l'arithmétique d'affichage (comparaison avant / après).
- **Hors V1** : Forge, `UpgradeLevel`, affixes, sets, fusion, recyclage, vente, échange, apparence 3D sur le héros.
- **Tests** : `./tools/test-equipment.ps1` (règles et service), `./tools/test-heroes.ps1` (roster et vue), `./tools/test-combat.ps1`
  (stats équipées en Normal et Élite), `./tools/test-security.ps1`.
- **Recette Studio** : toujours sur un store de recette (`StoreRecette`, `docs/SECURITY.md` § Recettes Studio). En Studio
  seulement, `ServerStorage.DebugData:Invoke(player, "AddItem", "item_004")` ajoute un exemplaire de test (même chemin que le
  loot : catalogue, plafond) pour jouer remplacement, doublons et Sacoche pleine sans attendre un drop.
- **Config invalide** : `EquipmentRules.activeConfig` renvoie `nil` ; aucun bonus n'est alors appliqué (roster, vues) et
  `EquipmentService` refuse les mutations : une erreur de config ne fausse jamais un combat.
