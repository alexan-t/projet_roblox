# Validation des tokens d'effets — 16 octobre 2026

Code validé : mise en œuvre `cc67b5d`, avec les tests ajoutés dans ce dossier.

## Tests ajoutés

```powershell
node --test tests/ui-effects.test.mjs tests/items-vitrine.test.mjs tests/resources.test.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test-ui-effects.ps1 -LuauPath C:\Users\teofo\AppData\Local\Temp\luau\luau.exe
```

- Effets, contrôles de source : **16 passés, 0 échoué**.
- Effets, exécution Luau : **5 passés, 0 échoué**. Vrais modules UITheme,
  UltimateEffectController, SummonEffectController, RarityConfig et RarityStyle ;
  doubles des types moteur et dépendances visuelles inutilisées.
- Items : **9 passés, 0 échoué** ; ressources : **13 passés, 0 échoué**.
  Node affiche 18 tests au total, car ces deux anciennes suites comptent chacune
  comme un fichier dans son rapport (elles comptent leurs propres assertions).

Les contrôles couvrent les références aux tokens et à la palette, les délais
littéraux dans les appels temporels, les durées de particules et l'immuabilité.
Les API sont exécutées à vitesse x1/x2 et pour les dix raretés de héros, avec
valeurs par défaut et rareté inconnue. Une injection de tokens différents vérifie
que les API suivent le thème. Les branchements audio, OnRevealed et Continuer
sont vérifiés dans le code source ; leurs callbacks visuels ne sont pas exécutés.
Les 14 s sont conservées pour la rotation décorative infinie des récompenses.

## Suites existantes

Tous les scripts `tools/test-*.ps1` ont été exécutés dans des processus PowerShell
distincts avec `-NoProfile -ExecutionPolicy Bypass -LuauPath` et le même exécutable
Luau que ci-dessus. **15 scripts réussis, 0 en échec**.

| Script | Résultats (passés / échoués) |
| --- | --- |
| test-arena | ArenaRules 11/0, ArenaPrep 25/0, PlacementState 14/0 |
| test-combat | CombatEngine 34/0, CombatService 33/0 |
| test-heroes | HeroRules 10/0, Migrations 12/0, HeroService 28/0 |
| test-items | ItemConfig 5/0 |
| test-kingdom | KingdomService 19/0 |
| test-migrations | Migrations 12/0 |
| test-playerstate | PlayerStateService 5/0 |
| test-plots | PlotService 37/0 |
| test-quests | QuestService 18/0 |
| test-resources | ResourceConfig 5/0 |
| test-rewards | RewardService 13/0, RewardFlow 16/0 |
| test-security | Sécurité #12 22/0, suites sous-jacentes réussies |
| test-skeleton | Skeleton 13/0, AnimationSets 14/0 |
| test-summon | HeroService 28/0 |
| test-zones | ZoneService 21/0 |

Certains scripts relancent les mêmes cas : ne pas additionner ces chiffres
comme des tests uniques. `git diff --check` réussit également.

Deux premiers lancements des nouveaux tests ont échoué à cause du harnais :
le contrôle de références incluait `UITheme.Effects.<groupe>` et le double de
RarityStyle ne fournissait pas `rank`. Corrigés en excluant les accès qualifiés
et en chargeant le vrai RarityStyle ; les relances passent intégralement.

## Validation restant à l'équipe

Aucun outil Studio n'est disponible dans cette session. Aucun PASS visuel n'est
attribué sans capture, conformément à CLAUDE.md et docs/VISUAL_QA.md.

Dans Studio synchronisé par Rojo, suivre le parcours documenté dans
docs/UI_DESIGN_SYSTEM.md : introduction, ultime à x1/x2, récompenses avec
Continuer, invocation et révélation de la carte (dix raretés de héros).
Capturer les effets réels, vérifier la palette et la synchronisation, consigner
VISUAL_QA PASS ou FIX puis réinitialiser la caméra après les captures.
