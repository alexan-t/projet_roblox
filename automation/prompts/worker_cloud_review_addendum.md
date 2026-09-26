# Worker Windows — review Cloud V1.2

Lire `automation/CLOUD_REVIEW_README.md` et appliquer les contrats de production et
de sécurité. Le worktree actif de ce pipeline est `C:\Users\teofo\roblox_worktrees\monster-pipeline`.

- Commencer par STOP/control et le checkpoint. Une tâche `awaiting_review` doit
  reprendre sa review, jamais sa construction depuis zéro.
- `monster_001` existe déjà : conserver `Workspace.HandoffTest_Pilleur`, son archive
  et son emplacement Monstres #16. Le checkpoint signale une étape ChangeHistory
  laissée ouverte ; sauvegarde et relance Studio avant une correction si nécessaire.
- Quand les captures d'une passe sont prêtes, écrire des noms `iteration_NN_*.png`,
  les référencer dans `tasks.json`, puis synchroniser queue et état en `awaiting_review`.
- Lancer `python automation/cloud_review_bridge.py --task <id>`. Ne pas entamer
  une autre créature pendant l'attente. Ne pas remplacer la review externe par sa propre QA.
- Code 0 : lire `latest_review` et le statut **dans tasks.json**, pas seulement le verdict.
  `human_review` exige l'utilisateur même si le JSON contient PASS.
- Code 2 : corriger le problème signalé ou attendre la disponibilité du service.
  Ne pas passer la tâche à `failed` et ne pas inventer de review.
- Code 3 / 130 : arrêt demandé ; sauvegarder puis attendre la reprise.
- Pour `fix_required`, lire les `required_changes`, préserver les parties satisfaisantes,
  incrémenter une seule fois l'itération au début de la passe et sauvegarder immédiatement
  queue + état avec `in_progress` et `next_step`. Après quota/crash, reprendre cette même
  itération à son checkpoint, sans nouvelle incrémentation.
- Après les corrections, nouvelles captures, puis nouvelle review. Ne jamais dépasser
  `max_iterations`. Ne jamais modifier les anciennes captures d'une demande déjà envoyée.
- Pour `done`, sauvegarder le modèle dans Studio et commiter/pousser uniquement le JSON
  de review, `automation/tasks.json` et `automation/state/<id>.json`, puis prendre la tâche suivante.
  Pour FIX/human_review, sauvegarder également ces trois fichiers avant d'avancer.
- Après quota, conserver la tâche et son `next_step` en `waiting_for_worker`. Au retour,
  la session Windows doit être relancée pour reprendre. Le bridge ne la réveille pas.

La suppression de STOP autorise la reprise ; elle ne prouve ni le retour du quota ni
la connexion MCP. Vérifier Studio et cibler la place réelle avant toute modification.
