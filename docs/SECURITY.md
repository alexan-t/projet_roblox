# Sécurité — Save/Load, remotes et récompenses (issue #12)

Le serveur fait autorité : le client n'envoie que des intentions (Ids, numéros de case, verbe) et
lit des vues en lecture seule. Aucune valeur de gameplay (récompense, héros, rareté, ticket, résultat
de combat, progression de quête) n'est décidée ni envoyée par le client.

## Garanties

| Menace | Protection | Test (`./tools/test-security.ps1`) |
| --- | --- | --- |
| Réclamer une récompense de stage (spam, écran rouvert, client falsifié) | **Aucune remote de récompense de stage**. RewardService est appelé par ZoneService à la victoire ; tout est sauvegardé avant l'écran de fin, qui est purement visuel. | `#12 no client reward remote` |
| Réclamer une récompense de quête (« Récupérer ») | `ClaimQuest` **peut attribuer** `QuestConfig.Rewards` (Or, Gemmes, Ticket). Le client n'envoie que le `QuestId` (tout autre argument, montant compris, est ignoré). Le serveur vérifie : données chargées, quête connue, quête **active** de la chaîne, commencée, **terminée**, **pas déjà réclamée** ; puis, dans une section synchrone sans yield : `Claimed = true`, récompenses définies côté serveur ajoutées une seule fois, quête suivante activée. Spam, double clic, quête future, quête falsifiée : refusés. | `#12 Zone 1 quest claims`, `#12 ClaimQuest spam`, `#12 no client reward remote` |
| Invocation tutorielle (`RequestStarterSummon`) | Aucun argument lu. Données chargées, plot, SON portail, distance, quête `SummonStarter` active, Écuyer jamais obtenu ; transaction synchrone (exemplaire créé, ni ticket, ni `Summons.Total`, ni royaume). Impossible deux fois. | tests HeroService « tutorial summon » |
| Même victoire traitée deux fois | 3 barrières : CombatService verrouille la session avant `CompleteStage` ; ZoneService supprime la session avant QuestService/RewardService (une session ne se termine qu'une fois) ; RewardService refuse un `completionId` (Id de session de stage) déjà récompensé. Une même victoire ne donne jamais FirstClear + Repeat. | `#12 duplicate victory, 3 layers` |
| Spam de lancement de stage | Au plus une session de stage par joueur (`session déjà en cours`) ; un combat par session (`combat déjà en cours`) ; anti-spam ArenaAction 0,12 s ; Ready / SelectStage idempotents. | `#12 stage spam`, `#12 one combat per stage session`, `#12 Ready spam`, `#12 SelectStage spam` |
| Double invocation | Transaction synchrone sans yield + verrou `summoning[player]` + ticket revérifié dans la transaction. | `#12 double summon`, `#12 summon lock`, `#12 defence in depth` |
| Ticket consommé sans héros | L'identifiant d'exemplaire est créé **avant** toute mutation ; héros ajouté puis ticket débité (aucune étape ne peut échouer entre les deux). | `#12 summon never consumes a ticket without a hero` |
| Départ pendant un combat | `PlayerRemoving` arrête le combat et détruit ses modèles ; la session de stage disparaît ; rien n'est attribué. Rejoin : le stage se relance normalement. | `#12 combat disconnect` |
| Départ après la victoire, avant l'écran | Récompenses, First Clear et quête sont déjà dans PlayerData avant `CombatEnded` : le rejoin les retrouve une fois. | `#12 victory then disconnect` |
| Départ pendant une invocation | Soit la transaction est faite (ticket 0 + héros), soit refusée avant mutation (rien) ; jamais à moitié. | `#12 summon then disconnect` |
| Profil perdu / `DataLoaded` absent | Chaque action sensible revérifie joueur présent + `DataLoaded` + données (stage, combat à chaque tick, récompense, invocation, hotbar, quête, monnaies). | `#12 DataLoaded lost`, tests PlotService (plot jamais tardif) |
| Vitesse de combat | `SetCombatSpeed` n'accepte que `1` ou `2` ; sinon `vitesse invalide`, rien ne change. | `#12 CombatSpeed` |
| Actions sur le plot / portail / arène / héros d'un autre | Le serveur résout toujours le plot du joueur (`PlotService:GetPlot`), son portail (distance serveur) et ses propres exemplaires (`data.Heroes`). | `#12 cross-player` (héros, arène) |
| Entrées absurdes | Types, NaN, ±inf, tables, Instances, chaînes : refus propre, aucune erreur, aucune mutation. | `#12 HotbarAction fuzz`, `#12 invalid slots / ids`, `#12 stage spam` |
| Monnaies | `GetCurrencies` renvoie une copie ; aucune remote ne modifie une monnaie. | `#12 read-only` |
| Loot et inventaire (#72) : créer un item, choisir ItemId / ResourceId / quantité / rareté, forcer un drop de boss, rejouer une completion | **Aucune remote d'écriture** : seules `GetInventory` (vue en lecture seule, arguments ignorés) et `InventoryChanged` existent. Le tirage (RNG, rareté, quantité, ItemId) est fait par RewardService dans la section synchrone de la victoire, avec la même identité de completion que le First Clear ; `LootConfig` est validée à l'Init (invalide = aucun loot) ; une erreur de loot ne bloque jamais le First Clear. Point ouvert : pas de sauvegarde forcée après un loot (`SaveNow`). | `#12 exactly two remotes, both read-only`, `#12 GetInventory ignores every client argument`, `#12 #72 no client input`, tests `#72` de `RewardService.spec` / `RewardFlow.spec` |

## Save / Load (ProfileStore)

`DataService` : `StartSessionAsync` (verrou de session : un seul serveur propriétaire d'un profil),
migration, `Reconcile`, `DataLoaded`, `EndSession` au départ, sauvegarde à la fermeture par le
`BindToClose` de ProfileStore. Le vendor n'est pas modifié. Si la session est reprise ailleurs,
`OnSessionEnd` retire les données et expulse le joueur : jamais deux propriétaires.

Ce qui n'est pas automatisable avec le harnais local : le comportement réel du DataStore en
production (latence, échecs d'écriture, fermeture brutale d'un serveur en ligne).

Validé dans Studio (DataStore Studio réel, 2 joueurs) :
- **Sauvegarde au départ** : un joueur expulsé juste après une invocation retrouve son ticket à 0 et
  son héros ; un joueur expulsé à l'instant de la victoire, avant l'écran de fin, retrouve son First
  Clear, ses monnaies, son ticket et sa quête.
- **Sauvegarde à l'arrêt du serveur** : une mutation faite pendant la session est relue dans le
  profil après l'arrêt (`BindToClose` de ProfileStore).
- **Verrou de session** :
  - sur un même serveur, ProfileStore refuse d'ouvrir deux fois le même profil ;
  - entre deux serveurs (la fenêtre d'édition de Studio tenant le profil), le serveur de jeu n'a
    chargé le joueur qu'après que l'autre session a reçu `OnSessionEnd` (environ 29 s) ;
  - il n'y a jamais deux propriétaires en même temps.

## Recettes Studio : store séparé obligatoire

**Problème constaté.** Le store de Studio (`PlayerData_Studio`) est aussi le profil de travail de
l'utilisateur. Les recettes qui jouent de vrais combats l'ont modifié durablement :
- 20/10/2026 (recette de la PR #96) : Élite 1-1 à 1-5 terminés, héros montés de niveau, tickets,
  un équipement Légendaire et des ressources ajoutés ;
- 24/10/2026 (contrôle du lot pilote de republication, PR #108) : deux combats 1-5, +200 XP à
  l'Écuyer du Rempart (niveau 11) et récompenses de stage.
Une recette suivante avait contourné le problème en modifiant à la main, sans commit, le nom du
store dans `DataService` (`PlayerData_Recette96`, profil de test encore présent) : procédure fragile.

**Règle.** Toute recette Studio qui joue (combat, invocation, récompense, quête, inventaire) utilise un
store de recette, jamais `PlayerData_Studio` :
1. En Edit, sur **ServerStorage**, ajouter l'attribut texte `StoreRecette` = nom court de la
   recette (lettres, chiffres, `_`, `-`, 32 caractères au plus ; ex. `Lot108`).
2. Lancer le Play : la console doit afficher `[DataService] Store "PlayerData_Recette_Lot108" prêt`.
   Sinon, arrêter avant toute action.
3. À la fin, **supprimer l'attribut** (le profil de travail reprend) et noter le store utilisé
   dans le rapport de recette.

Règle de nom : `src/server/Data/StoreName.lua` (tests `tools/test-storename.ps1`). L'attribut est
ignoré hors de Studio : le jeu publié utilise toujours `PlayerData`. Un nom invalide donne le store
générique `PlayerData_Recette`, jamais le profil de travail. Pas d'outil ni de code de recette qui
modifie `DataService` à la main.

## Limite connue

`RequestStartStage` (ancienne entrée directe de ZoneService) reste exposée : un client malveillant
peut ouvrir une session de stage sans arène et bloquer **sa propre** préparation jusqu'au rejoin.
Aucun effet sur les autres joueurs ni sur les récompenses (une session sans combat ne se termine
jamais en victoire).
