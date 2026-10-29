# CLAUDE.md

Règles permanentes pour tous les agents. Le détail est dans `docs/`.

## Direction artistique

- La seule source de vérité artistique est l'ensemble des **monstres et boss validés** listés dans `docs/ART_DIRECTION.md` § 1, plus leurs moodboards dans `docs/references/moodboards/`.
- **Références principales** (elles définissent la DA) : **King Tréant, Tréant, Slime King, King Orc**. Les gobelins #12 et #15, les slimes et `Treant_Arbre` sont **secondaires**. En cas d'hésitation, suivre la logique des quatre principales, sans les copier.
- Les **personnages existants** (ex. `Heros_Base` du Bestiaire, mannequins R15, modèles en blocs de couleur unie) **ne sont pas une référence artistique**. Ne pas s'en inspirer.
- Les futurs personnages jouables suivent **exactement** la même DA que les monstres et boss (`docs/CHARACTER_ART_DIRECTION.md`).
- Les monstres n'ont **aucune rareté**. N'en inventer aucune.
- **Interfaces** (HUD, fenêtres, panneaux du monde) : suivre `docs/UI_DESIGN_SYSTEM.md`. Les valeurs de style viennent uniquement de `src/shared/Config/UITheme.lua`.

## Avant de créer

1. Lire le brief, `docs/ART_DIRECTION.md`, puis le workflow : `docs/MONSTER_PRODUCTION.md` (monstre/boss) ou `docs/CHARACTER_ART_DIRECTION.md` (personnage).
2. Inspecter réellement dans Roblox Studio (MCP) les créations validées les plus proches du brief. Ne pas supposer ce que Studio peut dire.

## Animations

- Animer un héros ou un monstre : `docs/ANIMATION_TOOLS.md` (`tools/animation/AnimationKit.luau`). Toujours travailler sur une copie dans `Workspace.AtelierAnimation`, jamais sur le modèle du Bestiaire.

## Avant de déclarer terminé

- Capture d'écran réelle, puis contrôle avec `docs/VISUAL_QA.md`. Seuls résultats possibles : **PASS** ou **FIX**. Pas de PASS sans capture.
- Propriété des assets contrôlée (`docs/ASSET_OWNERSHIP.md`) : un asset hors propriétaire de l'expérience donne **FIX**, même si le rendu est bon.
- Recette Studio qui joue (combat, invocation, récompense…) : store de recette séparé, attribut `StoreRecette` sur ServerStorage, jamais le profil de travail `PlayerData_Studio` (`docs/SECURITY.md` § Recettes Studio).
- Après des captures avec `screen_capture`, réinitialiser la caméra de Studio (procédure dans `docs/MONSTER_PRODUCTION.md`, § Outils), sinon l'utilisateur perd le clic droit et le clic molette.

## Propriété des assets (obligatoire)

Détail et procédure : `docs/ASSET_OWNERSHIP.md`.

1. Tout asset définitif (image, icône, texture, mesh, `SurfaceAppearance`, animation, son, modèle) appartient au propriétaire de l'expérience : compte `nxtoma`, ou le groupe propriétaire si l'expérience passe dans un groupe (lire `game.CreatorType` / `game.CreatorId`).
2. Un asset publié sous le compte personnel d'un collaborateur n'est pas intégré au jeu, même s'il s'affiche dans sa session.
3. Le collaborateur crée et teste sous son compte ; avant la validation finale, l'asset est publié sous le bon propriétaire. Attention : `generate_mesh`, `generate_texture`, `upload_image`… publient sous le compte de la session Studio.
4. Sans droit de publier sous le propriétaire, préparer les fichiers sources et les instructions pour que l'utilisateur publie depuis sa propre session. Ne jamais demander d'identifiants.
5. Après republication, remplacer les anciens AssetIds partout : configs, catalogues, modèles, textures, meshes, animations, sons, icônes, références Studio.
6. Republier un modèle ne change pas le propriétaire de ses meshes et textures : contrôler chaque dépendance interne.
7. Tester le chargement dans l'expérience propriétaire réelle (place DEV), pas seulement dans la session du collaborateur.
8. Vérifier les permissions Roblox et le statut de modération.
9. Tenir l'inventaire : nom, type, ancien AssetId, nouvel AssetId, propriétaire, résultat du contrôle.
10. Propriété ou permissions incorrectes → blocage signalé (FIX) avant le merge. Contrôle : `tools/studio-check-asset-ownership.luau`.

Sans accord explicite de l'utilisateur : pas de republication en masse, pas de changement de permissions, pas de remplacement d'AssetIds avant confirmation du propriétaire et des accès, pas de publication en production.

## Projet

- Code Luau uniquement dans Git (`src/`), synchronisé par Rojo. Jamais de script écrit dans Studio. Branches `feature/*` → PR vers `develop` (voir `README.md`).
- Modèles et assets : dans Studio, pas dans Git. Toujours placer relativement aux repères existants et enregistrer une étape `ChangeHistoryService` (Ctrl+Z).

## Orchestration des sub-agents

- Le Claude principal est architecte et coordinateur : il lit l'état du dépôt, fixe la portée, délègue, intègre et décide (PR, merge, contrats). Les agents (`.claude/agents/`) exécutent un périmètre précis et rendent un rapport ; ils ne décident ni merge, ni refonte, ni changement de contrat. Spécification : `docs/CLAUDE_AGENTS_ROBLOX.md`.
- Délégation ciblée, pour économiser les tokens : tâche simple ou localisée → le principal seul ; sinon un spécialiste, au plus deux en parallèle sur des sujets indépendants ; jamais toute l'équipe.
- Grosse fonctionnalité qui change l'expérience joueur (loot, inventaire, progression, invocation, récompenses, monétisation, onboarding, navigation) → `roblox-product-benchmark` AVANT l'implémentation : comparables sourcés et datés, alerte VERT / JAUNE / ORANGE / ROUGE, sans web = analyse heuristique annoncée. ROUGE = arbitrage avec l'utilisateur, pas un veto. Le principal lui fournit le texte de l'issue (l'agent n'a pas `gh`) ; aucun verdict sans issue, configs, docs et dépendances lus, ni simplification qui touche un contrat existant sans arbitrage.
- Serveur, remotes ou sauvegardes → ajouter `roblox-data-security` ; fin d'un lot important → `roblox-qa-regression` ; PR à fusionner → `roblox-git-release` (audit), merge exécuté par le principal seulement sur demande.
- Chaque délégation transmet : objectif, branche, fichiers et contrats concernés, contraintes ; le rapport doit citer les fichiers et les tests réellement exécutés.
