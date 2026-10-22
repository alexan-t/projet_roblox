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
| `PotentialDrops?` | `LootConfig` via `LootRules.preview` (#72) : `{ Kind = "Resource" \| "Item", Id, Chance 0..1, Min?, Max? }` ; ressources avec leurs chances réelles, items précis configurés (aucun aujourd'hui) |

- **Construction** : `Server.Arena.StagePreview.build`, un module pur qui copie les configs (testé).
- **Butin (#72)** : `ArenaService` construit `PotentialDrops` depuis `LootConfig` (`LootRules.preview`, valeurs **ALPHA 0.0.2 PROVISOIRE**). Il liste les ressources avec leurs chances réelles. Le contrat `Drop` n'est pas étendu (pas de `Kind` ItemPool) : l'équipement aléatoire n'est donc **pas** listé ligne par ligne, seuls d'éventuels items précis configurés (`Items`, aucun aujourd'hui) le seraient. Sans table pour le stage, ou si `LootConfig` est invalide (aucun loot n'est alors accordé), `PotentialDrops` vaut `nil` et la fenêtre affiche « Pas de butin pour l'instant ». Aucun pourcentage n'est inventé.
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
  ce qui déverrouille le stage suivant), les récompenses de replay, le ticket initial et, depuis #72,
  le loot (même section synchrone, voir `docs/REWARDS.md` § Loot).
  `CompleteStage` renvoie `(true, { FirstClear, Rewards, Loot? })` à CombatService, qui l'envoie au client.
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
bordure ; arbres remplacés par colonnes, cheminées, coraux ou nuages ; aucun sol ne dépasse du plot).
La jonction est une lisière irrégulière (`LisiereArene` : dunes, congères, basalte et
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
| 3 · Le Royaume Gelé | Remparts de glace crénelés et stalactites, château prisonnier d'un glacier au fond, falaises glacées et cascade gelée, lac gelé et pont verglacé, fort gelé (barricades, tour, drapeaux), ruines et statues prises dans la glace, arbres enneigés, lanternes froides | Givrelot, CrocDeGlacier, ArmureGelee, BonhommeRoyal, MammouthCristallin | RoiSansEte | 8 |
| 4 · Les Forges | Forteresse de basalte : grand fourneau, rigoles de métal en fusion, enclumes | ChevalierRivete, GolemCloche, FourneauAmbulant, Martelet, Chaine | MaitreDesForges | 12 |
| 5 · La Cité Engloutie | Récif englouti : épave, coquillages géants, bulles, anémones, coffre | MeduseCouronnee, MureneMiroir, CoffreBernard, ChevalierNoye, CrabeCathedrale | Leviathan | 16 |
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
Un décor peut déplacer ses repères : dans la Zone 3, sans plateau, `Tente` et `HautRampe` (sorties du boss et
des ennemis « camp ») sont devant la grande porte du château, `BordPlateau1/2` au pied de la porte et
`SommetTour` sur la corniche du donjon (`moveMarkers` dans `tools/studio-zones-assets.luau`).

Le décor reste visible pendant l'outro. Une relance explicite avant sa fin installe néanmoins
le décor du nouveau combat avant sa création. Un décor ou un front absent refuse le lancement.
Le serveur et le client lisent les repères du décor courant ; les autres plots ne changent pas.

### Règles de décor (obligatoires pour chaque zone)

**Structure type**, du point de vue de la caméra du joueur, à garder pour toutes les zones :

| Plan | Contenu |
| --- | --- |
| Bas | Zone des héros (cases `CaseHeros`) |
| Milieu | Voie de combat (zone de bataille, règle 2) |
| Haut | Zone ennemie (`FrontEnnemi`) |
| Tout en haut, au fond | Structure du boss (règle 1) : porte, temple, forge, trône, faille, autel ou plateforme |

1. **Structure d'apparition du boss, propre à la zone.** Le petit plateau de la Zone 1 (plateau, rampe,
   porte et tour derrière le front ennemi) n'est **pas** un élément obligatoire des autres zones : il ne servait
   qu'à faire apparaître le boss de la Zone 1. Chaque zone doit avoir **sa propre belle structure**, dans son
   biome, d'où le boss sort : par exemple la grande porte du château prisonnier du glacier en Zone 3. Les
   repères de `SourcesEnnemis` utilisés par le boss (`Tente` = SortieTente, `HautRampe` = DescenteRampe, avec
   leurs `Etape1`, `Etape2`…) sont posés sur cette structure, et les repères restants du plateau
   (`BordPlateau1/2`, `SommetTour`) sont déplacés dessus ou à son pied (`moveMarkers`). Ne pas recopier le plateau.
2. **Zone de bataille au centre.** Comme la clairière de sable de la Zone 1 (`Sol.Clairiere` : large bande au
   milieu de l'arène, d'une autre couleur que l'herbe, aux bouts arrondis), chaque zone a au centre un sol
   **d'une couleur nettement différente** de son sol, là où les unités se battent : de l'entrée jusqu'à la
   structure du boss, sous les cases des héros et `FrontEnnemi`. Outil : `battleground` (bande de 44 studs,
   disques avant et fond, quelques taches plus sombres), juste au-dessus du sol de zone et sous les accessoires.
   Zone 3 : neige damée bleutée `#A7C5E0` sur la neige `#E4EDF5`.
3. **Un fond haut et impressionnant, une arène habitée.** Derrière la structure du boss, le décor doit monter
   assez haut pour cacher l'horizon et les plots voisins depuis la caméra de combat (Zone 4 : citadelle de
   42 à 52 studs, cheminées de 66 à 76), et le rempart monter vers le fond. Les flancs, hors zone de bataille,
   sont remplis d'éléments du biome (ateliers, réserves, lumières) : pas de grands sols nus.
4. **Une limite légère avec l'avant du plot.** Entre l'arène et l'avant du plot (portique d'entrée, royaume),
   une limite basse en décor du biome, avec un passage au centre en face du portique : elle sépare les deux
   espaces sans fermer l'arène ni bloquer le joueur (pièces sans collision). Zone 4 : `frontBoundary`.

| Zone | Structure du boss | Zone de bataille |
| --- | --- | --- |
| 1 | Plateau et tour du camp (d'origine) | Clairière de sable |
| 2 | Plateau générique (temple sur dais) | **À faire** |
| 3 | Grande porte du château glaciaire | Neige damée bleutée `#A7C5E0` |
| 4 | **Porte-Fournaise** : immense porte de métal encastrée dans la grande forge, qui s'ouvre (voir § Porte du boss) | Dalles chaudes `#8A7462` |
| 5 | Temple-coquille de la Cité Engloutie, porte couverte de coraux (§ Cité Engloutie) | Sable du fond `#B4A584` |
| 6 | **Sanctuaire du Ciel** : plateforme céleste flottante, invocation du boss (voir § Porte du boss) | Ciel pâle `#BFD6EE` |

Outils : `bossGate` (porte générique : fond sombre arrondi, montants, linteau, seuil lumineux) et
`moveMarkers(m, porte, sommet)` (repères sur la porte et le sommet du saut du boss) ; l'ancien coin du plateau
reçoit des accessoires du biome (enclume géante et charbon, bénitier géant, cloche dorée).

### Cité Engloutie (Zone 5)

Une cité sous une protection magique au fond de l'océan : on y marche normalement, l'océan se voit tout autour.
Décor : `BUILD[5]` de `tools/studio-zones-assets.luau` ; animations : `src/client/Controllers/DecorVivantController.lua`.

- **Décor** : rue de sable du fond bordée de coraux (zone de bataille), barrière de verre bleuté à liseré lumineux,
  palais de pierre blanche et bleue aux grandes fenêtres, statues de poisson et de pieuvre, fontaine qui coule vers
  le haut, épave encastrée dans un bâtiment, coquillages-maisons, jardin de coraux sous bulle magique, ancres,
  temple-coquille d'où sort le boss (structure du boss), limite légère de pierre et de corail vers l'avant.
- **Derrière la barrière**, sans sortir de la délimitation du plot (barrière en U de rayons 52 × 50, mur d'eau
  profonde sur la bordure, 57 × 55) : bande d'eau avec fond marin, algues, baleine, bancs de poissons, méduses
  lumineuses, silhouette géante et Léviathan (silhouettes fines, sombres), eau éclaircie vers la surface.
- **Animé** (tags) : `PoissonPasse` (baleine, bancs, Léviathan), `MeduseFlotte`, `CorailOndule`, `BulleMonte`
  (fontaine, eau envahie), `GoutteTombe` (fuites), `VagueBarriere` (barrière, bulle, baie), `SequenceOeil`.
- **Progression** : `ArenaService` pose sur l'arène `StageDecor` (stage choisi) ; le client n'affiche un groupe que si
  `StageMin <= StageDecor <= StageMax`. Stage 1 calme ; `Fuites` dès 2, `FuitesPlus` dès 3, `GrossesFissures` et
  jets d'eau dès 4 ; au 5, parties `Envahi` et `SalleDuBoss` (le `Palais` s'arrête au stage 4).
- **Salle du boss (stage 5)** : colonnade circulaire, gigantesque baie vitrée sur l'océan. Toutes les 40 s : une
  silhouette passe, revient plus près, puis un œil géant se colle contre la vitre, regarde, et repart.
- Vitrine : `Plot_Zone5.Arene` porte `StageDecor` (1 à 5) pour prévisualiser chaque stage en Play.

### Porte du boss (structure animée)

Une structure de boss peut s'animer à l'entrée du boss : le décor contient alors un modèle **`PorteBoss`**, que
le client (`src/client/Combat/BossGate.lua`) anime localement juste avant l'entrée d'un ennemi au style
`Heavy` (`CampBoss`), puis referme après son arrivée. Purement visuel, aucune règle.

| Partie de `PorteBoss` | Rôle à l'entrée du boss |
| --- | --- |
| Pièces à attribut `Lueur` (et `LueurAllumee`, Color3) | La forge s'allume : couleur allumée, lumières plus fortes |
| `Marteaux/<Model>` : `Axe` (pivot) et `Bras` (partie mobile) | Les marteaux mécaniques frappent leur enclume |
| `Chaines/<Model>` : `Poulie` en haut | Les chaînes se tendent, les contrepoids remontent |
| `Battants/<Model>` : `Charniere` (pivot), attribut `Sens` (±1) | Les battants s'ouvrent lentement vers l'arène |
| `Effets/Foyer` : émetteurs `Fumee` et `Braises` | Fumée et braises jaillissent de la fournaise |

Les repères du boss (`HautRampe`, `Tente`) sont posés **dans l'embrasure, derrière les battants** : le boss
apparaît porte ouverte et sort de la structure. Durées : `EnemyPresentationConfig.Gate` (ouverture prise sur le
budget d'entrée du boss) ; le budget du boss est allongé en conséquence dans `CombatConfig.Presentation.Entrance`
(`MaitreDesForges` = 4,4 s).

**Zone 4 — Porte-Fournaise** (`furnaceGate` dans l'outil d'assets) : arche de métal riveté sur socles de
basalte, linteau, couronne et sceau forgé, deux battants cerclés de fer avec symboles en losange (métal
refroidi au repos, orange braise une fois allumés), intérieur rougeoyant, tuyaux avec vapeur continue et
vannes, deux chaînes à contrepoids, deux marteaux mécaniques sur enclumes. Construite à l'échelle du boss
(8,5 studs de haut), puis agrandie de 1,35 autour du pied de la porte.

**Zone 4 — fond et flancs** (règle 3) : rempart de basalte de 14 studs à l'entrée à 34 au fond, contreforts à
braseros ; derrière, la citadelle-forge (`forgeCitadel`) : onze tours de 42 à 52 studs, meurtrières rougeoyantes,
créneaux, bannières, trois hautes cheminées fumantes, grand engrenage au-dessus de la porte, creuset suspendu
qui verse du métal en fusion ; deux cascades de lave. Pas de lac ni de bassins ronds : un **courant de lave**
(`lavaRiver` : lit en segments, croûtes sombres, berges de roches, braises) part du pied de chaque cascade, à
l'ouest le long du flanc jusque sous le rempart, à l'est vers l'angle du fond ; les repères `SautMare` sont posés
dessus. Roches : orgues basaltiques adossées au rempart (`basaltColumns`, deux rangs, tons chauds, éboulis au
pied) et roches arrondies (`boulder`, masses gonflées superposées, pas de cubes). Sur le flanc est, une petite
structure haute : le **haut-fourneau** (`blastFurnace`, environ 30 studs) : tour de basalte cerclée de fer en trois
étages, meurtrières, bannière, trou de coulée tourné vers l'arène qui verse dans une rigole, gueulard crénelé,
cheminée qui fume, potence et seau de minerai. Limite avec l'avant du plot (règle 4, `frontBoundary`, z 47) :
muret bas de basalte cerclé de fer, poteaux et chaînes pendantes, petits braseros, roches ; passage central
encadré de deux piliers à brasero et bannière, en face du portique. Flancs : postes de forge
(`forgeStation` : foyer, hotte, enclume, soufflet, baquet), râteliers d'armes, tonneaux et caisses, tas de
minerai, fissures de lave dans le sol. Les Neon utilisent `#D2501E` (un `#F08C3C` en Neon ressort jaune) ; les feux (`Fire`) sont
portés par une pièce droite invisible (`flame`), sinon ils partent de côté sur un cylindre couché.
Variante possible plus tard : le boss assemblé sur place, pièce par pièce, devant la fournaise.

**Zone 6 — Sanctuaire du Ciel** (`skySanctuary`, Style `Sanctuaire`) : plateforme circulaire de marbre cerclée
d'or, flottante sur un dessous de roche en pointe ; colonnade blanche ouverte vers l'arène (chapiteaux et frise
d'or), deux statues ailées, escalier suspendu de marches séparées jusqu'au sol ; grand cristal lévitant dans un
halo d'or et six cristaux en couronne ; cercle de runes au sol. **Invocation du boss** (variante forte, même
module `BossGate`, durée `GardienCeleste` = 4,4 s) : les cristaux, le cercle et le halo s'allument (`Lueur`),
trois anneaux de lumière tournent et montent (`Anneaux`, attributs `Tours`, `Monte`), la colonne de lumière
apparaît (`Apparition` 0,4), le vent et des étincelles jaillissent (émetteurs à `Rafale`), une ombre traverse
l'arène (`Effets/Ombre`, `Course`). Le boss naît dans la colonne, au centre de la plateforme (`HautRampe`),
puis descend l'escalier (`Etape1` en haut, `Etape2` au pied).

**Zone 6 — fond, flancs, limite** : mer de nuages (`cumulus`) qui monte vers le fond, dégagée derrière le
sanctuaire ; derrière, une couronne de nuages bleutés étirés en hauteur (contraste avec le marbre, cache
l'horizon) ; quatre îles flottantes (temple, cristal, arbre doré) et des pierres flottantes. Plus de lac : un
ruisseau de lumière céleste (`skyStream`) tombe en cascade d'une île et longe le flanc ouest ; les repères
`SautMare` (Mouton Nuage) sont posés dessus. Flancs : colonnades en ruine, îles basses, statues ailées le long de
l'allée, cloche et lanternes d'or ; à l'entrée ouest, l'**observatoire céleste** (`skyObservatory`, environ 34 studs) :
tour ronde de marbre sur un nuage, bandes et fenêtres d'or, porte tournée vers l'arène, galerie à colonnettes,
dôme d'or et sphère armillaire (trois anneaux d'or autour d'un orbe lumineux). Limite avant (`skyBoundary`) : balustrade de marbre, poteaux d'or à orbe,
nuages, passage gardé par deux statues ailées.

### Assets Studio

Dans le sandbox « test 3 », exécuter les outils d'assets en mode Edit via MCP ou la barre de
commande, **sans créer de Script ou modifier de Source** :

1. `tools/studio-zones-assets.luau` copie les monstres de chaque zone (30 pour la version B) vers
   `ReplicatedStorage.Assets.Combat` et construit les cinq décors depuis la Zone 1 de Plot_1.
   Si les modèles de base manquent, il copie Slime_Eau, GobLanceT_A et RoiOrc ; il conserve
   les versions de combat existantes. Les copies supplémentaires sont statiques et utilisent
   la mise en scène générique (charge/bascule), pas un nouveau squelette animé.
2. `tools/studio-zone-stage-signs.luau` installe les pancartes Expédition manquantes et replace les
   existantes, sur les huit arènes et les vitrines `PlotsZones` : à l'entrée, devant le portique côté droit
   (PointEtendard + (16,9 ; 50,2), tournée vers l'allée d'arrivée), hors de tout décor de zone. On y choisit
   le stage, ou une autre zone avec les flèches de la fenêtre, avant d'entrer dans l'arène.
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
