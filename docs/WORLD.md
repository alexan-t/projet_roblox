# Monde Alpha (issue #25)

Map commune minimale pour 8 joueurs, construite dans la place Studio « test 3 » à partir du Lobby
existant, puis **intégrée dans la DEV commune** (« Projet Roblox - Alpha ») et validée à deux
joueurs (voir « Validation dans la DEV »). Aucune logique de jeu dans les assets.
Contrat des plots : `docs/PLOTS.md` ; royaume et héros : `docs/KINGDOM.md`.

## Plan

```text
                 Tour des Titans (réservée, hors scope Alpha)
                          |
        Plot_8   Plot_1   |   (8 plots en pétales, 142 studs du centre)
     Plot_7     ( Place centrale, Ø 216 )     Plot_2
        Plot_6   Plot_3 ...
   ~~~~~~~~~~~ forêt de bordure + limites invisibles ~~~~~~~~~~~
```

- **Place centrale** (`Lobby.PlaceCentrale`, centre (331, 1.5, 412), Ø 216 studs) : point de
  rencontre, laissé **libre** pour les futurs systèmes sociaux (rien à y construire pour l'Alpha).
- **8 plots** (`Lobby.Plots.Plot_1..8`) reliés à la place par des allées, tous au même plan que
  `PlotTravail` (mêmes positions relatives au repère du royaume).
- **Route et tour des Titans** (`Lobby.RouteTitans`) : réservées, hors scope Alpha.

## Chaque plot (copié depuis PlotTravail, aux mêmes positions relatives au royaume)

| Élément | Rôle dans la boucle |
| --- | --- |
| `PointApparition` | arrivée du joueur (PlotService) |
| `Royaume.EmplacementCentral` | royaume posé par KingdomService (aucun royaume dans le décor) |
| `PortailInvocation` | invocation (Roll), 62 studs du spawn |
| `Arene` (arène de Zone 1, 9 cases `CaseHeros`, `FrontEnnemi`, porche « Zone 1 ») | **point d'Expédition / Stage 1**, 127 studs du spawn |
| `Nature`, `Bordure`, `Sol`, `Props`, `PanneauProprietaire` | décor |

Les copies d'arène n'ont pas les attributs de démonstration `IntroDemo` / `IntroDemoBoucle`.
Aucun script dans les plots.

**Gameplay** : l'Expédition se lance depuis **l'arène du plot du joueur** (`ArenaConfig.ArenaName`,
arène personnelle de #8, voir `docs/ARENA_PROTOTYPE.md`) ; les arènes des plots sont celles du
partenaire, revalidées avec ce flow. `Workspace.PlotTravail` reste une référence / sandbox, jamais
l'arène de jeu. L'invocation n'est pas encore branchée : #10 utilisera **le `PortailInvocation` du
plot du joueur**, pas un portail global.

## Spawn initial

`Lobby.Monde.SpawnLobby` : `SpawnLocation` invisible au centre de la place, neutre. Spawn commun
sûr pendant le chargement des données, avant que PlotService n'envoie le joueur sur son plot.
**Actif dans la DEV** ; l'ancien `Workspace.SpawnLocation` de test y est désactivé (gardé, pas
supprimé), et aucun autre `SpawnLocation` n'est actif. Dans Test 3, il reste désactivé (attribut
`Note`) pour garder le spawn près des ateliers d'animation. Les `PointApparition` des plots restent
des `BasePart` de repère (convention de PlotService), pas des `SpawnLocation`.

## Environnement et limites

- `Lobby.Monde.ForetBordure` : 900 arbres (copies agrandies des `Arbre` / `Sapin` de PlotTravail),
  en lisière qui épouse le contour du Lobby (de plus en plus grands vers l'extérieur). À hauteur de
  joueur, l'horizon est fermé par la forêt et les falaises des plots.
- `Lobby.Monde.Limites` : 90 murs invisibles (`LimiteMap`, hauteur 80) derrière la forêt, le plus
  proche à 330 studs du centre. `CanQuery = false` : la caméra ne bute pas dessus.

## Distances (marche à 16 studs/s)

| Trajet | Distance | Temps |
| --- | --- | --- |
| Place → spawn du plot | 142 studs | 9 s |
| Spawn du plot → portail d'invocation | 62 studs | 4 s |
| Spawn du plot → arène (Expédition) | 127 studs | 8 s |

Identiques pour les 8 plots. Toute la boucle Join → Plot → Royaume → Expédition → Stage 1 →
retour au plot se fait sans quitter son plot.

## Validation dans la DEV

Test Studio « Serveur et clients », 2 joueurs, après intégration :

- plots distincts (`Plot_1`, `Plot_2`), arrivée sur leur `PointApparition` ;
- respawn (reset du personnage) sur le bon plot ;
- royaumes indépendants (changer l'état de l'un ne touche pas l'autre) ;
- ownership de l'arène : un joueur ne peut ni placer ni lancer depuis l'arène d'un autre ;
- placements sur les 9 cases, bouton Prêt ;
- deux combats simultanés, chacun dans l'arène et le `Runtime` de son plot.

Les anciens éléments remplacés (royaumes posés, arènes DEV d'avant l'intégration) sont archivés
dans `ServerStorage.Archive_Plots`, pas supprimés.

## Capacité

8 plots valides : régler la capacité du serveur à 8 (`docs/PLOTS.md`). Le passage à 12 demanderait
4 pétales de plus : la place et la forêt le permettent, le contour de la forêt se recalcule.
