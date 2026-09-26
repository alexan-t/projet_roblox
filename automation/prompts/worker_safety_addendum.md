# Addendum Worker Windows — sécurité obligatoire

À lire en complément de `automation/prompts/worker_windows.md`.

Avant chaque étape importante :

1. Vérifie si `automation/STOP` existe.
2. Lis `automation/control.json`.
3. Mets à jour `automation/state/<task_id>.json`.

Si `STOP` existe ou si `emergency_stop` vaut `true`, arrête la tâche après avoir sauvegardé l'état.

Si `paused` vaut `true`, termine seulement l'étape atomique en cours, sauvegarde l'état puis arrête-toi.

Si une limite d'utilisation Claude t'empêche de continuer, mets la tâche en `waiting_for_worker`, sauvegarde `next_step`, puis arrête-toi. Ne passe jamais la tâche en `failed` pour une simple limite d'utilisation.

À la prochaine session, reprends d'abord toute tâche `waiting_for_worker`, `in_progress` ou `fix_required` avant de prendre une nouvelle tâche `todo`.
