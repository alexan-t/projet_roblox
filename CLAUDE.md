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
- Après des captures avec `screen_capture`, réinitialiser la caméra de Studio (procédure dans `docs/MONSTER_PRODUCTION.md`, § Outils), sinon l'utilisateur perd le clic droit et le clic molette.

## Projet

- Code Luau uniquement dans Git (`src/`), synchronisé par Rojo. Jamais de script écrit dans Studio. Branches `feature/*` → PR vers `develop` (voir `README.md`).
- Modèles et assets : dans Studio, pas dans Git. Toujours placer relativement aux repères existants et enregistrer une étape `ChangeHistoryService` (Ctrl+Z).

## Orchestration des sub-agents

- Le Claude principal est architecte et coordinateur : il lit l'état du dépôt, fixe la portée, délègue, intègre et décide (PR, merge, contrats). Les agents (`.claude/agents/`) exécutent un périmètre précis et rendent un rapport ; ils ne décident ni merge, ni refonte, ni changement de contrat. Spécification : `docs/CLAUDE_AGENTS_ROBLOX.md`.
- Délégation ciblée, pour économiser les tokens : tâche simple ou localisée → le principal seul ; sinon un spécialiste, au plus deux en parallèle sur des sujets indépendants ; jamais toute l'équipe.
- Grosse fonctionnalité qui change l'expérience joueur (loot, inventaire, progression, invocation, récompenses, monétisation, onboarding, navigation) → `roblox-product-benchmark` AVANT l'implémentation : comparables sourcés et datés, alerte VERT / JAUNE / ORANGE / ROUGE, sans web = analyse heuristique annoncée. ROUGE = arbitrage avec l'utilisateur, pas un veto. Le principal lui fournit le texte de l'issue (l'agent n'a pas `gh`) ; aucun verdict sans issue, configs, docs et dépendances lus, ni simplification qui touche un contrat existant sans arbitrage.
- Serveur, remotes ou sauvegardes → ajouter `roblox-data-security` ; fin d'un lot important → `roblox-qa-regression` ; PR à fusionner → `roblox-git-release` (audit), merge exécuté par le principal seulement sur demande.
- Chaque délégation transmet : objectif, branche, fichiers et contrats concernés, contraintes ; le rapport doit citer les fichiers et les tests réellement exécutés.
