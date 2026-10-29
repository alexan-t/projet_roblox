# Republication — lots des héros (préparés, non lancés)

Suite du lot pilote (`REPUBLICATION_LOT_PILOTE.md`, PASS, fusionné dans `develop` au commit
`7ce73b5`). **Aucun upload ni remplacement** sans l'accord explicite de l'utilisateur, lot par lot.
L'expérience n'est jamais publiée par ces outils.

## Périmètre

Les 60 héros de `HeroConfig` sont tous jouables : HeroService clone leurs modèles de
`ServerStorage.Assets.Heros` vers `ReplicatedStorage.Assets.Heros` (portraits de la hotbar, révélation
et vedettes de l'invocation, modèle de combat statique, royaume). Relevé dans Studio le 25/10/2026
(`GetProductInfo`, lecture seule) : l'Écuyer du Rempart est déjà à `nxtoma` (lot pilote) ; les
**59 autres héros comptent 1 042 assets, tous publiés par `cypher1359`** (521 meshes, 521 textures),
sans asset tiers ni asset partagé entre héros. Les copies de `Workspace.Bestiaire.Heros` utilisent les
mêmes identifiants et sont mises à jour par le même remplacement.

## Priorité de gameplay

La rareté sert seulement à découper les sous-lots ; l'ordre suit l'exposition réelle en jeu.

1. **P1 — héros de départ** : Écuyer du Rempart (`SummonConfig.Starter`, invocation tutorielle). **Fait.**
2. **P2 — jeu courant** : ce que les joueurs voient et obtiennent réellement aujourd'hui :
   - les héros les plus obtenus (chance par invocation d'après `RarityConfig` : 25 % pour la Tireuse
     des Faubourgs, 6,25 % pour chaque Peu commun) ;
   - les 9 vedettes des trois bannières, montrées en 3D dans la vue d'invocation à tous les joueurs
     (`SummonBannerConfig`, rotation toutes les 15 min), quelle que soit leur rareté ;
   - puis Rare (2,17 % chacun) et Épique (0,875 % chacun).
3. **P3 — reste du catalogue** : héros à moins de 0,4 % par invocation.

Les pourcentages sont la chance de base par invocation (poids de la rareté ÷ nombre de héros de cette
rareté) ; la mise en avant d'une bannière l'augmente pour ses vedettes.

| Lot | Priorité | Contenu | Héros | Assets | Héros (chance de base par invocation) |
|---|---|---|---|---|---|
| `lot-heros-01` | P2 jeu courant | Héros les plus obtenus (Commun + Peu commun) | 5 | 86 | Tireuse des Faubourgs (25,00 %), Lancier des Champs (6,25 %), Apprenti Pyromancien (6,25 %), Brise-Pierre (6,25 %), Guetteuse des Pins (6,25 %) |
| `lot-heros-02` | P2 jeu courant | Vedettes des trois bannières | 9 | 168 | Prêtresse aux Lucioles, Chevalier du Soleil Creux, Dame aux Mille Bannières, Chevalier de l'Éclipse Blanche, Roi des Corbeaux sans Ombre, Lame du Serment Brisé, Séraphin des Sept Sceaux, Soleil Dévoré, Auréon, Porteur de la Première Aube |
| `lot-heros-03` | P2 jeu courant | Rare | 6 | 96 | Chevalier du Lierre, Mage des Lanternes, Fauconnier Gris, Lancière des Sources, Barde de Fer, Moine du Vent Bas (2,17 % chacun) |
| `lot-heros-04` | P2 jeu courant | Épique (hors vedette) | 7 | 128 | Gardien des Ronces, Cartomancienne d'Ambre, Duelliste du Croissant, Forgeron Runique, Briseur de Cloche, Veneur de Givre, Alchimiste aux Masques (0,875 % chacun) |
| `lot-heros-05` | P3 reste | Légendaire (hors vedettes) | 8 | 130 | Lancier des Sept Orages, Architecte de Golems, Veuve du Lac Miroir, Chasseur de Comètes, Saint du Brasier Bleu, Gardienne de la Dernière Cloche, Prince des Racines d'Or, Archiviste du Temps Mort |
| `lot-heros-06` | P3 reste | Mythique (hors vedette) | 9 | 166 | Navigateur des Cieux Renversés, Reine des Cent Lames, Berger des Astres, Géant au Cœur de Verre, Sorcière des Marées Lunaires, Maître des Portes Oubliées, Gardienne du Dragon Dormant, Tisseur de Destins, Empereur des Cendres d'Or |
| `lot-heros-07` | P3 reste | Maudit (hors vedettes) | 6 | 108 | Porteur du Cœur Noir, Chevalier aux Mille Clous, Nonne de la Lune Fendue, Marionnettiste des Tombes, Sorcier de la Couronne Parasite, Chasseur de Noms |
| `lot-heros-08` | P3 reste | Suprême + Calamité + Transcendant (hors vedettes) | 9 | 160 | Reine du Firmament Doré, Chevalier de l'Aube Infinie, Oracle aux Cent Yeux, Forgeâme, Gardien du Trône Vide, Marcheur du Cataclysme, Reine de la Mer Renversée, Titanide des Derniers Jours, Elyria, qui Marche hors du Temps |
| **Total** | | | **59** | **1 042** | |

Fichiers : `automation/republication/lot-heros-0N.json` (ancien AssetId, type, HeroId, priorité).

## Prochain lot proposé : `lot-heros-01` (en attente d'accord)

| Héros | Rareté | Meshes | Textures |
|---|---|---|---|
| Tireuse des Faubourgs | Commun | 9 | 9 |
| Lancier des Champs | Peu commun | 8 | 8 |
| Apprenti Pyromancien | Peu commun | 9 | 9 |
| Brise-Pierre | Peu commun | 8 | 8 |
| Guetteuse des Pins | Peu commun | 9 | 9 |
| **Total** | | **43** | **43** |

Lecture seule faite le 25/10/2026 (`download`, aucun upload) : **86/86 téléchargés**, 43 meshes
`version 2.00`, 43 PNG 1024 × 1024, 49,8 Mo, aucun fichier au-delà de 1,4 Mo. `plan` : **0 asset
réutilisable** (aucun ancien id ni contenu déjà publié sous `nxtoma`), **86 à publier**.

## Réutilisation des assets déjà publiés

Registre `automation/republication/published-registry.json` (62 assets du lot pilote) : avant chaque
upload, `publish` cherche l'ancien AssetId, puis le contenu (SHA-256 et type). S'il existe déjà sous
le propriétaire, l'identifiant publié est réutilisé, sans upload. Chaque publication réussie l'enrichit.
`plan` montre, sans réseau, ce qui sera réutilisé ou publié.

## Procédure d'un lot (chaque étape attend l'accord de l'utilisateur)

**Préalables :**
- **Store de recette actif dans la place DEV.** Le code `StoreRecette` est dans `develop`, mais la
  place DEV n'est **pas encore synchronisée** : `DataService` y est l'ancienne version, sans
  `StoreName` (constaté le 25/10/2026). Synchroniser `develop` dans la DEV (Rojo), puis vérifier la
  ligne de console du store avant toute recette. Sans cela, pas de recette en Play.
- Sauvegarde de la place : télécharger la dernière version enregistrée (Asset Delivery, comme
  v205-v207 dans `C:\Users\Thoma\RobloxBackups\projet-roblox-alpha\`).

**Étapes :**
1. `download` (lecture) puis `plan` : formats, accès, réutilisation.
2. `publish --confirm --limit <taille>`, `refresh` jusqu'à 100 % `Approved`, `register`, `mapping`.
3. Contrôle de propriété et comparaison, dans Studio, en lecture seule : propriétaire `nxtoma` et
   contenu identique pour chaque paire (pixels ; sommets, faces, positions et UV).
4. Remplacement : `tools/studio-replace-asset-ids.luau`, `DRY_RUN` d'abord, puis une étape Ctrl+Z.
5. Recette en Play avec `StoreRecette` (`SECURITY.md` § Recettes Studio) : hotbar, invocation,
   arène, combat, royaume ; console sans « not authorized » ni « not approved » ; captures ;
   caméra réinitialisée ; attribut retiré à la fin.
6. Mapping, retour arrière et inventaire commités ; verdict PASS ou FIX.

**Retour arrière, du plus rapide au plus complet :**
1. Ctrl+Z dans la session Studio qui a fait le remplacement (une seule étape).
2. `rollback.luau` (produit par `mapping`, nouveau → ancien) collé dans le script de remplacement :
   remet les anciens identifiants partout, même après fermeture de Studio. Les anciens assets de
   `cypher1359` restent en ligne et rien n'est supprimé.
3. Restaurer la version de place sauvegardée avant le lot (historique des versions du Creator Hub).
