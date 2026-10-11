# Combat — CombatService (Alpha 0.0.1)

Le serveur calcule tout le combat : cibles, déplacements, attaques, PV, énergie, ultimes
(automatiques), morts, vagues, mini-boss, victoire et défaite. Le client affiche, et ne peut
demander qu'une chose : la vitesse x1/x2. Les modèles 3D représentent les unités mais ne
sont jamais une source de vérité : aucun `Humanoid.Health` n'est utilisé.

```
ArenaService (héros posés dans le monde, touche E, géométrie de l'arène)
      │ StartCombat(player, zoneSessionId, formation, context)
      ▼
CombatService (CombatSession par joueur, Heartbeat, remotes)
      │ CombatEngine.advance (ultimes compris)
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
- **Ultime automatique** (générique) : aucune action du joueur. Dès que la jauge d'un héros
  vivant est pleine et qu'il a une cible vivante (la sienne, sinon l'ennemi le plus proche),
  le moteur lance l'ultime : `Energy` repasse à 0 (`EnergyChanged`), puis `UltimateUsed`,
  puis `UltimateDamage` sur la cible et sur tous les ennemis à moins de `Radius` d'elle.
  Cycle : attaque → 100 → ultime → 0, une fois par remplissage, jamais deux dans le même pas.
- **Sans cible** (la jauge se remplit sur le coup qui tue le dernier ennemi d'une vague) :
  l'ultime n'est pas perdu ni lancé dans le vide. La jauge reste pleine et l'ultime part au
  premier pas où une cible existe (vague suivante ou mini-boss), à la place d'une action.
  Rien n'est lancé entre deux vagues. Les ennemis n'ont pas d'énergie, donc pas d'ultime.
- **Mort** : `UnitDied` une seule fois ; l'unité ne cible, ne bouge et n'attaque plus ;
  son modèle est retiré 1,7 s après (le temps de sa disparition côté client, même retardée jusqu'au coup visible).

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
- CombatService n'attribue aucune récompense. Devises, tickets et `FirstClears` relèvent de
  RewardService (#9), appelé par ZoneService. Le `CombatEnded` du moteur reste interne : après
  `CompleteStage`, le client reçoit **un seul** `CombatEnded { Result, FirstClear, Rewards }`
  (défaite : `FirstClear = false`, `Rewards = {}`). Voir `docs/REWARDS.md`.

## Vitesse x1 / x2

`CombatService:SetSpeed(player, 1 | 2)`, rien d'autre. La valeur est enregistrée dans
`Settings.CombatSpeed` (seul champ modifié) et reprise au combat suivant. x2 double le
temps simulé par seconde réelle (mouvements, cadence, progression), jamais les dégâts par
coup ; aucun événement n'est dupliqué.

Côté client, `CombatViewController` suit `SpeedChanged` : toutes les animations jouent à la vitesse
du combat (`MonsterAnimationController.SetTimeScale`), et les instants d'impact (chiffres de dégâts,
disparition, onde de l'ultime, séisme) sont divisés par la vitesse. La marche s'arrête quand l'unité
attaque ou meurt. Durées tenues en x2 : attaque du Roi Orc 0,7 s pour un intervalle de 0,75 s,
épée de l'Écuyer 0,3 s pour 0,45 s (Épéiste).

## API serveur

| Méthode | Résultat |
| --- | --- |
| `StartCombat(player, zoneSessionId, formation, context)` | `combatId`, ou `nil` et la raison |
| `GetCombat(player)` | vue copiée : `Id`, `ZoneSessionId`, `Zone`, `Stage`, `Wave`, `WaveCount`, `Speed`, `Units` |
| `CancelCombat(player)` | arrêt sans résultat |
| `SetSpeed(player, speed)` | `true` pour 1 ou 2 |
| `OnCombatEnded(callback)` | `callback(player, combatId, "Victory" \| "Defeat")` après l'annonce à ZoneService |

`formation` : `{ [slot] = classId }` (1 à 4 héros, classes de CombatConfig). ArenaService la
construit à partir des exemplaires posés (`HeroId` de chaque `HeroInstanceId`).
`context` (fourni par ArenaService, aucun nom d'asset dans CombatService) :
`HeroPositions[slot]` et `EnemyPositions[case]` (Vector3 au sol) et
`SpawnUnit(unit, pieds, regard) -> Model?` qui crée la représentation de l'unité
(`unit` = `UnitId`, `Team`, `TypeId`, `Slot`).

## Remotes

- `ReplicatedStorage.Remotes.SetCombatSpeed` (RemoteFunction) : `(1 | 2)`, seule demande
  possible du client. Toute autre valeur est refusée (`"vitesse invalide"`). Il n'existe
  aucun remote d'ultime ou d'action : le client ne peut jamais envoyer dégâts, PV, énergie,
  cible, position, vague, ennemi, stats, ultime ni résultat.
- `ReplicatedStorage.Remotes.CombatEvent` (RemoteEvent), serveur → propriétaire du
  combat uniquement : `(combatId, events)` par frame.

## Événements (pour le design)

`CombatStarted`, `SpeedChanged {Speed}`, `WaveStarted {Wave, WaveCount}`,
`MiniBossStarted {EnemyId}`, `UnitSpawned {UnitId, Team, TypeId, Slot, Cell, MiniBoss, X, Z,
Health, MaxHealth, Energy, MaxEnergy}`, `TargetChanged {UnitId, TargetId}`,
`MoveStarted {UnitId, TargetId}`, `Attack {UnitId, TargetId}`,
`Damage {TargetId, SourceId, Amount, Health}`, `EnergyChanged {UnitId, Energy, MaxEnergy}`,
`UltimateUsed {UnitId, TargetId, Hits}` (automatique : point d'accroche pour animation, VFX,
SFX, caméra), `UnitDied {UnitId, Team, TypeId}`,
`CombatEnded {Result, FirstClear, Rewards}` (un seul, envoyé après `CompleteStage` et l'attribution
des récompenses ; `Rewards` est `{}` à la défaite).

Les positions suivent les modèles répliqués (pas d'événement par frame). Le gameplay
n'attend jamais une animation. Les modèles portent les attributs `UnitId`, `Team`,
`CombatId` et `Alive` (faux à la mort).

## Côté client

Règle d'interface : une information qui peut s'afficher dans le monde n'a pas de HUD séparé.

- `ArenaPlacementController` : pendant le combat, une pastille légère au-dessus de la hotbar
  (vague, **x1 / x2**, **X** pour quitter), une annonce brève à chaque vague ou au mini-boss,
  et le résultat. La hotbar reste visible, grisée : elle ne modifie plus la formation.
- `CombatViewController` : tout le reste est **dans le monde**, au-dessus des unités.
  - Petite barre de **PV** (rouge sous 30 %) et, pour les héros, barre de **mana**. Barre
    plus large pour le mini-boss. Petite icône de classe (attribut `HeroClass`) au-dessus
    des héros, sans nom.
  - **Mana pleine** : la barre devient dorée et pulse, et le héros a un léger contour doré.
  - **Ultime** : automatique côté serveur ; le joueur n'a rien à faire. Sur `UltimateUsed`, le héros
    joue « Ultime » (`UltimateEffectController`, « Charge du Rempart ») : lueur dorée, une lame dorée
    file de son arme vers la cible, puis un anneau doré éclate au sol au rayon des ennemis touchés.
    Les chiffres de dégâts et la disparition des ennemis touchés attendent l'impact de l'onde
    (`IMPACT_DELAY`, 0,45 s).
  - **Coup visible** : les chiffres de dégâts et la disparition de la cible attendent l'instant du
    coup de l'animation « Attaque » de l'attaquant (attribut `Impact` de la séquence). Un modèle
    avec l'attribut `EffetAttaque` joue aussi un effet d'impact (`AttackEffectController`, ex.
    `"Seisme"` pour le Roi Orc).
  - **Dégâts** (`DamageFeedbackController`), à l'instant du coup visible : flash bref de la cible
    (clair sur un ennemi, rouge sur un héros), petit recul à l'opposé de l'attaquant, chiffre au
    design system (Fredoka contourée : clair, doré pour un ultime, rouge sur un héros) et traînée
    claire sur la barre de vie qui se résorbe. Pas d'animation de douleur ; un coup fatal laisse la
    place à la disparition. Démonstration Studio : tag `ApercuDegats` (`ApercuAllie` pour un héros).
  - **Mort** : les barres disparaissent, puis l'unité **se dissout** (`DefeatEffectController`,
    0,85 s, avant le retrait du modèle par le serveur à 1,7 s) : flash clair, petit sursaut,
    effacement de haut en bas avec poussière et étincelles dorées. Pas d'animation de douleur : le
    jeu est surtout en one-shot. Démonstration en Studio : tag `ApercuDisparition` sur un modèle.
  - **Vitesse x2** : animations, instants d'impact et effets suivent la vitesse du combat.
  - **Sons** (`AudioController`, `docs/AUDIO.md`) : élan, impact, ultime, dissolution, mini-boss.
  - Animations `Marche`, `Attaque`, `Touche`, `Mort` via `MonsterAnimationController.Play`,
    pour les modèles qui portent l'attribut `JeuAnimations`.
- `CombatIntroController` (Cypher) : reste une **démo** d'entrée en combat (vague fixe,
  mannequins côté client, déclenchée par `IntroDemo` / `IntroDemoBoucle`). Il n'est pas
  branché sur le vrai combat ; ArenaService suspend sa boucle pendant une préparation.
  Il pourra être rejoué sur `CombatStarted` et consommer `UnitSpawned` plus tard.
- `MonsterAnimationController` (Cypher) : inchangé ; utilisé via son API `Play`. Les
  mannequins actuels n'ont pas de `JeuAnimations` : aucune animation ne joue encore.

## Intégrations futures

- **#9 RewardService** (fait, `docs/REWARDS.md`) : ZoneService l'appelle à la victoire, juste après
  QuestService. L'écran de fin s'affiche sur `CombatEnded` (`ArenaPlacementController`) avec
  `RewardScreenController.Show({ Result, FirstClear, Rewards }, onContinue)`. Côté victoire : « Victoire ! »
  avec rayons dorés et étincelles, cartes de récompense en cascade avec objet 3D et montant qui défile,
  badge « Nouveau » et bouton « Continuer ». Côté défaite : un « Défaite… » sobre. Le client ne décide
  d'aucune récompense : `Rewards` et `FirstClear` sont celles réellement attribuées et déjà sauvegardées.
  Démonstration Studio : attribut `Workspace.ApercuEcranRecompenses = true`.
- **#10 HeroService** : la partie Alpha existe (`docs/HEROES.md` : exemplaires possédés, kit de
  départ, hotbar). Restent l'invocation, les niveaux et la rareté.
- **#11 UI** : remplacera les panneaux et barres provisoires en consommant les mêmes événements.

## Limites

- Mannequins temporaires (un seul `MannequinHeros`, classes distinguées par une petite
  icône provisoire ; vrais portraits et rareté avec #10), sans animation. Chaque joueur combat dans l'arène de son plot (lancement depuis la pancarte du stage), donc plusieurs combats physiques à
  la fois. Le moteur gère plusieurs sessions, ce que les tests prouvent.
- Pas de collision entre unités (elles peuvent se superposer), pas de pathfinding.

## Validation

```powershell
./tools/test-combat.ps1 -LuauPath <chemin-vers-luau.exe>
```

CombatEngine : vrai moteur avec la vraie config et la vraie StageConfig, jusqu'à des
Stage 1-1 complets. CombatService : vrai service avec des doubles de ZoneService,
DataService et des API Roblox.
