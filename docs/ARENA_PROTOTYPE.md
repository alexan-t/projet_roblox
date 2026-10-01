# Prototype — préparation de combat dans l'arène de test

**Prototype de préparation pour tester la boucle en Studio.** La phase de combat est
désormais prise en charge par **CombatService** (#8, voir `docs/COMBAT.md`). L'UI reste
provisoire (#11).

## Ce qu'on peut faire

1. S'approcher de l'étendard de l'arène `Workspace.PlotTravail.Arene` : un prompt
   **« Préparer le combat »** (touche E) lance le **Stage 1-1** via ZoneService. Pas de
   fenêtre : on place les héros **directement sur l'arène**.
   - En bas, la **main** : une carte compacte par héros (miniature 3D, icône, nom, ✓ si
     posé). Pas encore de rareté (contour neutre) : elle viendra avec #10.
   - En haut, une petite pastille annonce **quels ennemis** on va affronter
     (Slime ×2, Gobelin ×4, ★ Boss), **pas leurs positions**.
   - La grille 3x3 des héros reste discrète ; elle n'est bien visible que pendant un choix
     ou un glisser, avec la case survolée en surbrillance.
2. **Souris ou toucher** :
   - **glisser** une carte sur une case, ou **toucher** une carte puis une case ;
   - appuyer sur un héros posé puis le glisser vers une autre case (**déplacement**) ou
     vers la main (**retrait**) ;
   - une case occupée + un autre héros = **remplacement** ;
   - **4 héros maximum**, une unité par classe : reposer une classe la déplace.
3. **Combattre** : ArenaService passe la formation et la géométrie de l'arène à
   **CombatService**, qui fait le vrai combat automatique. La vague 1 apparaît au hasard sur
   le 3x3 ennemi, puis le mini-boss une fois la vague morte. Il y a un nouveau tirage à
   chaque combat. La main disparaît ; il ne reste que **x1 / x2 / X** en haut à droite.
   PV, mana et ultime sont dans le monde, au-dessus des unités (voir `docs/COMBAT.md`) :
   **toucher un héros à mana pleine** lance son ultime.
4. **Fin** : « Victoire ! » ou « Défaite… », décidée par le serveur, puis l'arène est rangée.
   **Quitter** arrête le combat sans résultat et annule la session.

## Découpage

| Fichier | Rôle |
| --- | --- |
| `src/shared/Config/ArenaConfig.lua` | arène de test, stage lancé, collection de 6 classes, max 4, mannequins par `EnemyId` |
| `src/server/Arena/ArenaRules.lua` | règles pures : roster annoncé (sans positions), formation (assign, clear) |
| `src/server/Services/ArenaService.lua` | prompt, phases Placement → Combat, géométrie et mannequins, remotes ; délègue le combat à CombatService |
| `src/client/Controllers/ArenaPrepController.lua` | main de héros, glisser-déposer sur la grille de l'arène, x1/x2/X pendant le combat |
| `src/client/Controllers/CombatViewController.lua` | barres PV/mana, icônes, dégâts et ultime au toucher, dans le monde |

- **Serveur autoritaire** : `Remotes.ArenaAction` n'accepte que `"Assign", case, classe`,
  `"Clear", case`, `"Fight"` et `"Leave"`. Le serveur valide la case (1..9), la classe, la limite et la phase,
  puis transmet une copie de la formation à CombatService. Pendant la préparation, le client
  ne reçoit que la liste agrégée des ennemis ; les unités d'une vague ne lui sont décrites que
  lorsque le serveur la lance. Il ne peut jamais déclarer une victoire.
- **3x3 héros** : les 9 `CaseHeros` de l'arène (attribut `Slot`, repère `PointDePose`).
- **3x3 ennemi** : `Zones.<ZoneId = 1>.SourcesEnnemis.FrontEnnemi` découpé en 3 × 3.
  La première ligne est côté héros, et les colonnes sont dans le même ordre que les cases héros.
- **Mannequins** : ceux du design (`ReplicatedStorage.Assets.Combat`), clonés tels quels par
  ArenaService quand CombatService crée une unité (`context.SpawnUnit`).
  Il n'existe qu'un `MannequinHeros` : ArenaService pose l'attribut `HeroClass`, et le client
  affiche une petite icône de classe provisoire au-dessus.
- **Apparition de test** (Studio uniquement) : à chaque apparition, le personnage est déplacé
  sur `PlotTravail.PointApparition` (`ArenaConfig.TestSpawn`, `nil` pour désactiver), une seconde
  après le placement de PlotService. Le plot attribué ne change pas.
- **Intro de démonstration** : l'attribut `IntroDemoBoucle` de l'arène est coupé pendant la
  préparation (runtime seulement) puis restauré ; le client retire les restes `IntroCombat`.
- Une seule préparation à la fois (arène de test unique). Départ, fin de session (debug) ou
  perte de profil : l'arène est rangée en moins d'une seconde.

## Limites (prototype)

- La collection n'est pas encore `PlayerData.Heroes` (vide) : 6 classes fixes pour le test.
- La main, les icônes (emoji) et les barres sont provisoires : #11 et le design.
- L'arène est celle de `PlotTravail`, pas celle du plot du joueur, qui n'a pas encore d'arène.

## Tests

```powershell
./tools/test-arena.ps1 -LuauPath <chemin-vers-luau.exe>
```

Les règles pures de préparation sont testées avec la vraie StageConfig (roster annoncé,
placement, remplacement, retrait). Le combat est testé par `./tools/test-combat.ps1`.
