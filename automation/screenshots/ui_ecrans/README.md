# Séances de capture des écrans du jeu

Un sous-dossier par séance : `AAAA-MM-JJ/`. Il contient toutes les captures de la séance (variantes
fond clair / fond sombre, détails, essais), nommées avec le préfixe de l'écran
(`08_expedition_sombre.png`). La capture retenue pour chaque écran est copiée dans
`docs/references/ui/ecrans/` sous le nom exact de l'inventaire.

Inventaire, procédure et format : `docs/references/ui/README.md`.

Chaque séance a un `README.md` court :

```markdown
# Séance AAAA-MM-JJ
Branche / commit : develop @ <sha>
Place : test, fenêtre 1920 × 1080
Écrans capturés : 01, 02, ...
Écrans non atteints et pourquoi : ...
Démonstrations utilisées à la place du jeu : ...
Caméra réinitialisée : oui
```
