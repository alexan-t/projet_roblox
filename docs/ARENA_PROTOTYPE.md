# Prototype — préparation de combat dans l'arène de test

**Prototype de préparation pour tester la boucle en Studio.** La phase de combat est
désormais prise en charge par **CombatService** (#8, voir `docs/COMBAT.md`). L'UI reste
provisoire (#11).

## Ce qu'on peut faire

1. S'approcher de l'étendard de l'arène `Workspace.PlotTravail.Arene` : un prompt
   **« Préparer le combat »** (touche E) lance le **Stage 1-1** via ZoneService et ouvre une
   **grande fenêtre** :
   - en haut, le **camp ennemi** (3x3) : des « ? » pendant la préparation. On connaît
     **quels ennemis** on va affronter (Slime ×2, Gobelin ×4, mini-boss Boss), **pas leurs positions** ;
   - dessous, la **formation** du joueur (3x3, rang Avant en haut, côté front) ;
   - à droite, la **collection** : Archer, Épéiste, Barbare, Paladin, Magicien, Tireur.
2. Au **clic ou au toucher** : choisir une case puis un héros, ou un héros puis une case.
   - Une case occupée + un autre héros = **remplacement**.
   - « **Retirer de la case** » vide la case sélectionnée.
   - **4 héros maximum**, une unité par classe : reposer une classe la déplace.
   - Les héros apparaissent aussi en 3D sur les cases de l'arène.
3. **Combattre** : ArenaService passe la formation et la géométrie de l'arène à
   **CombatService**, qui fait le vrai combat automatique. La vague 1 apparaît au hasard sur
   le 3x3 ennemi, puis le mini-boss une fois la vague morte. Il y a un nouveau tirage à
   chaque combat. La fenêtre se referme ; une barre en bas montre la vague, x1/x2, les
   héros (PV, énergie, bouton **Ultime**) et « Voir le terrain », qui affiche les unités
   réellement actives.
4. **Fin** : « Victoire ! » ou « Défaite… », décidée par le serveur, puis l'arène est rangée.
   **Quitter** arrête le combat sans résultat et annule la session.

## Découpage

| Fichier | Rôle |
| --- | --- |
| `src/shared/Config/ArenaConfig.lua` | arène de test, stage lancé, collection de 6 classes, max 4, mannequins par `EnemyId` |
| `src/server/Arena/ArenaRules.lua` | règles pures : roster annoncé (sans positions), formation (assign, clear) |
| `src/server/Services/ArenaService.lua` | prompt, phases Placement → Combat, géométrie et mannequins, remotes ; délègue le combat à CombatService |
| `src/client/Controllers/ArenaPrepController.lua` | fenêtre de préparation (terrain 3x3, collection) et barre de combat |

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
  Il n'existe qu'un `MannequinHeros` : les classes se distinguent par une étiquette provisoire.
- **Apparition de test** (Studio uniquement) : à chaque apparition, le personnage est déplacé
  sur `PlotTravail.PointApparition` (`ArenaConfig.TestSpawn`, `nil` pour désactiver), une seconde
  après le placement de PlotService. Le plot attribué ne change pas.
- **Intro de démonstration** : l'attribut `IntroDemoBoucle` de l'arène est coupé pendant la
  préparation (runtime seulement) puis restauré ; le client retire les restes `IntroCombat`.
- Une seule préparation à la fois (arène de test unique). Départ, fin de session (debug) ou
  perte de profil : l'arène est rangée en moins d'une seconde.

## Limites (prototype)

- La collection n'est pas encore `PlayerData.Heroes` (vide) : 6 classes fixes pour le test.
- Le panneau et les étiquettes sont des placeholders : #11 et le design.
- L'arène est celle de `PlotTravail`, pas celle du plot du joueur, qui n'a pas encore d'arène.

## Tests

```powershell
./tools/test-arena.ps1 -LuauPath <chemin-vers-luau.exe>
```

Les règles pures de préparation sont testées avec la vraie StageConfig (roster annoncé,
placement, remplacement, retrait). Le combat est testé par `./tools/test-combat.ps1`.
