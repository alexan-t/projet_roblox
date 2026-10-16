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

`src/shared/Config/SummonBannerConfig.lua` (partagé) : `Appel du Royaume` (par défaut), `Première
Aube`, `Serment Brisé`. Toutes tirent dans le même pool (les 60 héros) avec les mêmes chances par
rareté. Chacune met en avant 3 héros (`Featured`) : quand la rareté tirée contient un héros mis en
avant, l'un d'eux sort une fois sur deux (`FeaturedShare = 0,5`), sinon un héros quelconque de ce
palier.

## Données (`PlayerData`, DataVersion 2)

- `Heroes : { [HeroInstanceId] = { HeroId, Level } }` : un exemplaire par identifiant unique
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

## Premier héros : invocation tutorielle

Un nouveau profil n'a **aucun héros** (hotbar et équipe vides) : le premier héros est obtenu pendant
l'invocation tutorielle. Rien n'est donné au chargement.

`Remotes.RequestStarterSummon` (RemoteFunction, aucun argument), config `SummonConfig.Starter`
(`HeroId = "ecuyer_du_rempart"`, `QuestId = "SummonStarter"`, `Event = "StarterHeroSummoned"`).
Le serveur vérifie : données chargées, plot, SON portail, distance, aucune invocation en cours, quête
`SummonStarter` active et pas terminée, Écuyer jamais obtenu. Puis, sans yield
(`SummonRules.starter`) : exemplaire créé (raccourci 1), **sans ticket, sans `Summons.Total`, sans
évolution du royaume** ; ensuite `KingdomService:Refresh`, `HeroesChanged`, `HeroObtained` et l'événement
de quête. La première vraie invocation (avec ticket) reste donc la garantie `FirstSummon` (Tireuse) et
fait évoluer le royaume. Impossible deux fois. Les anciens profils gardent leurs héros (migration v3).

## Invocation

`Remotes.RequestSummon` (RemoteFunction). **Le client n'envoie que l'Id de la bannière** (texte,
facultatif : bannière par défaut ; inconnu ou d'un autre type → refus « bannière inconnue », rien
consommé). HeroId, coût, rareté et résultat sont décidés par le serveur ; tout autre argument est
ignoré. Réponse : `(true, Obtained)` ou `(false, raison)`.
`Remotes.GetSummonState` (RemoteFunction, lecture seule) : `{ Tickets, Cost }` pour la fenêtre
d'invocation.

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

**Tirage** :

- toute première invocation du profil (`Summons.Total == 0`) → **`tireuse_des_faubourgs`**, toujours
  (différente du starter). Un profil qui la possède déjà (test, migration) la reçoit quand même :
  c'est un doublon, `New = false` ;
- invocations suivantes → une rareté selon les chances (§ Raretés), puis un héros de cette rareté
  (mise en avant de la bannière, § Bannières). `SummonRules.roll`, pur et testé.

**Royaume** : `VisualState` 1 → 2 une seule fois (première invocation), jamais au-delà dans #10.
`Kingdom.Level` n'a pas encore de règle et n'est pas modifié. Les héros apparaissent sur les
repères du royaume dans l'ordre de leurs identifiants (`KINGDOM.md`).

## Événements

- `HeroService:OnHeroObtained(callback)` (serveur) : `callback(player, Obtained)` après la sauvegarde
  dans PlayerData et le Refresh du royaume.
- `Remotes.HeroObtained` (RemoteEvent, serveur → **seul** le joueur concerné) :
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
| `RequestSummon(player, bannerId?)` | `Obtained` (avec `Rarity`), ou `nil` et la raison |
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
client placé près du portail de son plot, ou passer par le portail (E). `"AddCurrency", "SummonTickets", 10`
donne des tickets.

## Tests

```powershell
./tools/test-heroes.ps1 -LuauPath <chemin-vers-luau.exe>      # tout
./tools/test-migrations.ps1 -LuauPath <chemin-vers-luau.exe>  # migration v1 -> v2
./tools/test-summon.ps1 -LuauPath <chemin-vers-luau.exe>      # HeroService et invocation
```
