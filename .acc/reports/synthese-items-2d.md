# Synthèse : catalogue d'items et vitrine d'inventaire (docs/ITEMS.md)

Mission : implémenter le catalogue d'items et la vitrine d'inventaire décrits dans `docs/ITEMS.md` (branche `docs/items-2d`).
Branche de travail : `acc/mission-34b86c17`, base `de6d7c6`.

## Ce qui a été fait

Commits `3755178..2c94a69`, 10 fichiers et 1020 lignes ajoutées :

- `3755178` docs : `docs/ITEMS.md` et 3 lignes de `docs/UI_DESIGN_SYSTEM.md` reprises de `origin/docs/items-2d`. Le cherry-pick a été refusé, donc report à la main. La branche d'origine part d'un develop ancien (PR #43).
- `75be4e0` : `src/shared/Config/ItemConfig.lua` contient les 100 équipements `item_001`..`item_100`. Il expose `Items`, `Ordered`, `SlotTypes`, `SlotTypeNames` et `slotName()`. `Icon` vaut `nil` tant que l'icône n'est pas livrée. S'y ajoutent `src/server/Tests/ItemConfig.spec.lua` et `tools/test-items.ps1`.
- `4095a4f` : `tools/studio-items-vitrine.luau` compare en lecture seule la vitrine Inventaire de Studio à ItemConfig et produit les lignes `item(...)` à reporter quand des icônes sont livrées.
- `2c94a69` : `tests/items-vitrine.test.mjs` est un test Node. Il lit directement le `.rbxl` binaire et vérifie ItemConfig contre ITEMS.md § 2, RarityConfig et les 100 cartes `Item_NNN`. Ajout d'un renvoi vers ce test dans `docs/ITEMS.md` § 1.

Source des données : `items_equipment.json` est introuvable (ni dans le dépôt, ni sur le Bureau). Le catalogue a été extrait des cartes `Item_NNN` du snapshot `studio/sandbox/partner_sandbox_v4.rbxl`, en lisant les attributs ItemId, Index, Rarete, SlotType et Nom.

## Vérification

- `node tests/items-vitrine.test.mjs` : **9/9 PASS**. Un test d'échec volontaire (modification temporaire de `item_037`, puis restauration) a bien fait échouer 4 contrôles.
- Relecture (#4) : catalogue, tests et docs conformes à ITEMS.md (paliers de rareté, répartition, types d'emplacement 26/21/17/15/14/5/2). Ni secret, ni migration, ni changement de PlayerData. ItemConfig n'est chargé par aucun service.
- Verdict de la relecture : **FIX** (voir le bloquant plus bas).

## Ce qui reste

1. **Bloquant avant publication** : le commit `c0634fc` suit encore `.acc/tmp/gen.cjs`, `.acc/tmp/parse.cjs` et `.acc/tmp/items.lua`. Ce sont des fichiers de travail, qu'il faut retirer de l'index avec `git rm --cached .acc/tmp/*` puis un commit, ou exclure de la publication. Cette tâche (#5) n'a pas le droit de le faire, car elle est limitée à `.acc/reports/`.
2. Le test Luau `tools/test-items.ps1` (ItemConfig.spec.lua) n'a jamais été lancé : luau n'est pas installé et PowerShell attend une approbation.
3. La vitrine n'a pas été contrôlée dans Studio en direct, faute de MCP. Il faut lancer `tools/studio-items-vitrine.luau` dans la place réelle, car le snapshot v4 peut être en retard sur elle.
4. Aucune intégration dans le jeu : pas d'onglet Équipement dans `HeroBarController` (toujours « Soon »), pas d'inventaire dans PlayerData, pas de type de récompense Item. ITEMS.md ne demandait pas ces points dans ce périmètre.
5. Les icônes ne sont pas livrées (`Icon = nil`). Il faudra les reporter avec l'outil Studio au moment de la livraison.
6. Aucune capture ni VISUAL_QA : aucune interface n'a été modifiée.

## Décisions prises

- Pas de cherry-pick de `docs/items-2d` (base trop ancienne) : seul le contenu des docs a été repris, par-dessus develop.
- Le snapshot `.rbxl` sert de source du catalogue en l'absence du JSON, et ItemConfig est figé : un test le compare à la vitrine.
- Les raretés d'items réutilisent `RarityConfig`, dont les 10 paliers sont les mêmes. Les monstres n'ont toujours aucune rareté.
- Outil Studio en lecture seule : il ne modifie rien dans la place.
- Ajout d'un test Node en plus du test Luau, pour vérifier sans luau ni Studio.

## Risques résiduels

- **Moyen** : des fichiers de travail `.acc/tmp/` seront publiés s'ils ne sont pas retirés.
- **Moyen** : le snapshot v4 a pu diverger de la vitrine réelle ou du JSON d'origine. Ce point n'est pas vérifiable sans Studio ou sans `items_equipment.json`.
- **Faible** : `ItemConfig.spec.lua` n'a pas été exécuté. Le risque est limité, car l'emballage est identique à `test-heroes.ps1` et le contenu est contrôlé par le test Node.
- **Faible** : le test Node dépend d'un parseur `.rbxl` maison, qui pourrait casser si le format du fichier change.
