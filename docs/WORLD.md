# Monde Alpha (issue #25)

Map commune minimale pour 8 joueurs, construite dans la place Studio « test 3 » à partir du Lobby
existant, à copier dans la DEV commune. Aucune logique de jeu dans les assets.
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
| `Arene` (arène de Zone 1, 9 cases `CaseHeros`, porche « Zone 1 ») | **point d'Expédition / Stage 1**, 127 studs du spawn |
| `Nature`, `Bordure`, `Sol`, `Props`, `PanneauProprietaire` | décor |

Les copies d'arène n'ont pas les attributs de démonstration `IntroDemo` / `IntroDemoBoucle`.
Aucun script dans les plots.

**À faire côté gameplay (#7 / #8 / #10 / #11)** : aujourd'hui `ArenaConfig.ArenaPath` vise la seule
arène de test (`PlotTravail.Arene`), et l'invocation n'est pas encore branchée. Avec ce monde,
l'Expédition se lance depuis **l'arène du plot du joueur** et l'invocation depuis **le portail de
son plot**. Les tags des copies (`CaseHeros`, `AreneCombat`…) sont aujourd'hui ignorés par le code,
qui filtre sur `PlotTravail`.

## Spawn initial

`Lobby.Monde.SpawnLobby` : `SpawnLocation` invisible au centre de la place, neutre. Spawn commun
sûr pendant le chargement des données, avant que PlotService n'envoie le joueur sur son plot.
**Désactivé dans Test 3** (attribut `Note`) pour garder le spawn près des ateliers d'animation ;
à **activer dans la DEV** et désactiver tout autre `SpawnLocation`.

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

## Capacité

8 plots valides : régler la capacité du serveur à 8 (`docs/PLOTS.md`). Le passage à 12 demanderait
4 pétales de plus : la place et la forêt le permettent, le contour de la forêt se recalcule.
