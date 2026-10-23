# Héros possédés, hotbar et invocation — HeroService (#10)

Boucle Alpha fermée : Combat → récompense (RewardService, +1 `SummonTicket` au premier clear de 1-1)
→ invocation au portail de son plot → nouveau héros → collection / hotbar → royaume.
Raretés, bannières et interface d'invocation : voir § Raretés, § Bannières et `docs/SUMMON.md`.
Hors scope : niveaux, stats par rareté (tous les héros d'un même profil ont les mêmes stats).

## HeroId réel ≠ profil de combat

`HeroId` est l'identifiant **réel** du héros : le même que l'attribut `HeroId` des modèles de
`ServerStorage.Assets.Heros`. C'est lui qui est sauvegardé, jamais une classe de combat.

Le catalogue des héros **activés** est `src/shared/Config/HeroConfig.lua` (partagé). Chaque entrée
porte le nom, la **rareté** (`Rarity`, Id de `RarityConfig`, reprise de l'attribut `Rarete` du
Bestiaire), le monogramme provisoire, l'ordre du Bestiaire et deux détails Alpha temporaires.
Les **60 héros** du Bestiaire sont activés (tous jouables, tous invocables) :

| HeroId | `CombatProfile` (stats, `CombatConfig.Heroes`) | `CombatTemplate` (`ReplicatedStorage.Assets.Combat`) |
| --- | --- | --- |
| `ecuyer_du_rempart` | `Epeiste` | `Heros_EcuyerDuRempart` (articulé, animé) |
| `tireuse_des_faubourgs` | `Tireur` | aucun : son vrai modèle (le mannequin R15 `Heros_Tireur` n'est plus utilisé, #13) |
| les 58 autres | un des 6 profils selon leur rôle (`Epeiste`, `Tireur`, `Archer`, `Barbare`, `Paladin`, `Magicien`) | aucun : le combat pose le **vrai modèle** du héros (`ReplicatedStorage.Assets.Heros`, par `HeroId`, statique) |

HeroConfig est la **seule** table de correspondance : le serveur (arène, combat) et le client
(héros dans les mains) la lisent. `Heros_EcuyerDuRempart` est la copie articulée de
`Workspace.AtelierAnimation.EcuyerDuRempart` (`JeuAnimations = EcuyerDuRempart` : Marche, Attaque,
Ultime jouées en combat ; Studio uniquement tant que les séquences n'ont pas d'`AssetId`, voir
`ANIMATION_TOOLS.md`). Un modèle articulé n'a que sa racine ancrée en arène. La Tireuse et les
autres héros n'ont pas encore d'animation : leur vrai
modèle est posé tel quel (comme le slime).

## Raretés

`src/shared/Config/RarityConfig.lua` (partagé), du rang 1 au rang 10. Chance de tirage en pour dix
mille (somme 10 000) ; couleurs dans `UITheme.Rarity` (Transcendant : dégradé `UITheme.RarityPrism`).
Les monstres n'ont **aucune** rareté.

| Rang | Id | Libellé | Chance | Héros |
| --- | --- | --- | --- | --- |
| 1 | `Commun` | Commun | 50 % | 2 |
| 2 | `PeuCommun` | Peu commun | 25 % | 4 |
| 3 | `Rare` | Rare | 13 % | 6 |
| 4 | `Epique` | Épique | 7 % | 8 |
| 5 | `Legendaire` | Légendaire | 3,5 % | 10 |
| 6 | `Mythique` | Mythique | 1 % | 10 |
| 7 | `Maudit` | Maudit | 0,3 % | 8 |
| 8 | `Supreme` | Suprême | 0,12 % | 6 |
| 9 | `Calamite` | Calamité | 0,06 % | 4 |
| 10 | `Transcendant` | Transcendant | 0,02 % | 2 |

Un palier sans héros invocable reporte sa chance sur le palier inférieur le plus proche qui en a
(au supérieur s'il n'y en a aucun) : la somme reste 10 000 (`SummonRules.buildPool`, testé).

## Bannières

`SummonBannerConfig` définit trois bannières : Appel du Royaume, Première Aube et Serment Brisé. Une seule est active, par créneau UTC de **15 minutes**, identique sur tous les serveurs. `Featured` garde l'ordre vedette principale puis deux secondaires. Pool commun de 60 héros ; `FeaturedShare = 0,5` réserve la moitié des tirages de la rareté au sous-pool vedette, l'autre moitié au pool complet. Les probabilités exactes incluent ces deux chemins. Voir [SUMMON.md](SUMMON.md).

## Données (`PlayerData`, DataVersion 4)

- `Heroes : { [HeroInstanceId] = { HeroId, Level, XP } }` : un exemplaire par identifiant unique
  (`H_T<horodatage><séquence>_<GUID>`). KingdomService range les héros dans l'ordre d'obtention :
  anciens `H_<GUID>` d'abord (quelle que soit la casse), puis les identifiants horodatés par date ;
  le starter reste donc sur `Heros_1`. **Doublons autorisés** : même `HeroId`, `HeroInstanceId`
  différent.
- `Hotbar : { string }` : **exactement 10** identifiants d'exemplaires, `""` = raccourci vide
  (pas de tableau à trous). La hotbar et l'arène utilisent toujours le `HeroInstanceId`.
- `Summons : { Total }` : invocations réussies ; `Total = 0` → la prochaine est la première.

### Migration v1 → v2 (`src/server/Data/Migrations.lua`)

Les profils v1 avaient pour `HeroId` les classes temporaires `Archer`, `Epeiste`, `Barbare`,
`Paladin`, `Magicien`, `Tireur`. L'étape v1 → v2 est historique (valeurs figées, elle ne lit pas
HeroConfig) et déterministe :

1. un `ecuyer_du_rempart` existe déjà → il est conservé ;
2. sinon un exemplaire `Epeiste` existe → **le même `HeroInstanceId`** devient `ecuyer_du_rempart`
   (niveau et raccourci conservés) ;
3. sinon l'exemplaire legacy au plus petit identifiant devient `ecuyer_du_rempart` ;
4. sinon (aucun legacy) rien n'est converti.

Puis tous les autres exemplaires legacy sont retirés ; les cases de `Hotbar` qui les visaient
deviennent `""` (même taille) et `Team` est recompactée. Les vrais `HeroId` déjà présents, les
devises, tickets, `FirstClears`, quêtes, royaume et réglages ne sont pas touchés.

## Niveaux et XP (#68) — ALPHA 0.0.2 PROVISOIRE

La progression appartient à l'**exemplaire** (`HeroInstanceId`) : deux exemplaires du même `HeroId`
ont chacun leur niveau. `HeroId` (catalogue) ≠ `HeroInstanceId` (exemplaire) ≠ `CombatProfile` (stats).

- **Niveaux Lv1 → Lv20** (`HeroProgressionConfig.MaxLevel`). Pas d'étoiles, d'ascension, de fragments,
  de talents ni de fusion.
- **XP relative au niveau courant** : `Level = 3, XP = 40` = Lv3, 40 XP vers Lv4 (pas d'XP cumulée).
  Nouveau héros : `Level = 1, XP = 0`. Au Lv20 : `XP = 0`, plus aucune XP gagnée.
- **Courbe (provisoire)** : XP de Lv n à n + 1 = `100 + 25 × (n - 1)` → 100, 125, 150 … 550 (Lv19 → 20).
  Plusieurs niveaux possibles d'un coup ; le surplus au Lv20 est perdu.
- **Gain (provisoire)** : **victoire seulement**, par stage (`HeroProgressionConfig.StageXP`) :
  1-1 = 25, 1-2 = 35, 1-3 = 50, 1-4 = 70, 1-5 = 100. Défaite = 0. Chaque héros **réellement posé et
  engagé** dans le combat gagne le montant complet ; un héros de la collection ou de la hotbar non posé
  ne gagne rien.
- **Gain Élite (#69, ALPHA 0.0.2 PROVISOIRE)** : table distincte `EliteStageXP` : 1-1E = 60, 1-2E = 80,
  1-3E = 110, 1-4E = 150, 1-5E = 220 ; victoire seulement. Le gain dépend de **Mode + Zone + Stage**
  (`HeroProgressionRules.stageXP(zone, stage, config, mode)`, `HeroService:GrantCombatXP(..., mode)`) :
  1-3 Élite ne donne jamais l'XP de 1-3 Normal. Les stats de niveau des héros sont les mêmes en Élite.
- **Stats** : `MaxHealth` et `AttackDamage` × `1 + (Level - 1) × 0,05`, arrondies (Lv1 = stats actuelles,
  Lv2 = 105 %, Lv10 = 145 %, Lv20 = 195 %). **Aucune autre stat ne progresse** (cadence, portée, vitesse,
  énergie, dégâts de l'ultime).
- **Serveur autoritaire** : au lancement, ArenaService fige le roster (`HeroService:GetCombatRoster` :
  case, `HeroInstanceId`, `HeroId`, profil, niveau, stats) depuis SA formation ; à la fin, l'XP n'est
  donnée (`HeroService:GrantCombatXP`) qu'une fois ZoneService ayant accepté la victoire de CETTE session,
  une seule fois (session verrouillée). Le client n'envoie ni exemplaire, ni XP, ni niveau : **aucune
  remote d'XP**. `HeroesChanged` est poussé après la mutation ; `CombatEnded.HeroProgression` donne à
  l'écran de fin `{ InstanceId, HeroId, XPGranted, LevelBefore, LevelAfter, XP, XPToNext, MaxLevel }`.
- **Vue client** (`HeroesChanged` / `GetHeroes`) : `{ Id, HeroId, Level, XP, XPToNext, MaxLevel, MaxHealth, AttackDamage }`
  par exemplaire (Lv20 : `XP = 0`, `XPToNext = 0`). `MaxHealth` / `AttackDamage` = `HeroProgressionRules.combatStats`
  du profil de combat au niveau de l'exemplaire (les mêmes valeurs qu'en combat), pour la fiche de la Sacoche ;
  lecture seule, aucun calcul côté client.
- **Interface** : « Nv. n » sur chaque raccourci et chaque carte de la sacoche ; la carte choisie montre
  « 40 / 150 XP » et une barre ; l'écran de fin a une section « Héros » (portrait, nom, Nv., « +25 XP »,
  barre qui se remplit ; montée : « NIVEAU SUPÉRIEUR ! », « Nv.1 → Nv.2 », pop et lueur dorée).
- Règles pures : `src/server/Heroes/HeroProgressionRules.lua` (`xpToNext`, `grantXP`, `combatStats`,
  `stageXP`), testées par `tools/test-heroes.ps1` (suite `progression`).

### Migration v3 → v4

Chaque exemplaire reçoit `XP` (absente ou invalide → 0) ; un `Level` entier ≥ 1 est conservé, sinon 1.
Aucun héros retiré, aucun identifiant changé ; hotbar, équipe, monnaies, First Clears, invocations,
royaume et quêtes intacts.

## Premier héros : invocation tutorielle

Un nouveau profil n'a **aucun héros** (hotbar et équipe vides) : le premier héros est obtenu pendant
l'invocation tutorielle. Rien n'est donné au chargement.

`Remotes.RequestStarterSummon` (RemoteFunction, aucun argument), config `SummonConfig.Starter`
(`HeroId = "ecuyer_du_rempart"`, `QuestId = "SummonStarter"`, `Event = "StarterHeroSummoned"`).
Le serveur vérifie : données chargées, plot, SON portail, distance, aucune invocation en cours, quête
`SummonStarter` active et pas terminée, Écuyer jamais obtenu. Puis, sans yield
(`SummonRules.starter`) : exemplaire créé (raccourci 1), **sans ticket, sans `Summons.Total`, sans
évolution du royaume** ; ensuite `KingdomService:Refresh`, `HeroesChanged`, `HeroObtained` et l'événement
de quête. La première vraie invocation (avec ticket) garantit un résultat Épique ou mieux et fait évoluer le royaume.
Impossible deux fois. Les anciens profils gardent leurs héros (migration v3).

Présentation : `GetSummonState.Starter = { Active, HeroId, Name, Rarity }` (lecture seule) pour la bannière
spéciale « Premier héros » de la fenêtre d'invocation (voir SUMMON.md). Le client ne choisit jamais le
héros : `RequestStarterSummon` n'a aucun argument.

## Invocation

`GetSummonState()` publie la bannière active, son créneau et sa prochaine borne, les tickets, coûts, probabilités normales/garanties et la disponibilité du starter. `RequestSummon({ BannerId, Slot, Quantity, ExpectedTotal })` autorise **1 / 10 / 100** résultats pour **1 / 10 / 100 tickets**. Aucun coût, héros ou taux client n'est accepté.

Le serveur revérifie le profil, le personnage vivant, le portail du joueur à 18 studs maximum, le créneau actif, la version persistée et le solde. `SummonRules.batch` prépare tout avant mutation, puis crée un identifiant indépendant par résultat, débite le lot et publie une seule mise à jour de collection/royaume. Un replay de la même version ne peut pas débiter deux fois.

Le premier résultat de la première invocation payante (`Summons.Total == 0`) est **Épique ou mieux**, aux poids des rangs 4–10 renormalisés. Les autres résultats utilisent les taux normaux de la bannière. Le starter gratuit ne touche pas ce compteur ; les profils déjà payants (`Total > 0`) ne retrouvent jamais la garantie au rejoin. Le schéma DataVersion 4 suffit.

À la première invocation payante, `Kingdom.VisualState` passe de 1 à 2 une seule fois ; `Kingdom.Level` ne change pas. Doublons, hotbar et progression XP restent indépendants par exemplaire. Voir [SUMMON.md](SUMMON.md) pour le contrat complet, les taux, les reveals et l'économie provisoire des tickets.

## Événements

- `HeroService:OnHeroObtained(callback)` (serveur) : `callback(player, Obtained)` après la sauvegarde
  dans PlayerData et le Refresh du royaume.
- `Remotes.HeroObtained` (RemoteEvent du starter et de l’adaptateur interne x1, serveur → **seul** le joueur concerné) :
  `{ InstanceId, HeroId, Name, New, Rarity }`.
- `Remotes.HeroesChanged` (RemoteEvent) : nouvelle vue de la collection après tout changement.

## Modèles côté client

Au démarrage, HeroService clone les modèles des héros **activés** de `ServerStorage.Assets.Heros`
vers `ReplicatedStorage.Assets.Heros` (attribut `HeroId`), pour la révélation de l'invocation
(`SummonEffectController`), les cartes des bannières et le combat des héros sans modèle dédié.
Copies sans script, ancrées, sans collision ni requête ; la source
ServerStorage n'est pas modifiée. Seuls les HeroId de HeroConfig sont copiés.

## Règles (`src/server/Heroes/HeroRules.lua`, pur, testé)

- **Nouveau héros** : ajouté à la première case libre de la hotbar ; hotbar pleine → il reste
  dans la collection (sacoche).
- **Hotbar normalisée** au chargement : 10 cases, uniquement des exemplaires possédés, sans doublon.
- **Héros de combat** : `combatHero` ne renvoie `{ HeroId, CombatProfile, CombatTemplate }` que pour
  un exemplaire possédé, activé dans HeroConfig et dont le profil a des stats ; sinon « héros
  inconnu » ou « héros non disponible au combat ».
- Édition manuelle de la hotbar (`Remotes.HotbarAction`) : `Assign`, `Clear`, `Swap`, sans dupliquer
  un exemplaire. La hotbar représente les héros **accessibles rapidement**, pas l'équipe : l'arène
  reste limitée à 4 héros posés.

## API serveur

| Méthode | Résultat |
| --- | --- |
| `GetCombatHero(player, instanceId)` | `{ HeroId, CombatProfile, CombatTemplate }`, ou `nil` et la raison (ArenaService) |
| `RequestSummonBatch(player, request)` | lot V2 autoritaire, ou `nil` et raison |
| `RequestSummon(player, bannerId?)` | adaptateur serveur x1 conservé pour les outils historiques |
| `CanSummon(player)` | données du joueur, ou `nil` et la raison |
| `OnHeroObtained(callback)` | voir Événements |
| `AddHero(player, heroId)` | identifiant du nouvel exemplaire (héros activé uniquement, sinon `nil`) |
| `RemoveHero(player, instanceId)` | `true` si retiré (et libéré de la hotbar) |

Chaque changement rafraîchit le royaume (`KingdomService:Refresh`) et le client (`HeroesChanged`).
ArenaService envoie au combat le **profil** (`heroOf`) et pose le **template** de l'exemplaire ;
les modèles d'arène portent `HeroId` (réel), `HeroClass` (profil) et `HeroInstanceId`.

## Debug (Studio)

`ServerStorage.DebugData:Invoke(player, "AddHero", "tireuse_des_faubourgs")` et `"RemoveHero", id`
passent par HeroService. Pour invoquer, lire `GetSummonState`, puis envoyer la requête V2 décrite dans `SUMMON.md` depuis un
client placé près du portail de son plot, ou passer par le portail (E). `"AddCurrency", "SummonTickets", 10`
donne des tickets.

## Tests

```powershell
./tools/test-heroes.ps1 -LuauPath <chemin-vers-luau.exe>      # tout
./tools/test-migrations.ps1 -LuauPath <chemin-vers-luau.exe>  # migration v1 -> v2
./tools/test-summon.ps1 -LuauPath <chemin-vers-luau.exe>      # HeroService et invocation
```

## Ultimes (brief)

Proposition d'ultime pour chacun des 60 héros (animation, intention de gameplay, durée cible) :
[`docs/ultimes/ULTIMES.md`](ultimes/ULTIMES.md) et ses données [`ultimes_60_heros.json`](ultimes/ultimes_60_heros.json).
Concepts à valider et équilibrer, rien n'est encore développé (sauf l'ultime actuel de l'Écuyer).
