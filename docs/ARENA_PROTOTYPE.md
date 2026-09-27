# Prototype — préparation de combat dans l'arène de test

**Prototype pour tester la boucle en Studio.** Ce n'est ni le moteur de combat (#8) ni
l'UI finale (#11) : ces issues pourront reprendre les règles serveur et remplacer le reste.

## Ce qu'on peut faire

1. S'approcher de l'étendard de l'arène `Workspace.PlotTravail.Arene` : un prompt
   **« Préparer le combat »** (touche E) lance le **Stage 1-1** via ZoneService.
2. Un panneau provisoire affiche **les ennemis à affronter** (Slime ×2, Gobelin ×4,
   mini-boss Boss) mais **pas leurs positions**.
3. Choisir une classe dans la collection (Archer, Épéiste, Barbare, Paladin, Magicien,
   Tireur), puis **cliquer une case** du 3x3 (`CaseHeros`) : le héros y est posé. Reclic sur
   une case occupée = retirer. **4 héros maximum, une unité par classe** (reposer une classe
   la déplace).
4. **Combattre** : les ennemis du stage apparaissent **au hasard** sur le 3x3 ennemi, avec
   un nouveau tirage à chaque combat, même en rejouant 1-1.
5. **Quitter** : annule la session et range l'arène. Aucun combat réel n'a lieu (#8).

## Découpage

| Fichier | Rôle |
| --- | --- |
| `src/shared/Config/ArenaConfig.lua` | arène de test, stage lancé, collection de 6 classes, max 4, mannequins par `EnemyId` |
| `src/server/Arena/ArenaRules.lua` | règles pures : liste des ennemis, résumé sans positions, tirage aléatoire, placement |
| `src/server/Services/ArenaService.lua` | prompt, phases Placement → Combat, mannequins, remotes |
| `src/client/Controllers/ArenaPrepController.lua` | panneau provisoire et clic sur les cases |

- **Serveur autoritaire** : `Remotes.ArenaAction` n'accepte que `"Toggle", case, classe`,
  `"Fight"` et `"Leave"`. Le serveur valide la case (1..9), la classe, la limite et la phase,
  et fait tous les tirages. Le client ne reçoit la liste des ennemis qu'agrégée, et ne peut
  jamais déclarer une victoire.
- **3x3 héros** : les 9 `CaseHeros` de l'arène (attribut `Slot`, repère `PointDePose`).
- **3x3 ennemi** : `Zones.<ZoneId = 1>.SourcesEnnemis.FrontEnnemi` découpé en 3 × 3.
  La première ligne est côté héros, et les colonnes sont dans le même ordre que les cases héros.
- **Mannequins** : ceux du design (`ReplicatedStorage.Assets.Combat`), clonés tels quels.
  Il n'existe qu'un `MannequinHeros` : les classes se distinguent par une étiquette provisoire.
- **Intro de démonstration** : l'attribut `IntroDemoBoucle` de l'arène est coupé pendant la
  préparation (runtime seulement) puis restauré ; le client retire les restes `IntroCombat`.
- Une seule préparation à la fois (arène de test unique). Départ, fin de session (debug) ou
  perte de profil : l'arène est rangée en moins d'une seconde.

## Limites (prototype)

- La collection n'est pas encore `PlayerData.Heroes` (vide) : 6 classes fixes pour le test.
- Pas de combat, de dégâts, de PV, d'IA ni de résultat : #8.
- Le panneau et les étiquettes sont des placeholders : #11 et le design.
- L'arène est celle de `PlotTravail`, pas celle du plot du joueur, qui n'a pas encore d'arène.

## Tests

```powershell
./tools/test-arena.ps1 -LuauPath <chemin-vers-luau.exe>
```

Les règles pures sont testées avec la vraie StageConfig : ennemis, résumé, tirage sur 9 cases
distinctes, variation d'un combat à l'autre et placement.
