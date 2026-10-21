# Zones et stages — ZoneService

`ZoneService` (#7) décide **quel stage** un joueur peut lancer, crée la **session serveur**
correspondante et reçoit sa **fin**. Il ne fait aucun combat : ennemis, dégâts, vagues
réelles, mini-boss, x2 et victoire/défaite calculées sont le rôle de CombatService (#8).

## StageConfig

`src/server/Config/StageConfig.lua` décrit tous les stages. ZoneService ne connaît aucun
stage en particulier : ajouter un stage ou une zone se fait uniquement dans la config. Extrait (1-1) :

```lua
Zones = {
	[1] = {
		Stages = {
			[1] = {
				Waves = {
					{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 2 } } },
				},
			},
		},
	},
},
```

- Zones et stages sont des listes : identifiants entiers **consécutifs à partir de 1**.
  La clé stable d'un stage est `"<zone>-<stage>"` (Stage 1 : `"1-1"`).
- `Waves` : liste non vide de vagues ; chaque vague a une liste non vide `Enemies` de
  `{ EnemyId: string non vide, Count: entier >= 1 }`.
- `MiniBoss` : facultatif, `{ EnemyId }`, affronté après la dernière vague.
- **Convention de progression d'une zone Alpha** : X-1 à X-4 = combats d'ennemis communs, **X-5 =
  boss de zone** (`MiniBoss`, seulement sur X-5). Les six zones suivent cette convention.
- **Zone 1** (boss = `Boss`, le Roi Orc, modèle `Ennemi_RoiOrc`) :

  | Stage | Contenu | PV ennemis |
  | --- | --- | --- |
  | 1-1 | Slime ×2, Gobelin ×2 — stage d'entrée, gagnable par le héros de départ seul | 280 |
  | 1-2 | Slime ×3, Gobelin ×2 | 340 |
  | 1-3 | 2 vagues : Slime ×2 + Gobelin ×2, puis Slime ×2 + Gobelin ×1 | 480 |
  | 1-4 | 2 vagues : Slime ×2 + Gobelin ×2, puis Gobelin ×3 | 520 |
  | 1-5 | Slime ×2 + Gobelin ×1, puis **le Roi Orc** | 650 |

  Simulations (CombatEngine + CombatConfig, 20 tirages, tests #13) : l'Écuyer seul gagne 1-1 ;
  l'Écuyer + n'importe quel deuxième héros (chaque profil de combat ; aucun n'est garanti) gagnent 1-1
  à 1-5. Un stage
  n'est jouable qu'après le First Clear du précédent (RewardService, `docs/REWARDS.md`).
- `EnemyId` est un **identifiant logique**. Stage 1 reprend les types de la vague de
  démonstration de `CombatIntroController` (`Slime`, `Gobelin`, `Boss`). Aucune statistique
  (PV, dégâts, vitesse), aucun modèle, aucune position : CombatService (#8) associera ces
  identifiants à leurs stats et à leurs modèles (future `EnemyConfig`).
- Validation au démarrage :
  - structure `Zones` / `Stages` invalide : avertissement, **aucun** stage lançable ;
  - contenu d'un stage invalide : avertissement, **ce stage** refusé (`"stage indisponible"`),
    les autres restent jouables. Pas de crash.
- La config est copiée et gelée au démarrage : ni une session ni un appelant ne peut la modifier.

## Mode Élite (#69) — ALPHA 0.0.2 PROVISOIRE

Après le **Roi Orc** (First Clear Normal de 1-5), la Zone 1 se rejoue en **Élite** : 1-1E → 1-2E → 1-3E →
1-4E → 1-5E (pas de 1-6E). Même map, mêmes stages (`StageConfig`), mêmes ennemis et `EnemyId`, mêmes
entrées depuis le décor, même CombatEngine, même ArenaService. Seule la difficulté change, côté serveur.

- **Identité** : une session de stage porte `Mode` (`"Normal"` / `"Elite"`), `Zone`, `Stage` ;
  `ZoneService:StartStage(player, zone, stage, mode)`, `CanStartStage`, `ListStages(player, mode)`,
  `IsEliteUnlocked(player, zone)`. Mode absent = Normal (comportement existant inchangé).
- **Config** : `src/server/Config/EliteConfig.lua` : `UnlockAfter = "1-5"` et, par stage, les
  multiplicateurs ennemis (seulement `MaxHealth` et `AttackDamage`) :

  | Stage | PV | ATK |
  | --- | --- | --- |
  | 1-1E | ×1,50 | ×1,25 |
  | 1-2E | ×1,65 | ×1,30 |
  | 1-3E | ×1,80 | ×1,35 |
  | 1-4E | ×2,00 | ×1,40 |
  | 1-5E | ×2,25 | ×1,50 |

- **Progression** : `Progression.EliteFirstClears` (même format que `FirstClears`, indépendante). Vide pour
  tout profil, nouveau ou ancien : aucun clear Élite rétroactif. Ajoutée aux anciens profils par
  `Profile:Reconcile()` (clé fixe de `Progression`) : **pas de migration**, DataVersion reste 4.
  Un stage Élite n'est jouable qu'après le First Clear Élite du précédent ; le premier, dès 1-5 Normal.
- **Fin** : une victoire Élite émet `EliteStageCompleted` pour les quêtes (jamais `StageCompleted` : une
  quête Normale ne progresse pas par accident), puis RewardService en mode Élite (`REWARDS.md`).
- **Sélection** : le stage choisi porte son mode ; après une victoire Élite, le stage Élite suivant est
  sélectionné (1-5E reste 1-5E). Au join / rejoin, la sélection repart en Normal (aucune préférence
  sauvegardée) ; l'onglet Élite propose son premier stage débloqué non terminé.
- **Sécurité** : le client n'envoie que des entiers et un nom de mode (`SelectStage`, `RequestStartStage`) ;
  mode inconnu, Élite verrouillée, stage Élite précédent non terminé, stage ou zone inconnus (1-6E) :
  refusés. Aucune stat, aucun multiplicateur, aucune récompense ne vient du client.
- **Interface** : fenêtre Expédition avec onglets **Normal** / **Élite** (« Élite · verrouillé » avant 1-5,
  cartes Élite consultables, « Termine 1-5 pour débloquer l'Élite ») ; cartes Élite marquées « Élite »,
  titre en rouge royal ; pancarte « Stage 1-3 » + pastille « Élite », pastille « F · Lancer … · ÉLITE ».

## Règles d'accès

`CanStartStage(player, zone, stage)` refuse, dans cet ordre :

| Raison | Condition |
| --- | --- |
| `"données non chargées"` | joueur parti, `DataLoaded` absent ou profil absent |
| `"aucun plot"` | `PlotService:GetPlot(player)` ne renvoie rien : le stage se lance depuis son plot |
| `"stage inconnu"` | zone ou stage absent de la config, ou identifiant non entier |
| `"stage indisponible"` | stage présent mais config invalide |
| `"stage verrouillé"` | le stage précédent n'est pas dans `Progression.FirstClears` |
| `"session déjà en cours"` | une session active existe déjà pour ce joueur |

Le stage précédent est le stage `n - 1` de la même zone, ou le dernier stage de la zone
précédente pour le premier stage d'une zone. **Zone 1 / Stage 1 est toujours ouvert.**
ZoneService **ne modifie pas PlayerData** : `FirstClears` est écrit par RewardService (#9)
avec la même clé `"<zone>-<stage>"`. `CurrentZone` et `HighestStage` ne sont pas utilisés.

## Session

Une session est **runtime uniquement** (jamais sauvegardée) et au plus **une par joueur**.
`StartStage` et `GetSession` renvoient une vue gelée :

```lua
{ Id = 1, Zone = 1, Stage = 1, Status = "Running", Config = <config du stage, gelée> }
```

À chaque accès, la session est revérifiée : joueur présent, `DataLoaded`, profil chargé et
**même plot** qu'au lancement. Sinon elle est supprimée, sans attendre un signal. Elle est
aussi supprimée à `PlayerRemoving`.

## API serveur

| Méthode | Résultat |
| --- | --- |
| `CanStartStage(player, zone, stage)` | `true`, ou `false` et la raison |
| `StartStage(player, zone, stage)` | vue de la session, ou `nil` et la raison |
| `GetSession(player)` | vue de la session active, ou `nil` |
| `CompleteStage(player, sessionId, victory)` | `true` si la session active `sessionId` est terminée |
| `CancelStage(player)` | `true` si une session active a été annulée |
| `ListStages(player)` | tous les stages de `StageConfig` dans l'ordre, avec `Status` (`Unlocked` / `Locked` / `Unavailable`), `Cleared` (First Clear) et la config ; liste vide sans données |

Cycle : `Running` → `CompleteStage(victoire)` ou `CompleteStage(défaite)` ou `CancelStage`.
Dans tous les cas la session disparaît et le joueur peut relancer un stage autorisé.
`sessionId` empêche une fin tardive d'une ancienne session de terminer la nouvelle.

## Action client → serveur

`ReplicatedStorage.Remotes.RequestStartStage` (RemoteFunction, créée par le serveur au démarrage) :

```lua
local ok, reason = Remotes.RequestStartStage:InvokeServer(1, 1)
```

- Le client n'envoie que `zone` et `stage`, deux entiers. Tout autre argument est ignoré.
- Le serveur applique les mêmes règles que `StartStage` ; réponse `(ok, raison?)`.
- Le client ne fournit jamais d'ennemis, de vagues, de config, de résultat ni de récompense.
  Il n'existe **aucune** action client pour terminer un stage.

Le jeu passe par l'arène (#11) : la pancarte du stage envoie `ArenaAction("SelectStage", zone, stage)`, qui revalide avec `ListStages` ; le premier héros posé lance la session via `StartStage` (voir `docs/ARENA_PROTOTYPE.md`).

## Fenêtre Expédition — aperçu des stages (lecture seule)

`ArenaState.Stages` et `ArenaState.EliteStages` contiennent, par stage, ce que fournit `ArenaService.stagesOf`. Ce sont des données en **lecture seule** : rien n'est accordé ni modifié côté gameplay.

| Champ | Source réelle |
| --- | --- |
| `Zone`, `Stage`, `Mode`, `Status`, `Cleared` | ZoneService (`FirstClears` / `EliteFirstClears`) |
| `Waves = { { Enemies = { { EnemyId, Count } } } }` | `StageConfig`, vague par vague |
| `Boss` | `MiniBoss.EnemyId` (1-5 : Roi Orc) |
| `HeroXP` | `HeroProgressionConfig`, XP **par héros posé** |
| `FirstClearRewards`, `RepeatRewards` | `RewardConfig` (vide = rien affiché) |
| `Multipliers = { MaxHealth, AttackDamage }` | `EliteConfig` (Élite seulement) |
| `PotentialDrops?` | table de butin réelle (#72) : `{ Kind = "Resource" \| "Item", Id, Chance 0..1, Min?, Max? }` |

- **Construction** : `Server.Arena.StagePreview.build`, un module pur qui copie les configs (testé).
- **Butin** : sans table de butin réelle, `PotentialDrops` vaut `nil` et la fenêtre affiche « Butin à venir ». Aucun pourcentage n'est inventé.
- **Élite verrouillée** : le message de déblocage utilise la vraie progression Normal (`X/5 stages terminés`).

## Contrats

- **QuestService (#6)** : sur une **victoire** uniquement, ZoneService appelle
  `QuestService:HandleGameplayEvent(player, "StageCompleted", { Zone = zone, Stage = stage })`,
  une seule fois par session. Rien au lancement, à la défaite, à l'annulation ni au départ.
- **CombatService (#8)** : lit la session (`GetSession`) et sa `Config` pour créer le vrai
  combat (vagues, mini-boss). À la fin, il appelle
  `ZoneService:CompleteStage(player, session.Id, victory)`. C'est le seul appelant prévu.
- **RewardService (#9)** : à la victoire, juste après QuestService, ZoneService appelle
  `RewardService:HandleStageCompleted(player, zone, stage, session.Id)`. L'id de session sert
  d'identité de completion. RewardService gère le First Clear (`FirstClears["<zone>-<stage>"] = true`,
  ce qui déverrouille le stage suivant), les récompenses de replay et le ticket initial.
  `CompleteStage` renvoie `(true, { FirstClear, Rewards })` à CombatService, qui l'envoie au client.
  ZoneService n'écrit lui-même **aucune** récompense, devise ni ticket. Voir `docs/REWARDS.md`.

## Validation

```powershell
./tools/test-zones.ps1 -LuauPath <chemin-vers-luau.exe>
```

Le vrai module est exécuté avec la vraie config (et des configs de test) et des doubles
de DataService, PlotService et QuestService.

En Studio, `ServerStorage.DebugData` (Studio uniquement) simule CombatService depuis la
ligne de commande côté Serveur : `"StartStage", 1, 1`, `"GetStageSession"`,
`"CompleteStage", true | false` et `"CancelStage"`. Le vrai combat de Stage 1 (ennemis,
vagues physiques, mini-boss) ne pourra être testé qu'avec #8.

## Zones 2 à 6 — Alpha provisoire

Le parcours reste celui de WORLD.md : le joueur choisit une expédition depuis **son arène**,
le décor change sur place. Les plots de démonstration de `Workspace.PlotsZones` ne sont pas
les points d'accès au gameplay.

**Vitrine visitable (sandbox « test 3 »)** : `tools/studio-zones-vitrine.luau` (après
`studio-zones-assets.luau`) reconstruit `Workspace.PlotsZones.Plot_Zone2` à `Plot_Zone6` : cinq copies du plot
alignées au sud du Lobby (z ≈ −360, x = 120 à 880), entrée tournée vers le Lobby. **L'avant (herbe, royaume,
portail) reste celui du plot, toujours en herbe** ; seul ce qui est derrière le portique prend le biome (arène,
bordure ; arbres remplacés par colonnes, cheminées, coraux ou nuages ; sol de biome ovale autour de l'arène,
`PlotsZones.SolsBiomes`). La jonction est une lisière irrégulière (`LisiereArene` : dunes, congères, basalte et
braises, récifs et coraux, nuages), posée en désordre avec des taches de sol du biome qui mordent sur l'herbe,
ouverte au portique ; pas de mur. Chaque arène expose ses six monstres (`MonstresDeLaZone`). On y va à pied par le passage
du mur sud du Lobby (x ≈ 331, `PlotsZones.CheminZones` ; murs et arbres retirés rangés dans
`ServerStorage.Archive_PassageZones`). Aucun script, aucun combat : ce sont des lieux à visiter.

**Version B (octobre 2026)** : chaque zone a sa propre faune, celle des fiches de production des
monstres (`automation/briefs`, socles Monstres #23 à #52 du Bestiaire). Cinq monstres communs par zone ;
en X-5, le **monstre fort de fin de zone** de la fiche sert de boss. Les trois boss validés (Roi Orc,
Slime King, King Tréant) ne servent plus qu'en Zone 1 (Roi Orc) et restent dans `CombatConfig`.
Aucune rareté de monstre, aucun nouveau système de butin.

| Zone | Biome | Ennemis (X-1 à X-5) | Boss X-5 | Niveau cible de simulation |
| --- | --- | --- | --- | --- |
| 2 · Le Royaume des Sables | Temple ensablé (colonnade, pyramide à degrés, temple sur dais), énorme tête de statue qui sort du sable, crêtes de grès, oasis et canal ancien asséché, avant-poste du désert (palissades, auvent, drapeaux déchirés), amphores, ossements | VaseDesSables, ChacalParchemin, ScarabeeForgeSoleil, MangeDune, GardienSansVisage | ColosseEnseveli | 4 |
| 3 · Les Terres Gelées | Donjon de glace : remparts crénelés, tours, stalactites, trône du Roi, lac gelé | Givrelot, CrocDeGlacier, ArmureGelee, BonhommeRoyal, MammouthCristallin | RoiSansEte | 8 |
| 4 · Les Forges | Forteresse de basalte : grand fourneau, rigoles de métal en fusion, enclumes | ChevalierRivete, GolemCloche, FourneauAmbulant, Martelet, Chaine | MaitreDesForges | 12 |
| 5 · Les Abysses | Récif englouti : épave, coquillages géants, bulles, anémones, coffre | MeduseCouronnee, MureneMiroir, CoffreBernard, ChevalierNoye, CrabeCathedrale | Leviathan | 16 |
| 6 · Les Îles du Ciel | Sanctuaire céleste : bancs de nuages, arches de marbre, dôme d'or, statues ailées | GargouilleAilee, MiniColosseCeleste, MoutonNuage, PoissonDuCiel, BecTonnerre | GardienCeleste | 20 |

**Décors** (`tools/studio-zones-assets.luau`) : chaque arène a son propre décor, construit autour des sorties
d'ennemis de `SourcesEnnemis` (plateau, rampe, porte, tour, trois sorties au sol, aux mêmes places que la Zone 1).
De la Zone 1, on ne garde que le lac (couleur et matière du biome), le portique d'entrée et ces repères invisibles.

**Équilibrage conservé** : chaque nouveau monstre reprend les stats de l'archétype qu'il remplace
dans les vagues de la version précédente (ex. `VaseDesSables` = `Slime`, `ColosseEnseveli` = `KingSlime`,
`MaitreDesForges` = `Boss`). Les vagues gardent les mêmes totaux de PV et de dégâts ; la simulation #13
(`CombatEngine.spec`) passe sans retouche des niveaux cibles. L'archétype de chaque monstre est noté
à côté de ses stats dans `CombatConfig` (« comme Slime »…). Valeurs Alpha provisoires, pas un balancing final.

Chaque zone comprend cinq stages. X-1 est débloqué par le First Clear de (X-1)-5 ;
X-2 à X-5 suivent les First Clears de leur prédécesseur. Chaque boss X-5 est le monstre fort
de la faune de sa zone, renforcé par la difficulté de zone. Après une victoire, la sélection peut
passer au premier stage de la zone suivante ; après 6-5, elle reste sur 6-5.
Les flèches du titre d'Expédition permettent de consulter les zones voisines, y compris
verrouillées. Les onglets Élite ne sont proposés que pour une zone réellement configurée :
**seule la Zone 1 possède un mode Élite**.

### Équilibrage

`StageConfig.Zones[zone].Difficulty` multiplie uniquement MaxHealth et AttackDamage.
Le module pur `Combat/Difficulty` valide ces facteurs et les combine avec ceux de l'Élite.
Ces valeurs et les niveaux ci-dessus sont **provisoires**. Le test CombatEngine utilise
cinq graines et trois compositions de quatre héros : chaque stage est gagné au niveau cible,
et le boss résiste majoritairement aux équipes au niveau cible de la zone précédente.
Ce test ne garantit pas que toutes les équipes gagnent ; le test Studio utilise une équipe
au niveau 20 pour contrôler le fonctionnement des cinq boss.

L'XP par héros posé augmente de zone en zone (`HeroProgressionConfig`). Chaque stage a une
entrée dans RewardConfig afin de sauvegarder son First Clear : récompenses de premier clear
vides provisoires, replay X-1 = 20 or, X-2..5 = 1/1/2/5 tickets, comme la Zone 1.
Aucune table de ressources ou d'équipements n'est ajoutée.

### Décor des zones

`Server/Arena/ZoneDecor` conserve un seul décor actif dans `Arene.Zones`. Les décors inactifs
sont rangés dans `ServerStorage.ZonesRangees_<plot>` et les nouveaux sont copiés depuis
`ServerStorage.Assets.ZonesArene`. Chaque gabarit porte ZoneId et Nom, et son pivot est celui
de l'arène de référence. `PivotTo(arena:GetPivot())` conserve les positions relatives sur
les huit plots. Chaque décor fournit `SourcesEnnemis.FrontEnnemi` et les sources d'entrée.

Le décor reste visible pendant l'outro. Une relance explicite avant sa fin installe néanmoins
le décor du nouveau combat avant sa création. Un décor ou un front absent refuse le lancement.
Le serveur et le client lisent les repères du décor courant ; les autres plots ne changent pas.

### Assets Studio

Dans le sandbox « test 3 », exécuter les outils d'assets en mode Edit via MCP ou la barre de
commande, **sans créer de Script ou modifier de Source** :

1. `tools/studio-zones-assets.luau` copie les monstres de chaque zone (30 pour la version B) vers
   `ReplicatedStorage.Assets.Combat` et construit les cinq décors depuis la Zone 1 de Plot_1.
   Si les modèles de base manquent, il copie Slime_Eau, GobLanceT_A et RoiOrc ; il conserve
   les versions de combat existantes. Les copies supplémentaires sont statiques et utilisent
   la mise en scène générique (charge/bascule), pas un nouveau squelette animé.
2. `tools/studio-zone-stage-signs.luau` installe les pancartes Expédition manquantes sur les
   huit arènes, relativement à PointEtendard. Il conserve toute pancarte déjà présente.
   Les textes et interactions viennent du contrôleur client et de UITheme.

Les outils enregistrent une étape ChangeHistoryService. Relancer Rojo depuis ce checkout et
connecter le plugin avant Play. Aucun asset de map n'est versionné dans Git et rien n'est publié.
`DebugData("SetHeroLevel", instanceId, niveau)` permet de préparer une équipe de test en Studio ;
le niveau doit être entier, compris entre 1 et MaxLevel, et le héros doit appartenir au joueur.
Cette fonction n'existe pas dans une partie publiée et n'ajoute aucune remote client.

Deux contrôles en lecture seule (aucune étape ChangeHistoryService, rien n'est modifié) :
`tools/studio-check-menu-icons.luau` précharge les images du menu et liste celles qui
échouent ; `tools/studio-check-two-players.luau`, côté serveur pendant un test à deux
clients, vérifie plots, décors et combats séparés. Procédure : `docs/ZONES_QA.md` § Reprise.

Validation datée, limites du sandbox et captures : `docs/ZONES_QA.md`.
