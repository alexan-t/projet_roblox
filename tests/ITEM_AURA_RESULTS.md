# Résultats des tests — aura des équipements

Exécution le 19 octobre 2026, dans le worktree de la mission, sans publication.

## Résultat final

| Contrôle | Réussis | Échoués |
| --- | ---: | ---: |
| Aura : vérifications Node | 6 | 0 |
| Aura : exécution du module Luau réel | 5 | 0 |
| Catalogue des équipements et snapshot historique | 19 | 0 |
| Ressources | 13 | 0 |
| Assets d'interface | 5 | 0 |
| Scripts existants `tools/test-*.ps1` | 20 suites | 0 |

Les scripts Luau existants totalisent 545 assertions réussies, avec les répétitions
des suites appelées par plusieurs scripts (invocation et migrations notamment).
Node annonce 8 tests de premier niveau ; les scripts historiques comptent leurs
propres assertions, d'où les nombres détaillés ci-dessus.

## Couverture ajoutée

- Bornes et nombres entiers des couches, durées positives, halo animé.
- Identifiants uniques des 100 équipements et couverture du catalogue de production
  (42 tâches ; les 58 icônes du partenaire sont déjà dans le catalogue du jeu).
- Branchement de l'aperçu sur le catalogue complet et la rareté de chaque item.
- Exécution réelle de `forRarity` : les dix paliers, les 100 équipements et les
  identifiants absents ou inconnus ; protection des réglages contre les mutations.
- Validité des réglages globaux de dégradé, respiration et débordement compact.

Les contrôles du branchement UI dans Node sont statiques : ils ne remplacent pas
une exécution du rendu dans Roblox.

## Échecs rencontrés et corrigés

La première exécution globale donnait 19 scripts réussis sur 20 : deux assertions
d'Expédition attendaient des récompenses de rejeu vides. Le diff avec le commit de
base `8c698b3314a3c6e36e912b2315b456b49f492aca` montre que ces tests avaient perdu
leurs attentes sur les tickets, tandis que `RewardConfig` les attribue toujours.
`src/server/Tests/Expedition.spec.lua` a été rétabli exactement depuis ce commit.
Nouvelle exécution : **15 réussis, 0 échoué**. Aucun code de jeu modifié.

Une première version du nouveau test supposait 100 tâches de production : corrigée
pour tenir compte des 58 icônes du partenaire. La couverture des 100 équipements
reste contrôlée via `ItemConfig`.

## Reproduction

```powershell
node --test tests/*.test.mjs
& tests/test-item-aura.ps1 -LuauPath "$PWD/build/luau/luau.exe"
Get-ChildItem tools/test-*.ps1 | ForEach-Object {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $_.FullName -LuauPath "$PWD/build/luau/luau.exe"
    if ($LASTEXITCODE -ne 0) { throw "$($_.Name): échec" }
}
git diff --check
```

Luau était absent du PATH : binaire Windows officiel téléchargé depuis
`https://github.com/luau-lang/luau/releases/latest/download/luau-windows.zip`
et extrait dans `build/luau` (ignoré par Git). Les sorties détaillées des scripts
existants sont dans `build/test-*.log` et `build/test-results.json` (non versionnés).

## Limite visuelle

Cette étape modifie uniquement les tests. Aucun nouveau verdict VISUAL_QA PASS
n'est attribué. Le contrôle Studio en lecture seule a trouvé une place « test 3 »
sans `ItemAuraConfig` synchronisé ; aucun changement n'y a été fait. Le PASS visuel
annoncé à l'étape de mise en œuvre n'a donc pas été revérifié ici.

La branche de mission imposée a été conservée conformément à l'interdiction de
changer de branche ; aucun push ni publication.
