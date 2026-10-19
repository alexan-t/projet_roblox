# Captures des écrans réels du jeu

Référence visuelle de **toutes** les interfaces du jeu, capturées en Studio (Play) sur la place
réelle, par-dessus le monde. Elle remplace la maquette `maquette_v1.jpg`, construite à la main avant
l'existence des écrans et **périmée** : ne plus s'en servir pour juger une interface.

Sert à : juger la cohérence entre écrans, préparer une revue design, comparer avant / après une
modification d'interface. Les règles de style restent celles de `docs/UI_DESIGN_SYSTEM.md` et de
`src/shared/Config/UITheme.lua` : une capture montre l'état actuel, elle ne fait pas loi.

## 1. Rangement

| Dossier | Contenu |
| --- | --- |
| `docs/references/ui/ecrans/` | **Une capture retenue par écran** (tableau § 3), nom exact du tableau. C'est la référence courante : on remplace le fichier quand l'écran change. |
| `automation/screenshots/ui_ecrans/<AAAA-MM-JJ>/` | Toutes les captures d'une séance (variantes fond clair / fond sombre, essais, détails), même préfixe que l'écran : `08_expedition_sombre.png`, `08_expedition_detail_cartes.png`. Le `README.md` de la séance note la version testée et les écarts. |
| `docs/references/ui/maquette_v1.jpg` | Maquette historique, **périmée**. Conservée pour l'historique seulement. |

Format : PNG, fenêtre de jeu seule (sans barres de Studio ni notification Rojo), **1920 × 1080**
(écran de référence de `UIKit.screen` : 1080 px de haut). Pas de recadrage sur un détail dans
`ecrans/` : le détail va dans la séance.

## 2. Procédure de capture

1. Place `test`, Rojo connecté sur la branche à documenter (`develop` à jour pour la référence).
   Fenêtre de jeu en 1920 × 1080 (Studio : *Test* › *Device* › 1920 × 1080, ou fenêtre plein écran).
2. **Play** (pas *Run* : il faut le joueur et son plot). Attendre la fin du chargement des données.
3. Pour chaque ligne du tableau § 3 : provoquer l'état décrit (colonne « Déclencher »), attendre la
   fin des animations d'apparition (≈ 1 s), capturer. Si un modèle ou une texture est gris ou noir,
   attendre et recapturer (chargement).
4. Écrans de démonstration (colonne « Source » = Démo) : seulement si l'écran réel n'est pas
   atteignable ; le noter dans le `README.md` de la séance.
5. Pour les fenêtres et le HUD (§ 11 du design system) : une capture **fond clair** et une
   **fond sombre** dans la séance ; la plus représentative du jeu va dans `ecrans/`.
6. Après la dernière capture faite avec `screen_capture` (MCP) : **réinitialiser la caméra**
   (`docs/MONSTER_PRODUCTION.md`, Outils § A), sinon l'utilisateur perd le clic droit et le clic
   molette. Arrêter le Play.
7. Mettre à jour la colonne « État » du tableau § 3 (`à capturer` → `capturé AAAA-MM-JJ`), puis
   lancer `tools/test-ui-captures.ps1` et `node tests/ui-captures.test.mjs` (inventaire confronté
   au code : contrôleurs, démos et commandes DebugData cités ; tout contrôleur qui dessine une
   interface doit avoir sa ligne). Commit sur une branche `docs/*` → PR vers `develop`.

Commandes de test, côté **Serveur** dans la ligne de commande de Studio (`DebugService`, Studio
uniquement), avec `local p = game.Players:GetPlayers()[1]` :

```lua
local d = game.ServerStorage.DebugData
d:Invoke(p, "AddHero", "tireuse_des_faubourgs")                    -- héros dans la hotbar
d:Invoke(p, "AddCurrency", "SummonTickets", 1)                     -- ticket d'invocation
d:Invoke(p, "AddCurrency", "Gold", 500)                            -- monnaies non nulles
d:Invoke(p, "QuestEvent", "StageCompleted", { Zone = 1, Stage = 1 }) -- quête terminée
d:Invoke(p, "SetKingdomState", 2)                                  -- montée de niveau du royaume
d:Invoke(p, "CompleteStage", false)                                -- défaite (stage en cours)
```

Démonstrations côté client, sans serveur (`UIPreviewController`, `RewardScreenController`,
`CombatIntroController`) : attribut `Workspace.ApercuUI` (`Quete`, `Monnaies`, `Expedition`,
`Invocation`, `Collection`, `Transition`, `Tout`), `Workspace.ApercuEcranRecompenses = true`, attribut
`IntroDemo` (nombre, à changer) sur l'arène taguée `AreneCombat`.

## 3. Inventaire des écrans

Source : **Jeu** = parcours réel du joueur ; **Démo** = seulement visible en démonstration Studio.
État : `à capturer` ou `capturé AAAA-MM-JJ` (le fichier doit alors exister dans `ecrans/`).

| N° | Fichier | Écran | Contrôleur / vue | Source | Déclencher | État |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | `01_hud_plot.png` | HUD au plot : quête en haut à gauche, monnaies en haut au centre, hotbar en bas | `QuestController`, `CurrencyController`, `HeroBarController` | Jeu | Play, au spawn du plot (héros ajouté, monnaies non nulles) | à capturer |
| 02 | `02_quete_terminee.png` | Quête terminée, bouton « Récupérer » | `QuestController` / `QuestView` | Jeu | `QuestEvent` `StageCompleted` (ou gagner le stage 1-1) | à capturer |
| 03 | `03_sacoche.png` | Sacoche ouverte : cartes de héros, badge « Posé », bouton « Placer » | `HeroBarController` | Jeu | 2 héros ou plus (`AddHero`), clic sur le bouton bois à gauche de la hotbar | à capturer |
| 04 | `04_heros_en_main.png` | Raccourci sélectionné, héros au curseur, pastille « … en main · approche-toi d'une dalle : E » | `HeroBarController`, `HeldHeroController`, `ArenaPlacementController` | Jeu | Touche 1 avec un héros dans la hotbar | à capturer |
| 05 | `05_placement_dalles.png` | Dalles de l'arène en surbrillance, prompt « Placer … · Dalle N » | `ArenaPlacementController` | Jeu | Héros en main, s'approcher d'une dalle de l'arène | à capturer |
| 06 | `06_toast_refus.png` | Toast de refus en haut (ex. « Prends un héros (1 à 0), approche-toi d'une dalle : E ») | `ArenaPlacementController` | Jeu | « Lancer » sans héros posé, ou action refusée par le serveur | à capturer |
| 07 | `07_pancarte_stage.png` | Pancarte du stage et prompt « Choisir un stage · Stage Z-S » | `ArenaPlacementController` | Jeu | S'approcher de la pancarte de l'arène | à capturer |
| 08 | `08_expedition.png` | Fenêtre des stages (`ExpeditionView`) : stages, ennemis, Lancer / Préparer l'équipe | `ArenaPlacementController` / `ExpeditionView` | Jeu | E à la pancarte | à capturer |
| 09 | `09_transition_stage.png` | Rideau de transition « Stage Z-S » | `UIKit.curtain` | Jeu | « Lancer » dans la fenêtre des stages (capturer au milieu du rideau) ; sinon Démo `ApercuUI = Transition` | à capturer |
| 10 | `10_combat_intro.png` | Entrée en combat : étendard planté, silhouettes dorées des héros, ennemis qui arrivent | `CombatIntroController` | Jeu | Début du combat ; sinon attribut `IntroDemo` sur l'arène | à capturer |
| 11 | `11_combat_hud.png` | Combat : barres PV / énergie et icône de classe au-dessus des unités, pastille basse « Vague 1/1 », x1 / x2, « X » | `CombatViewController`, `ArenaPlacementController` | Jeu | Pendant le combat, toutes les unités visibles | à capturer |
| 12 | `12_combat_degats.png` | Chiffres de dégâts (coup de base) | `DamageFeedbackController` | Jeu | Pendant le combat, au moment d'un impact | à capturer |
| 13 | `13_combat_ultime.png` | « ULTIME ! », colonne de lumière dorée, chiffre d'ultime doré | `UltimateEffectController`, `DamageFeedbackController` | Jeu | Pendant le combat, énergie d'un héros pleine | à capturer |
| 14 | `14_annonce_vague.png` | Annonce « Vague » ou « Boss : … » (texte contouré, sans fond) | `ArenaPlacementController` | Jeu | Début de vague, ou arrivée du mini-boss | à capturer |
| 15 | `15_victoire.png` | Victoire : titre doré, rayons, badge « Première victoire », cartes de récompense, « Continuer » | `RewardScreenController` | Jeu | Gagner un stage pour la première fois ; sinon Démo `ApercuEcranRecompenses` | à capturer |
| 16 | `16_defaite.png` | Défaite : titre `Error`, sans rayons, « Continuer » | `RewardScreenController` | Jeu | `CompleteStage false` pendant un stage, ou perdre le combat | à capturer |
| 17 | `17_hud_gain_monnaies.png` | Monnaies qui défilent sur le HUD après « Continuer » | `CurrencyController` / `CurrencyView` | Jeu | « Continuer » après une victoire (capturer pendant le défilement) | à capturer |
| 18 | `18_annonce_ticket.png` | Annonce « Nouveau ticket ! Invoque un héros au portail » | `SummonController` | Jeu | Obtenir un ticket (récompense de quête ou `AddCurrency SummonTickets 1`) | à capturer |
| 19 | `19_portail_prompt.png` | Portail du plot et prompt « Invoquer · Portail » | `SummonController`, `PortalAmbientController` | Jeu | S'approcher du portail | à capturer |
| 20 | `20_invocation.png` | Fenêtre « Invocation » : bannière, « Tickets : N », bouton « Taux », « Invoquer » | `SummonController` / `SummonView` | Jeu | E au portail avec au moins 1 ticket | à capturer |
| 21 | `21_invocation_sans_ticket.png` | Fenêtre « Invocation » sans ticket (bouton désactivé) | `SummonController` / `SummonView` | Jeu | E au portail avec 0 ticket | à capturer |
| 22 | `22_invocation_effet.png` | Effet 3D du portail et annonce de rareté (« Commun ! ») | `SummonEffectController` | Jeu | « Invoquer » (capturer pendant l'effet) | à capturer |
| 23 | `23_invocation_revelation.png` | Carte du héros obtenu (badge « Nouveau ») | `SummonView.Reveal` | Jeu | Fin de l'effet d'invocation | à capturer |
| 24 | `24_royaume_niveau.png` | Montée du royaume et « Royaume niveau N ! » | `KingdomChangeController` | Jeu | `SetKingdomState 2` (caméra sur le royaume du plot) | à capturer |
| 25 | `25_panneaux_zones.png` | Panneaux du monde : titres de zone (`AffichageZone`, `EtiquetteZone`), Zone 1 et Zones 2 à 6 | décor (`Workspace.PlotsZones`) | Jeu | Vue large des plots de zone | à capturer |
| 26 | `26_collection.png` | Collection des héros (`CollectionView`, non branchée : la sacoche sert de collection) | `UIPreviewController` / `CollectionView` | Démo | `Workspace.ApercuUI = "Collection"` | à capturer |

Un nouvel écran ou un nouvel état visible = une nouvelle ligne (numéro suivant, jamais réutilisé),
dans la même PR que l'écran.

## 4. Ce que l'équipe fait des captures

- Revue de cohérence : mettre les 26 captures côte à côte (planche) et passer la grille § 11 de
  `docs/UI_DESIGN_SYSTEM.md` ; les écarts deviennent des issues, pas des retouches de capture.
- Quand une PR modifie un écran : recapturer la ligne concernée et remplacer le fichier dans
  `ecrans/` dans la même PR.
