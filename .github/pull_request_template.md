## Contenu

<!-- Ce que fait la PR, issue liée. -->

## Tests

- [ ] Suites Luau concernées (`tools/test-*.ps1`) et `node --test tests/`
- [ ] Studio : rendu contrôlé sur capture réelle (`docs/VISUAL_QA.md`, PASS ou FIX), ou « non testé Studio »
- [ ] Recette Studio jouée sur un store de recette (`StoreRecette`), jamais sur `PlayerData_Studio` (`docs/SECURITY.md`)

## Propriété des assets (`docs/ASSET_OWNERSHIP.md`)

- [ ] La PR n'ajoute ni ne modifie aucun AssetId (configs, catalogues, modèles Studio, animations, sons) — sinon :
- [ ] Chaque asset nouveau ou modifié appartient au propriétaire de l'expérience (`tools/studio-check-asset-ownership.luau` : 0 FIX)
- [ ] Dépendances internes des modèles contrôlées (meshes, textures, `SurfaceAppearance`)
- [ ] Chargement vérifié dans la place DEV propriétaire (aucun « User is not authorized to access Asset »)
- [ ] Permissions et modération vérifiées sur le Creator Hub
- [ ] Inventaire joint : nom, type, ancien AssetId, nouvel AssetId, propriétaire, contrôle

Verdict propriété : PASS | FIX (blocage avant merge)
