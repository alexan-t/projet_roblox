# Recette #120 : progression après la Zone 1

Issue : #120 (EPIC #67, audit `docs/ALPHA_002_PLAYTEST.md`). Branche `feature/progression-apres-zone1`.
Recette Studio du 29-30/10/2026, place « Projet Roblox - Alpha », Rojo synchronisé depuis la branche.

**Verdict : GO.** Les trois parcours passent avec un vrai profil neuf. Deux limites restent, déjà suivies ailleurs :
- tailles de texte sur téléphone (#119) ;
- rappels « ! » de découverte (antérieurs).

Captures (A1 à R2) : [`docs/playtest/progression-120/`](playtest/progression-120/).

## Conditions

- **Store de recette isolé** :
  - `ServerStorage.StoreRecette = "P120_A"` → `PlayerData_Recette_P120_A` ;
  - profil neuf (session n°1 dans les logs) ;
  - attribut retiré à la fin ; `PlayerData_Studio` et la production non touchés.
- **Partie réelle**, sans `DebugData` :
  - invocation de départ, puis invocations avec les tickets gagnés ;
  - combats lancés par les remotes de l'interface (`ArenaAction`) et par le bouton « Lancer » ;
  - réclamations par le panneau Quêtes ou par `ClaimQuest`, revalidées côté serveur.
- **Restauration** : caméra réinitialisée, `HttpEnabled` resté à `false`, aucun asset publié.

## Parcours A : nouveau joueur → 1-5 → Élite

| Étape | Observé | Résultat |
| --- | --- | --- |
| Profil neuf | quête `SummonStarter`, objectif `Normal 1-1` | PASS |
| 1-1 → 1-3 | sélection 1-2, puis 1-3, puis 1-4 ; quêtes Défense récupérées | PASS |
| 1-4 perdu (Écuyer seul), 2ᵉ héros par ticket, 1-4 gagné | sélection 1-5 | PASS |
| Expédition 1-5 (A1) | « Équipement · 1re victoire » Garanti (Commun 20 % · Peu commun 50 % · Rare 30 %), « Équipement aléatoire » 12 % (Commun 3,6 % · Peu commun 6 % · Rare 2,4 %) = `LootConfig` | PASS |
| Roi Orc battu (bouton Lancer) | équipement garanti reçu ; sélection **1-1E** (plus 2-1) ; objectif `EliteNew` | PASS |
| Après « Continuer » (A2) | « Mode Élite débloqué ! », puis « Ennemis plus forts, meilleur équipement : lance 1-1 en Élite » | PASS |
| Panneau Quêtes (A3) | carte « Zone 1 Élite · Palier 1/5 » | PASS |
| Roi Orc récupéré (A4) | HUD « Gagne 1-1 en Élite », balise sur la pancarte | PASS |
| Expédition (A5) | ouverte sur l'onglet **Élite**, 1-1E sélectionné, « Ennemis plus coriaces, meilleur équipement », équipement 22 % (Rare 19,8 % · Épique 2,2 %) | PASS |
| 1-1E gagné (A6) | quête 1/1 « Récupérer », sélection 1-2E | PASS |

## Parcours B : progression Élite

| Étape | Observé | Résultat |
| --- | --- | --- |
| Réclamations | 1-1E : +200 or / +20 gemmes ; 2ᵉ clic « déjà réclamée » ; quête future « quête non commencée » | PASS |
| 1-2E, 1-3E gagnés | quête suivante, +250/25, +300/30, sélection suivante | PASS |
| 1-4E perdu puis gagné | sélection conservée après la défaite ; +350/35 | PASS |
| Reconnexion en milieu de chaîne (B1) | HUD « Roi Orc en Élite 0/1 », flèches au sol vers la pancarte, 1-5E présélectionné, monnaies conservées | PASS |
| Replays 1-5 Normal (tickets) | après chaque victoire, sélection **revenue à 1-5E** (objectif) | PASS |
| Invocation ×10, Roi Orc Élite battu | objectif `Farm 1-5E`, sélection reste 1-5E | PASS |
| Après « Continuer » (B2) | « Zone 1 maîtrisée ! Améliore ton équipe en Élite en attendant les prochaines zones » | PASS |
| Dernière quête | +500 or, +50 gemmes, +2 tickets, une seule fois ; quête principale = collection de héros | PASS |

## Parcours C : toute l'Élite terminée, reconnexion

| Étape | Observé | Résultat |
| --- | --- | --- |
| Reconnexion | aucune annonce rejouée ; sélection 1-5E ; journal : Défense ✓, Élite ✓, Héros en cours | PASS |
| Expédition (C1) | 1-5E « Boss · Terminé », sous-titre « Zone 1 maîtrisée ! Améliore ton équipe en attendant les prochaines zones », équipement 45 % (Rare 20,3 % · Épique 18,9 % · Légendaire 5,9 %) ; aucune Zone 2 proposée | PASS |

## Interfaces

| Appareil | Observé | Résultat |
| --- | --- | --- |
| PC 1651 × 633 | captures A1 à C1 ; annonces lisibles, sans chevauchement de l'annonce de quête | PASS |
| Tablette paysage (1179 × 819) | « Équipement » tronqué (« Équipement… ») → corrigé : libellés courts hors PC (R2, 76 px de texte pour 192 px) | PASS après correctif |
| Téléphone 844 × 390 (viewport 750 × 381) | lignes d'équipement, chance et raretés visibles (R1) ; 12,4 px réels, comme les lignes de butin existantes | FIX hors périmètre, suivi par #119 |

Annonces de palier : `Title` et `Heading`, soit au moins 22,4 et 16,8 px réels à l'échelle minimale (0,7).

## Tests automatiques

- **Runners Luau** (`tools/test-*.ps1`, exécutés dans Studio Edit) :
  - QuestService **49/0**, ArenaRules **18/0**, ArenaPrep 25/0, PlacementState 14/0 ;
  - Expedition **20/0**, ZoneService 34/0, LootRules 19/0 ;
  - RewardService 31/0, RewardFlow 22/0, Tutorial 25/0, QuestLog 7/0 ;
  - Migrations 26/0, PlayerStateService 7/0, Sacoche 12/0, SacocheInventory 53/0, CombatPresentation 19/0.
- **Node** : `node --test tests/` **38/0**.
- **Build** : `rojo build` OK, `git diff --check` propre.
- **Nouveaux cas couverts** :
  - chaîne Élite et ordre de déblocage ;
  - victoire Normal sans effet sur l'Élite, et inversement ;
  - doubles récompenses et quêtes futures refusées ;
  - anciens profils (Élite partielle et complète) sans rejouer ;
  - victoire Élite avant la réclamation du Roi Orc ;
  - reconnexions, deux joueurs ;
  - objectif (profil neuf → farm, Zone 2 sans butin jamais proposée, Zone 2 proposée dès qu'elle aura du butin) et sélection après victoire ;
  - aperçu de l'équipement recalculé depuis `LootConfig` ;
  - annonces jamais au join ; libellés courts.

## Limites

- **Téléphone** : texte du butin à 12,4 px réels (comme avant #120) → #119.
- **Rappels « ! » du menu** (Index, Stats, Quêtes, Sac) : allumés en même temps dans ce parcours scripté, qui n'a jamais ouvert ces menus. C'est un comportement antérieur à #120. Rien d'ajouté ici : aucune nouvelle flèche ni nouveau « ! ».
- **Sur tablette**, les touches clavier envoyées par MCP n'atteignent pas le jeu : l'utilisateur a ouvert l'Expédition au toucher. Pas d'appareil réel.
- **Équilibrage** :
  - les récompenses des quêtes Élite sont PROVISOIRES (#112) ;
  - le Roi Orc Élite a résisté à 2 héros niveau 5 et a été battu avec 4 héros après une invocation ×10 (sans équiper l'arc reçu) ;
  - 1-4E : 5 défaites de suite à 2 héros.
  - Ces constats sont à lire avec les simulations de #112.
