# Héros possédés, hotbar et invocation — HeroService (#10)

Boucle Alpha fermée : Combat → récompense (RewardService, +1 `SummonTicket` au premier clear de 1-1)
→ invocation au portail de son plot → nouveau héros → collection / hotbar → royaume.
Hors scope : niveaux, rareté, vrai gacha, interface d'invocation (#11).

## HeroId réel ≠ profil de combat

`HeroId` est l'identifiant **réel** du héros : le même que l'attribut `HeroId` des modèles de
`ServerStorage.Assets.Heros`. C'est lui qui est sauvegardé, jamais une classe de combat.

Le catalogue des héros **activés** est `src/shared/Config/HeroConfig.lua` (partagé). Chaque entrée
porte, en plus du nom et du monogramme provisoire, deux détails Alpha temporaires :

| HeroId | Nom | `CombatProfile` (stats, `CombatConfig.Heroes`) | `CombatTemplate` (`ReplicatedStorage.Assets.Combat`) |
| --- | --- | --- | --- |
| `ecuyer_du_rempart` | Écuyer du Rempart | `Epeiste` | `Heros_Epeiste` |
| `tireuse_des_faubourgs` | Tireuse des Faubourgs | `Tireur` | `Heros_Tireur` |

HeroConfig est la **seule** table de correspondance : le serveur (arène, combat) et le client
(héros dans les mains) la lisent. Les mannequins `Heros_*` restent provisoires ; les 20 autres
assets réels ne sont pas encore activés (non jouables, pas dans le pool).

## Données (`PlayerData`, DataVersion 2)

- `Heroes : { [HeroInstanceId] = { HeroId, Level } }` : un exemplaire par identifiant unique
  (`H_<GUID>`). **Doublons autorisés** : même `HeroId`, `HeroInstanceId` différent.
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
4. sinon (aucun legacy) rien n'est converti ; HeroService donne le starter au chargement.

Puis tous les autres exemplaires legacy sont retirés ; les cases de `Hotbar` qui les visaient
deviennent `""` (même taille) et `Team` est recompactée. Les vrais `HeroId` déjà présents, les
devises, tickets, `FirstClears`, quêtes, royaume et réglages ne sont pas touchés.

## Héros de départ

`HeroConfig.StarterHeroes = { "ecuyer_du_rempart" }`. Chaque HeroId de départ absent de la
collection est ajouté une fois au chargement (`HeroRules.grantStarter`). Un nouveau joueur a donc
**exactement 1 héros** (l'Écuyer, raccourci 1) ; un joueur qui le possède déjà ne reçoit rien
(rejoin). Un Écuyer retiré à la main (debug) est redonné au chargement suivant.

## Invocation

`Remotes.RequestSummon` (RemoteFunction). **Le client n'envoie rien** : HeroId, coût, rareté et
résultat sont décidés par le serveur ; tout argument est ignoré. Réponse : `(true, Obtained)` ou
`(false, raison)`.

Conditions vérifiées par le serveur (`HeroService:CanSummon`), réglages dans
`src/server/Config/SummonConfig.lua` :

- joueur présent, `DataLoaded`, profil disponible ;
- plot attribué et **son** `PortailInvocation` (`PlotService:GetPlot(player).PortailInvocation`,
  jamais `PlotTravail`, jamais une Instance fournie par le client) ;
- personnage vivant, à **18 studs** au plus (distance horizontale, position serveur) du pivot de ce
  portail : près du portail d'un autre joueur → refus ;
- `SummonTickets >= Cost` (1) ; aucune invocation déjà en cours pour ce joueur.

Transaction (`SummonRules.summon`, pure, **sans yield**) : revérifier le ticket → choisir le héros →
ticket −1 → nouveau `HeroInstanceId` → ajout aux `Heroes` → première case libre de la hotbar (sinon
collection) → `New` = premier exemplaire de ce HeroId → `Summons.Total + 1` → à la première
invocation seulement, `Kingdom.VisualState` 1 → 2. Deux demandes avec un seul ticket : une seule
réussite, un seul héros, ticket final 0. Ensuite : `KingdomService:Refresh`, `HeroesChanged`,
`HeroObtained`.

**Tirage Alpha** (pas de gacha) :

- toute première invocation du profil (`Summons.Total == 0`) → **`tireuse_des_faubourgs`**, toujours
  (différente du starter). Un profil qui la possède déjà (test, migration) la reçoit quand même :
  c'est un doublon, `New = false` ;
- invocations suivantes (tests) → un héros du pool `SummonConfig.Pool` (héros activés), au hasard.

**Royaume** : `VisualState` 1 → 2 une seule fois (première invocation), jamais au-delà dans #10.
`Kingdom.Level` n'a pas encore de règle et n'est pas modifié. Les héros apparaissent sur les
repères du royaume dans l'ordre de leurs identifiants (`KINGDOM.md`).

## Événements

- `HeroService:OnHeroObtained(callback)` (serveur) : `callback(player, Obtained)` après la sauvegarde
  dans PlayerData et le Refresh du royaume.
- `Remotes.HeroObtained` (RemoteEvent, serveur → **seul** le joueur concerné) :
  `{ InstanceId, HeroId, Name, New }`.
- `Remotes.HeroesChanged` (RemoteEvent) : nouvelle vue de la collection après tout changement.

## Modèles côté client

Au démarrage, HeroService clone les modèles des héros **activés** de `ServerStorage.Assets.Heros`
vers `ReplicatedStorage.Assets.Heros` (attribut `HeroId`), pour la révélation de l'invocation
(`SummonEffectController`, #11). Copies sans script, ancrées, sans collision ni requête ; la source
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
| `RequestSummon(player)` | `Obtained`, ou `nil` et la raison |
| `CanSummon(player)` | données du joueur, ou `nil` et la raison |
| `OnHeroObtained(callback)` | voir Événements |
| `AddHero(player, heroId)` | identifiant du nouvel exemplaire (héros activé uniquement, sinon `nil`) |
| `RemoveHero(player, instanceId)` | `true` si retiré (et libéré de la hotbar) |

Chaque changement rafraîchit le royaume (`KingdomService:Refresh`) et le client (`HeroesChanged`).
ArenaService envoie au combat le **profil** (`heroOf`) et pose le **template** de l'exemplaire ;
les modèles d'arène portent `HeroId` (réel), `HeroClass` (profil) et `HeroInstanceId`.

## Debug (Studio)

`ServerStorage.DebugData:Invoke(player, "AddHero", "tireuse_des_faubourgs")` et `"RemoveHero", id`
passent par HeroService. Pour invoquer, appeler `Remotes.RequestSummon:InvokeServer()` depuis un
client placé près du portail de son plot.

## Tests

```powershell
./tools/test-heroes.ps1 -LuauPath <chemin-vers-luau.exe>      # tout
./tools/test-migrations.ps1 -LuauPath <chemin-vers-luau.exe>  # migration v1 -> v2
./tools/test-summon.ps1 -LuauPath <chemin-vers-luau.exe>      # HeroService et invocation
```
