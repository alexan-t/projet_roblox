# Sources figées — Invocation V2

Archive reçue : `Mid-century desk lamp (1).zip` ; SHA-256 `326485147d12b272187f8299a63bf6a14b774f5966eca82a749915232a417a6b`.

Inventaire intégral : 111 fichiers, 7 364 343 octets décompressés : 8 HTML, 2 JS, 43 SVG, 55 PNG, 1 JPG, 1 TXT et 1 vignette sans extension. `source-manifest.json` donne le SHA-256 de chaque entrée originale, y compris les fichiers non utilisés par cette issue.

Sources visuelles retenues : `Invocation.dc.html`, `HeroCard.dc.html`, `assets/invocation/LISEZMOI.txt`, 21 PNG d'invocation (et leurs SVG), monnaies. Les originaux conservés ici sont copiés sans retouche ; `support.js` permet de consulter les maquettes HTML et `refs/world.png` sert uniquement de fond de référence. Ces fichiers ne sont pas exécutés dans Roblox.

L'archive comprend aussi les planches Menu, Monnaies et Quêtes déjà intégrées, des images de référence et un exemple Desk Lamp/three.js sans rapport avec l'invocation. Ils ont été inventoriés ; ils n'ajoutent aucune instruction de gameplay ni de redesign.

Les 21 PNG d'invocation sont importés dans Roblox ; leurs identifiants sont dans `src/shared/Config/InvocationVisualConfig.lua`. Les monnaies utilisent les identifiants existants de `CurrencyVisualConfig`. Les cadres 1–10 correspondent à l'ordre exact de `RarityConfig`. Le PNG bannière @2x (1200×680) est réduit par Roblox à 1024×580 ; le SliceCenter du README est ajusté proportionnellement.

Le prototype contient du RNG et des soldes factices pour sa démonstration : ils ne sont jamais repris comme règles. Le calcul des chances de vedette affichées dans le prototype omet le chemin via le pool normal. Le serveur publie la probabilité totale exacte, tout en conservant le panneau et les visuels figés. La garantie suit la précision du prototype : « Épique ou mieux ».
