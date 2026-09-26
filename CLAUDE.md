# CLAUDE.md

Règles permanentes pour tous les agents. Le détail est dans `docs/`.

## Direction artistique

- La seule source de vérité artistique est l'ensemble des **monstres et boss validés** listés dans `docs/ART_DIRECTION.md` § 1, plus leurs moodboards dans `docs/references/moodboards/`.
- **Références principales** (elles définissent la DA) : **King Tréant, Tréant, Slime King, King Orc**. Les gobelins #12 et #15, les slimes et `Treant_Arbre` sont **secondaires**. En cas d'hésitation, suivre la logique des quatre principales, sans les copier.
- Les **personnages existants** (ex. `Heros_Base` du Bestiaire, mannequins R15, modèles en blocs de couleur unie) **ne sont pas une référence artistique**. Ne pas s'en inspirer.
- Les futurs personnages jouables suivent **exactement** la même DA que les monstres et boss (`docs/CHARACTER_ART_DIRECTION.md`).
- Les monstres n'ont **aucune rareté**. N'en inventer aucune.

## Avant de créer

1. Lire le brief, `docs/ART_DIRECTION.md`, puis le workflow : `docs/MONSTER_PRODUCTION.md` (monstre/boss) ou `docs/CHARACTER_ART_DIRECTION.md` (personnage).
2. Inspecter réellement dans Roblox Studio (MCP) les créations validées les plus proches du brief. Ne pas supposer ce que Studio peut dire.

## Avant de déclarer terminé

- Capture d'écran réelle, puis contrôle avec `docs/VISUAL_QA.md`. Seuls résultats possibles : **PASS** ou **FIX**. Pas de PASS sans capture.
- Après des captures avec `screen_capture`, réinitialiser la caméra de Studio (procédure dans `docs/MONSTER_PRODUCTION.md`, § Outils), sinon l'utilisateur perd le clic droit et le clic molette.

## Projet

- Code Luau uniquement dans Git (`src/`), synchronisé par Rojo. Jamais de script écrit dans Studio. Branches `feature/*` → PR vers `develop` (voir `README.md`).
- Modèles et assets : dans Studio, pas dans Git. Toujours placer relativement aux repères existants et enregistrer une étape `ChangeHistoryService` (Ctrl+Z).
