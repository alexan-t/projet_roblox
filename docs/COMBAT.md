# Combat — CombatService (Alpha 0.0.1)

Le serveur calcule tout le combat : cibles, déplacements, attaques, PV, énergie, ultime,
morts, vagues, mini-boss, vitesse, victoire et défaite. Le client ne fait qu'afficher et
demander (ultime, vitesse). Les modèles 3D représentent les unités mais ne sont jamais
une source de vérité : aucun `Humanoid.Health` n'est utilisé.

```
ArenaService (préparation, formation, géométrie de l'arène)
      │ StartCombat(player, zoneSessionId, formation, context)
      ▼
CombatService (CombatSession par joueur, Heartbeat, remotes)
      │ CombatEngine.advance / useUltimate
      ▼
CombatEngine (pur, testable hors Studio)
      │ fin : CompleteStage(player, zoneSessionId, victoire)
      ▼
ZoneService ──► QuestService (StageCompleted, victoire seulement)
```

## CombatConfig

`src/server/Config/CombatConfig.lua`, lu uniquement par le serveur.

| Classe | PV | Dégâts | Intervalle (s) | Portée | Vitesse | Énergie/attaque | Ultime |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Archer | 90 | 14 | 1.0 | 24 | 8 | 20 | 60 |
| Épéiste (`Epeiste`) | 150 | 16 | 0.9 | 5 | 10 | 20 | 70 |
| Barbare | 170 | 22 | 1.3 | 5 | 9 | 25 | 90 |
| Paladin | 220 | 12 | 1.1 | 5 | 8 | 20 | 60 |
| Magicien | 80 | 18 | 1.4 | 22 | 7 | 25 | 80 |
| Tireur | 85 | 20 | 1.5 | 28 | 8 | 20 | 70 |

| Ennemi | PV | Dégâts | Intervalle (s) | Portée | Vitesse |
| --- | --- | --- | --- | --- | --- |
| Slime | 60 | 6 | 1.2 | 4 | 6 |
| Gobelin | 80 | 8 | 1.0 | 5 | 8 |
| Boss (mini-boss) | 450 | 18 | 1.5 | 7 | 6 |

`MaxEnergy = 100` pour les héros ; les ennemis n'ont ni énergie ni ultime. Ultime :
`Radius = 8`. `TickRate = 20`, `MaxFrameTime = 0.25`, `MaxAllies = 4`.

**Ces valeurs sont temporaires, ce n'est pas le balancing final.** Aucune valeur n'existait
dans le dépôt. Objectifs : Stage 1-1 gagné avec 3-4 héros, perdu avec un héros seul, en
une dizaine de secondes à une demi-minute à x1 (mesuré en Studio : 14 s), écart net entre
x1 et x2. Ces objectifs sont vérifiés par des simulations complètes dans les tests.

## CombatSession et unités

Session (runtime seulement, jamais sauvegardée) : `Id`, `Player`, `ZoneSessionId`
(la `StageSession` de ZoneService, distincte), `Zone`, `Stage`, vitesse, état du moteur
(temps, vague, unités, résultat). Au plus une par joueur.

Unité : `UnitId` (unique dans la session), `Team` (`Ally` / `Enemy`), `TypeId` (classe ou
`EnemyId`), `Health`, `MaxHealth`, `Energy`, `MaxEnergy`, `TargetId`, `Position` (plan
horizontal), `Alive`, `Slot` (héros) ou `Cell` (ennemi), `MiniBoss`.

## Simulation

- **Pas fixe** : 1/20 s. CombatService accumule `min(dt, 0.25) × vitesse` à chaque
  Heartbeat et exécute autant de pas fixes (au plus 10 × vitesse par frame ; un retard
  plus grand est abandonné).
- **Ordre** : les unités agissent par `UnitId` croissant ; les morts sont traitées une fois
  à la fin du pas, puis la progression (défaite, vague suivante, mini-boss, victoire).
- **Ciblage** : ennemi vivant le plus proche ; à distance égale, le plus petit `UnitId`.
  Jamais un allié. Une cible morte déclenche une nouvelle acquisition.
- **Déplacement** : hors portée, l'unité avance en ligne droite vers sa cible de
  `MoveSpeed × dt`, sans dépasser la portée. Pas de pathfinding ni de collision.
- **Attaque** : cible vivante et à portée, `AttackInterval` respecté (première attaque
  immédiate). `Health = max(0, Health − AttackDamage)`.
- **Énergie** : `+EnergyPerAttack` par attaque d'un héros, bornée à `MaxEnergy`.
- **Ultime** (générique) : héros vivant du joueur, énergie pleine, combat en cours.
  L'énergie repasse à 0, puis `UltimateDamage` touche la cible (ou l'ennemi le plus proche)
  et tous les ennemis à moins de `Radius` d'elle. Un double clic est refusé : il n'y a plus d'énergie.
- **Mort** : `UnitDied` une seule fois ; l'unité ne cible, ne bouge et n'attaque plus ;
  son modèle est retiré une seconde après (le temps d'une animation de mort).

## Vagues, mini-boss, fin

Les ennemis viennent de `ZoneService:GetSession(player).Config` (StageConfig), jamais du
client. Vague 1 → … → vague N → `MiniBoss` s'il existe → victoire. Une vague n'apparaît
qu'une fois la précédente entièrement morte ; chaque ennemi prend une case différente du
3x3, tirée au hasard par le serveur. Le mini-boss n'apparaît jamais avec une vague.
Stage 1-1 : Slime ×2 + Gobelin ×4, puis Boss.

- **Victoire** : toutes les vagues et le mini-boss morts, au moins un héros vivant.
- **Défaite** : tous les héros morts avant la fin.
- CombatService verrouille sa session, puis appelle `ZoneService:CompleteStage(player,
  zoneSessionId, victoire)` **une seule fois**. QuestService est prévenu par ZoneService,
  jamais directement.
- **Quitter** (`CancelCombat`), départ du joueur, perte du profil ou de la session de
  stage : combat arrêté sans résultat, aucun `CompleteStage`.
- Aucune récompense : devises, tickets et `FirstClears` relèvent de RewardService (#9).

## Vitesse x1 / x2

`CombatService:SetSpeed(player, 1 | 2)`, rien d'autre. La valeur est enregistrée dans
`Settings.CombatSpeed` (seul champ modifié) et reprise au combat suivant. x2 double le
temps simulé par seconde réelle (mouvements, cadence, progression), jamais les dégâts par
coup ; aucun événement n'est dupliqué.

## API serveur

| Méthode | Résultat |
| --- | --- |
| `StartCombat(player, zoneSessionId, formation, context)` | `combatId`, ou `nil` et la raison |
| `GetCombat(player)` | vue copiée : `Id`, `ZoneSessionId`, `Zone`, `Stage`, `Wave`, `WaveCount`, `Speed`, `Units` |
| `CancelCombat(player)` | arrêt sans résultat |
| `UseUltimate(player, unitId)` | `true`, ou `false` et la raison |
| `SetSpeed(player, speed)` | `true` pour 1 ou 2 |
| `OnCombatEnded(callback)` | `callback(player, combatId, "Victory" \| "Defeat")` après l'annonce à ZoneService |

`formation` : `{ [slot] = classId }` (1 à 4 héros, classes de CombatConfig).
`context` (fourni par ArenaService, aucun nom d'asset dans CombatService) :
`HeroPositions[slot]` et `EnemyPositions[case]` (Vector3 au sol) et
`SpawnUnit(unit, pieds, regard) -> Model?` qui crée la représentation de l'unité.

## Remotes

- `ReplicatedStorage.Remotes.CombatAction` (RemoteFunction), seules demandes acceptées :
  `("UseUltimate", unitId)` et `("SetSpeed", 1 | 2)`. Tout autre nom est refusé
  (`"action inconnue"`), les arguments en trop sont ignorés. Le client ne peut jamais
  envoyer dégâts, PV, énergie, cible, position, vague, ennemi, stats ni résultat.
- `ReplicatedStorage.Remotes.CombatEvent` (RemoteEvent), serveur → propriétaire du
  combat uniquement : `(combatId, events)` par frame.

## Événements (pour le design)

`CombatStarted`, `SpeedChanged {Speed}`, `WaveStarted {Wave, WaveCount}`,
`MiniBossStarted {EnemyId}`, `UnitSpawned {UnitId, Team, TypeId, Slot, Cell, MiniBoss, X, Z,
Health, MaxHealth, Energy, MaxEnergy}`, `TargetChanged {UnitId, TargetId}`,
`MoveStarted {UnitId, TargetId}`, `Attack {UnitId, TargetId}`,
`Damage {TargetId, SourceId, Amount, Health}`, `EnergyChanged {UnitId, Energy, MaxEnergy}`,
`UltimateUsed {UnitId, TargetId, Hits}`, `UnitDied {UnitId, Team, TypeId}`,
`CombatEnded {Result}`.

Les positions suivent les modèles répliqués (pas d'événement par frame). Le gameplay
n'attend jamais une animation. Les modèles portent les attributs `UnitId`, `Team`,
`CombatId` et `Alive` (faux à la mort).

## Côté client

Règle d'interface : une information qui peut s'afficher dans le monde n'a pas de HUD séparé.

- `ArenaPrepController` (#11 fera l'UI finale) : pendant le combat, seulement **x1 / x2 / X**
  (quitter) en haut à droite, une annonce brève à chaque vague ou au mini-boss, et le
  message de fin.
- `CombatViewController` : tout le reste est **dans le monde**, au-dessus des unités.
  - Petite barre de **PV** (rouge sous 30 %) et, pour les héros, barre de **mana**. Barre
    plus large pour le mini-boss. Petite icône de classe (attribut `HeroClass`) au-dessus
    des héros, sans nom.
  - **Mana pleine** : la barre devient dorée et pulse, et le héros a un léger contour doré.
  - **Ultime** : toucher ou cliquer un héros dont la mana est pleine (raycast sur son
    corps, sinon le héros prêt le plus proche dans un rayon de 70 px). Le client envoie
    seulement `CombatAction("UseUltimate", unitId)` ; le serveur vérifie tout.
  - **Dégâts** : chiffres brefs au-dessus des ennemis (plus gros et dorés pour un ultime).
  - **Mort** : les barres disparaissent, puis l'animation `Mort`.
  - Animations `Marche`, `Attaque`, `Touche`, `Mort` via `MonsterAnimationController.Play`,
    pour les modèles qui portent l'attribut `JeuAnimations`.
- `CombatIntroController` (Cypher) : reste une **démo** d'entrée en combat (vague fixe,
  mannequins côté client, déclenchée par `IntroDemo` / `IntroDemoBoucle`). Il n'est pas
  branché sur le vrai combat ; ArenaService suspend sa boucle pendant une préparation.
  Il pourra être rejoué sur `CombatStarted` et consommer `UnitSpawned` plus tard.
- `MonsterAnimationController` (Cypher) : inchangé ; utilisé via son API `Play`. Les
  mannequins actuels n'ont pas de `JeuAnimations` : aucune animation ne joue encore.

## Intégrations futures

- **#9 RewardService** : sera appelé par ZoneService à la victoire (même point que QuestService).
- **#10 HeroService** : la formation vient aujourd'hui de la collection fixe du prototype
  (6 classes) ; elle viendra de `PlayerData.Heroes`. **Dette assumée.**
- **#11 UI** : remplacera les panneaux et barres provisoires en consommant les mêmes événements.

## Limites

- Mannequins temporaires (un seul `MannequinHeros`, classes distinguées par une petite
  icône provisoire ; vrais portraits et rareté avec #10), sans animation. Une seule arène de test (`PlotTravail.Arene`), donc un combat physique à
  la fois. Le moteur gère plusieurs sessions, ce que les tests prouvent.
- Pas de collision entre unités (elles peuvent se superposer), pas de pathfinding.

## Validation

```powershell
./tools/test-combat.ps1 -LuauPath <chemin-vers-luau.exe>
```

CombatEngine : vrai moteur avec la vraie config et la vraie StageConfig, jusqu'à des
Stage 1-1 complets. CombatService : vrai service avec des doubles de ZoneService,
DataService et des API Roblox.
