# Review Cloud — V1.2

Le worker reste **Claude Windows**. Le manager est une session Claude Cloud externe
qui ouvre les captures puis publie un verdict JSON. Le bridge transporte la demande
et récupère la réponse ; il ne juge pas les images et ne pilote pas l'interface de Claude.

## Dossier de travail de ce projet

Utiliser `C:\Users\teofo\roblox_worktrees\monster-pipeline`, branche
`feature/monster-pipeline`. Le dossier OneDrive `roblox projet commun` est actuellement
sur une autre branche et ne contient qu'une copie partielle du patch de sécurité.
Ne pas lancer le pipeline depuis cette copie.

La DA validée au commit `200422a` reste inchangée. `monster_001`, le Pilleur de la
rivière, est déjà construit et attend sa première review. Ne pas le recréer.

## Préparer le manager une seule fois

1. Vérifier que cette branche est poussée sur `alexan-t/projet_roblox`.
2. Dans ce dossier, avec Claude CLI connecté au compte voulu, lancer :

   ```powershell
   claude --cloud "Lis automation/prompts/manager_cloud_bootstrap.md. Prépare le rôle de manager QA, indique ton identifiant de session et ta branche de sortie autorisée. Attends une demande de review."
   ```

3. Relever le `session_...` (ou `cse_...`) et la branche **réelle** annoncée par le
   manager. La branche de sortie doit être différente de `feature/monster-pipeline`,
   `develop` et `main`. Ne pas supposer que la session peut écrire sur la branche du worker.
4. Copier `automation/cloud_manager_config.json` vers
   `automation/cloud_manager_config.local.json`, puis remplir `session_id` et
   `review_branch`. Le fichier `.local.json` est ignoré par Git. Si nécessaire,
   indiquer le chemin du lanceur Claude dans `claude_command`. Ne pas y mettre de token.

   ```json
   {
     "session_id": "session_REMPLACER",
     "review_branch": "claude/REMPLACER_PAR_LA_BRANCHE_REELLE",
     "claude_command": "claude"
   }
   ```

5. Python 3.10+ et Git doivent fonctionner dans le terminal du worker. Aucun module
   Python supplémentaire n'est requis. Vérifier sans envoyer de demande :

   ```powershell
   python automation/cloud_review_bridge.py --check
   ```

   Si Windows utilise le lanceur Python, remplacer `python` par `py -3`.
   `--check` ne teste ni l'authentification ni la qualité visuelle du manager.

## Première review

Lire l'addendum `automation/prompts/worker_cloud_review_addendum.md`, puis lancer :

```powershell
python automation/cloud_review_bridge.py --task monster_001
```

Le bridge :

- vérifie STOP, pause, tâche, état, captures courantes et configuration ;
- écrit un manifeste immuable avec l'identifiant de tâche, l'itération et les SHA256
  des entrées. Pour `.md`/`.json`, le BOM UTF-8 est retiré et CRLF est normalisé en LF ;
- commit/push **uniquement** la tâche, son état, ses captures courantes et le manifeste ;
- refuse un index Git déjà rempli, et tout document artistique modifié non commité ;
- cherche une review existante avant de solliciter le Cloud ;
- envoie une demande à la session configurée et attend la review sur sa branche de sortie ;
- importe uniquement le JSON demandé, jamais les autres modifications du manager ;
- vérifie `request_id`, tâche, itération et cohérence du verdict avant d'appliquer le résultat.

La commande Claude d'envoi utilise `-p --cloud SESSION_ID --output-format json`,
avec le prompt sur l'entrée standard. Elle confirme la mise en file d'attente,
sans attendre le verdict. Voir la [documentation officielle Claude](https://code.claude.com/docs/en/claude-code-on-the-web#send-follow-ups-from-the-cli).

Les reviews V1.2 portent un nom incluant leur `request_id` :
`automation/reviews/monster_001_iteration_00_<request_id>.json`.
Le champ `latest_review` est la référence à suivre ; ne pas deviner un nom de fichier.

## Résultat et reprise

| Résultat | Statut de la tâche | Action du worker |
|---|---|---|
| PASS, confiance moyenne/haute, sans alerte humaine | `done` | Sauvegarder, puis tâche suivante |
| FIX, corrections encore autorisées | `fix_required` | Corriger le modèle existant |
| FIX à la limite d'itérations | `human_review` | Attendre l'utilisateur |
| Confiance faible ou `human_attention` non vide | `human_review` | Attendre l'utilisateur |
| Réseau/Cloud indisponible ou délai dépassé | `awaiting_review` conservé | Relancer le bridge plus tard |

Le résultat est enregistré localement dans la review, l'état puis la queue. Le worker
doit commiter/pousser ces trois fichiers avant d'enchaîner une nouvelle tâche. La review
Cloud reste également présente sur la branche du manager. Aucun `force push`, `reset`,
merge ou stash n'est exécuté automatiquement.

L'itération 0 est la première création ; `max_iterations: 3` autorise les passes de
correction 1, 2 et 3. Une dernière review de la passe 3 peut encore donner PASS.
Le bridge n'incrémente pas l'itération : le worker le fait une seule fois au début
d'une nouvelle passe de correction, en mettant aussi à jour le checkpoint.

## Stop, quota et erreurs

- Créer `automation/STOP` dans **ce worktree**, ou mettre `paused` / `emergency_stop`
  à `true` dans `control.json`, arrête les nouvelles actions du bridge.
- Pendant l'attente, ces contrôles sont relus chaque seconde. Une commande Git/Claude
  déjà lancée peut prendre jusqu'à 60 secondes avant le prochain contrôle. STOP local
  n'annule pas une demande Cloud déjà transmise ; arrêter aussi la session Cloud si nécessaire.
- Le bouton Stop/Esc de Claude Windows reste le moyen d'interrompre son action interactive.
- Supprimer STOP ou lever la pause, puis relancer le bridge. Il récupère d'abord toute
  review existante. Il ne renvoie pas automatiquement une demande déjà envoyée.
- Une interruption pendant l'envoi laisse un reçu `delivery_unknown` dans `.local/`.
  Vérifier la session Cloud ; utiliser `--resend` seulement si la demande n'y est pas
  arrivée ou si le manager doit être relancé. Ne pas effacer les reçus pour forcer une boucle.
- Une erreur Git ou un JSON invalide arrête le bridge sans inventer de verdict. Les
  commits locaux et checkpoints restent disponibles. Résoudre le problème puis reprendre.
- Après une erreur de commit, vérifier l'index : le bridge refuse de reprendre avec
  un index non vide. Ne pas retirer les changements d'un autre travail.
- Une limite du worker se note `waiting_for_worker` avec `next_step` sauvegardé.
  **Le réveil automatique de Claude Windows après quota n'est pas fourni par cette V1.2.**
  Relancer sa session et lui demander de reprendre son checkpoint. Un manager sans
  quota laisse la tâche en attente ; il ne transforme jamais un manque de quota en FIX.
- Garder un seul worker actif sur une tâche. Le verrou empêche deux bridges concurrents
  dans le même worktree, mais ne verrouille pas Roblox Studio ni un autre ordinateur.

## Validation locale

```powershell
python -m unittest discover -s automation/tests -v
```

Les tests couvrent le transport avec un dépôt Git local, PASS/FIX, l'arrêt, les reviews
périmées, les captures modifiées, les doublons, les limites et l'import sans fusion.
Ils ne remplacent pas une première review réelle dans Claude Cloud.
