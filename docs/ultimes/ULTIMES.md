# Ultimes des 60 héros — Direction de gameplay et animation

Conception proposée, à valider et équilibrer. Les noms et équipements des héros correspondent aux briefs de référence fournis. Les ultimes ne sont pas des fonctionnalités déjà développées.

> **Repères dans le dépôt** (ajouté à l'import, le reste du document est le brief tel que fourni) :
> - Données : [`ultimes_60_heros.json`](ultimes_60_heros.json), un objet par héros
>   (`production_status = concept_proposed` pour tous).
> - `hero_NNN` / « NN. » = rang du héros dans `src/shared/Config/HeroConfig.lua` (ordre du catalogue),
>   **pas** le numéro de socle du Bestiaire ni le `HeroId` réel. Ex. `hero_006` Guetteuse des Pins =
>   `guetteuse_des_pins`, socle 14.
> - Seul l'Écuyer a un ultime animé aujourd'hui (style `Rempart`, `docs/ANIMATION_TOOLS.md`) ; son
>   brief ci-dessous (« Rempart Fermé ») est une nouvelle proposition.
> - Animation : `docs/ANIMATION_TOOLS.md` et `docs/SKELETON.md` (squelette commun, arme tenue par
>   `Poing` / `Prise`) ; effets : `src/client/Controllers/UltimateEffectController.lua`.

## Contraintes pour la production Roblox

1. L'animation du héros fait l'essentiel du spectacle : anticipation, pose identifiable, impact, retour en garde. Aucun écran blanc ou flash global.
2. VFX localisés au héros et aux cibles. Garder la grille 3×3, les silhouettes, les barres de vie et de mana lisibles.
3. Pas de déplacement de caméra imposé, pas de ralenti global, pas de secousse répétée, pas de blocage général des commandes.
4. Créer les personnages et armes avec leurs vrais points d'ancrage et respecter la version effective des modèles du brief (certaines ont divergé du concept initial).
5. VFX majoritairement client, dégâts et états calculés côté serveur. Réutiliser les effets et leur permettre de se simplifier lorsque plusieurs ultimes sont simultanés.
6. Une seule forme signature majeure par ultime : un effet de lame, une structure géométrique, un familier éphémère ou un changement de posture. Éviter les nuages opaques et les effets persistants.
7. Durées ci-dessous : cibles d'animation complètes et non des durées de contrôle de personnage. La fin visuelle peut être accélérée si les ultimes sont fréquents.
8. Un héros des raretés supérieures se distingue d'abord par la chorégraphie et la précision de son pouvoir, pas par une saturation de particules.

## Commun — 0,6 à 0,8 s

### 01. Écuyer du Rempart : Rempart Fermé

**Animation :** Il cale son bouclier de bois au sol et avance d'un pas ; un choc court en forme de bouclier frappe devant lui.

**Intention gameplay :** Protection brève des alliés proches et interruption légère des ennemis en face.

### 02. Tireuse des Faubourgs : Le Dernier Carreau

**Animation :** Elle pose un genou à terre, arme son arbalète et lâche un carreau lourd qui laisse une fine traînée tendue.

**Intention gameplay :** Tir perforant sur une ligne courte, priorité à une cible distante.

## Peu commun — 0,7 à 0,9 s

### 03. Lancier des Champs : Haie de Lances

**Animation :** Il pivote sa longue lance à l'horizontale puis porte trois estocs en éventail, avec de sobres traits de fer.

**Intention gameplay :** Repousse ou interrompt brièvement les ennemis de première ligne.

### 04. Apprenti Pyromancien : Braise Indocile

**Animation :** La gemme du bâton tousse trois petites braises ; il en rattrape une du bout du bâton et la propulse sur deux cibles.

**Intention gameplay :** Petit sort de feu rebondissant, brûlure courte.

### 05. Brise Pierre : Fendaille de Carrière

**Animation :** Elle ramène sa masse de pierre derrière la tête et assène un coup massif ; le sol s'ouvre en une fissure d'une seule longueur de masse.

**Intention gameplay :** Fort dégât sur cible et affaiblissement d'armure.

### 06. Guetteuse des Pins : Cor des Cimes

**Animation :** Elle sonne brièvement du cor à sa ceinture puis décoche une flèche qui suit le contour lumineux très fin d'un pin.

**Intention gameplay :** Désigne une cible prioritaire et augmente les dégâts concentrés contre elle.

## Rare — 0,8 à 1,1 s

### 07. Chevalier du Lierre : Muraille de Lierre

**Animation :** Il frappe le bas de son bouclier ; trois grosses tiges de lierre jaillissent comme un parapet miniature puis se rétractent.

**Intention gameplay :** Protège les héros derrière lui et gêne l'avancée ennemie.

### 08. Mage des Lanternes : La Veillée

**Animation :** Elle balance sa lanterne au bout du bâton ; un ruban ambré en rejoint deux alliés puis revient dans la lanterne.

**Intention gameplay :** Bouclier léger ou petit soin de soutien ciblé.

### 09. Fauconnier Gris : Piqué du Fauconnier

**Animation :** Le faucon quitte son gant en spirale, replie les ailes, plonge sur la cible, puis revient aussitôt se poser.

**Intention gameplay :** Frappe ciblée et marque facilitant les prochaines attaques.

### 10. Lancière des Sources : Serment de la Source

**Animation :** Elle décrit un demi-cercle avec sa lance ; un étroit ruban d'eau suit la pointe puis éclate en gouttes contre la première ligne.

**Intention gameplay :** Balayage de mêlée et légère régénération de l'allié le plus proche.

### 11. Barde de Fer : Accord de Fer

**Animation :** Il pince une grosse corde de son luth puis frappe sa cloche-masse : deux notes métalliques visibles se propagent au sol.

**Intention gameplay :** Améliore brièvement l'attaque alliée et trouble les monstres proches.

### 12. Moine du Vent Bas : Trois Pas Rasants

**Animation :** Il glisse très bas entre deux ennemis, frappe de chaque paume et finit par une poussée circulaire de ses gantelets.

**Intention gameplay :** Triple frappe rapide en mêlée, léger recul final.

## Épique — 1 à 1,3 s

### 13. Gardien des Ronces : Bastion d'Épines

**Animation :** Il plante son bouclier-pavois, abaisse sa masse et fait dresser un mur de trois ronces épaisses en chevron.

**Intention gameplay :** Blocage temporaire et immobilisation locale des ennemis.

### 14. Cartomancienne d'Ambre : Les Trois Présages

**Animation :** Elle éventaille trois cartes d'ambre, en choisit une d'un geste sec ; les deux autres frappent les côtés de la cible.

**Intention gameplay :** Trois frappes de contrôle, avec ralentissement ou courte pétrification.

### 15. Duelliste du Croissant : Croissant Retourné

**Animation :** Il laisse l'ennemi attaquer, pivote sur son talon en parade et dessine un unique croissant argenté avec son sabre.

**Intention gameplay :** Contre-attaque rapide à la première ligne, dégâts plus forts à la cible focalisée.

### 16. Forgeron Runique : Le Sceau du Marteau

**Animation :** Il frappe son marteau runique dans l'air comme sur une enclume ; une marque de forge descend sur les armes des alliés proches.

**Intention gameplay :** Petit choc frontal et renforcement offensif temporaire des alliés.

### 17. Prêtresse aux Lucioles : La Luciole-Mère

**Animation :** Elle ouvre la main ; la fleur du bâton s'entrouvre et cinq lucioles vert-or rejoignent en courbe les alliés blessés.

**Intention gameplay :** Soin réparti, petite bénédiction défensive.

### 18. Briseur de Cloche : Beffroi Fracturé

**Animation :** Il cogne son battant contre la cloche-bouclier ; une seule onde de bronze en anneau se détache de la fissure.

**Intention gameplay :** Étourdissement très court en zone proche et protection du lanceur.

### 19. Veneur de Givre : Le Cri de la Meute Blanche

**Animation :** Il souffle dans son cor ; l'ombre d'un grand loup blanc jaillit de sa cape, traverse une cible puis s'évapore en givre.

**Intention gameplay :** Charge spectrale qui ralentit la cible et inflige un coup fort.

### 20. Alchimiste aux Masques : Le Masque Émeraude

**Animation :** Elle relève son masque d'os, retourne son bâton-alambic et projette deux grosses gouttes vertes, l'une alliée, l'autre ennemie.

**Intention gameplay :** Amélioration ou soin d'un allié et affaiblissement d'un ennemi.

## Légendaire — 1,1 à 1,5 s

### 21. Chevalier du Soleil Creux : Jugement du Soleil Creux

**Animation :** Il présente son bouclier ; l'anneau solaire de son heaume s'aligne derrière lui, puis il abat son épée dans un rayon bronze étroit.

**Intention gameplay :** Frappe frontale et petit bouclier accordé aux alliés adjacents.

### 22. Dame aux Mille Bannières : La Marche des Étendards

**Animation :** Elle plante son étendard-lance ; ses trois fanions dorsaux se déploient l'un après l'autre dans un claquement impeccable.

**Intention gameplay :** Ralliement : bonus d'attaque et de résistance des alliés proches.

### 23. Lancier des Sept Orages : Fracture des Sept Cieux

**Animation :** Il fait tourner sa lance ; sept pointes de foudre s'alignent brièvement sur son fer avant un estoc qui trace un zigzag précis.

**Intention gameplay :** Dégâts sur une ligne et interruption d'attaque ennemie.

### 24. Architecte de Golems : Main du Bâtisseur

**Animation :** Elle pose son bâton-clef de voûte ; son énorme gantelet de pierre se déploie puis deux murs courts émergent en tenaille.

**Intention gameplay :** Coup de zone restreinte, rassemblement et protection des alliés.

### 25. Veuve du Lac Miroir : Reflet d'Absence

**Animation :** Elle incline son bâton-miroir ; un seul reflet argenté apparaît derrière la cible et reproduit son geste avec un temps de retard.

**Intention gameplay :** Renvoie une part des dégâts et ralentit l'ennemi visé.

### 26. Chasseur de Comètes : La Comète Captive

**Animation :** Il fait pivoter son marteau-cage au-dessus de l'épaule et écrase le fragment incandescent sur le sol, soulevant trois éclats rocheux.

**Intention gameplay :** Forte frappe de mêlée avec petite zone d'impact.

### 27. Saint du Brasier Bleu : Procession du Brasier Bleu

**Animation :** Il lève sa vasque de feu bleu puis la ramène près du cœur ; une procession de flammes basses longe les alliés.

**Intention gameplay :** Purification et soin bref des alliés, brûlure des ennemis tout proches.

### 28. Gardienne de la Dernière Cloche : Dernière Résonance

**Animation :** Elle tourne les épaules et frappe la cloche portée sur son dos avec son maillet ; deux arcs de bronze résonnent devant elle.

**Intention gameplay :** Réduction de dégâts alliée et étourdissement frontal bref.

### 29. Prince des Racines d'Or : Droit des Racines d'Or

**Animation :** Il plante son épée ; trois racines dorées s'entrelacent en arc protecteur, puis une pointe s'élance vers l'ennemi.

**Intention gameplay :** Protection de la première ligne et entrave d'une cible.

### 30. Archiviste du Temps Mort : La Seconde Rayée

**Animation :** Il retourne son bâton-sablier : les grains remontent ; les ennemis ralentissent en silhouettes dédoublées pendant un instant.

**Intention gameplay :** Contrôle temporel court et petite réparation des PV alliés.

## Mythique — 1,2 à 1,6 s

### 31. Navigateur des Cieux Renversés : Latitude Inversée

**Animation :** Il trace un cap avec sa gaffe-harpon ; sa rose des vents se retourne, soulevant légèrement les ennemis avant de les reposer lourdement.

**Intention gameplay :** Soulèvement bref en petite zone et soutien de placement.

### 32. Reine des Cent Lames : Couronne des Cent Lames

**Animation :** Ses six épées dorsales se referment comme les doigts d'une main puis piquent des cibles successives avant un dernier coup de sa propre épée.

**Intention gameplay :** Frappes réparties sur quelques ennemis, priorité à la cible principale.

### 33. Berger des Astres : Le Troupeau des Astres

**Animation :** Il ramène les trois étoiles de sa houlette d'un geste de berger ; elles dessinent la silhouette fugace d'un bélier qui charge.

**Intention gameplay :** Protection alliée et poussée douce des ennemis en ligne.

### 34. Géant au Cœur de Verre : Dernier Battement de Verre

**Animation :** Il frappe son cœur cristallin du poing ; les cinq éclats derrière lui s'ouvrent en éventail puis se referment comme une cage.

**Intention gameplay :** Provocation ou absorption de dégâts, contre-choc en mêlée.

### 35. Sorcière des Marées Lunaires : Marée à Rebours

**Animation :** Elle incline son croissant de nacre ; une lame d'eau étroite remonte vers elle, emporte deux ennemis et repart en vague douce.

**Intention gameplay :** Rassemblement bref des cibles et dégâts de contrôle.

### 36. Chevalier de l'Éclipse Blanche : Éclipse du Rempart

**Animation :** Son disque d'éclipse se place devant son bouclier ; les coups absorbés se dessinent en quelques traits or pâle qu'il renvoie d'un coup de masse.

**Intention gameplay :** Bouclier d'équipe local et contre-attaque frontale.

### 37. Maître des Portes Oubliées : La Porte Entre-Deux

**Animation :** Il tourne sa clé géante ; les cinq pierres de son arche composent un seuil près des ennemis, dont les battants se referment aussitôt.

**Intention gameplay :** Entrave de petite zone et réduction d'élan des ennemis.

### 38. Gardienne du Dragon Dormant : Souffle du Dragon Endormi

**Animation :** Elle baisse sa glaive ; ses cinq écailles flottantes dessinent un museau de dragon qui souffle une rafale d'ambre en cône.

**Intention gameplay :** Balayage, ralentissement et protection légère de l'avant-garde.

### 39. Tisseur de Destins : Nœud Irrévocable

**Animation :** Ses fuseaux filent trois fils carmin vers des cibles ; il tire d'un coup sur la quenouille et resserre les liens.

**Intention gameplay :** Relie quelques ennemis pour partager une part des dégâts reçus.

### 40. Empereur des Cendres d'Or : Le Dernier Décret

**Animation :** Il pose son sceptre-masse comme un insigne impérial ; ses pointes de couronne se rangent en trône derrière lui, puis un sceau de cendres tombe.

**Intention gameplay :** Coup de zone courte et bref commandement offensif des alliés.

## Maudit — 1,2 à 1,6 s

### 41. Porteur du Cœur Noir : La Dîme du Cœur

**Animation :** Son cœur noir suspendu bat deux fois ; des nervures d'ombre rampent vers les ennemis proches et reviennent se refermer sur sa cage thoracique.

**Intention gameplay :** Drain de vie local et récupération défensive du lanceur.

### 42. Chevalier aux Mille Clous : Litanie des Mille Clous

**Animation :** Il frappe son maillet au sol ; quelques clous sortent de son armure, se dressent en demi-cercle puis tombent en cadence.

**Intention gameplay :** Dégâts en cône et réduction temporaire de défense.

### 43. Nonne de la Lune Fendue : Lune Sacrifiée

**Animation :** Elle fauche à hauteur de taille ; son halo lunaire fendu quitte un instant sa cornette, décrit une orbite coupante et revient.

**Intention gameplay :** Balayage en arc avec vol de vie modéré.

### 44. Roi des Corbeaux Sans Ombre : Sacre des Corbeaux

**Animation :** Il ouvre son manteau de plumes ; cinq corbeaux noirs en jaillissent, piquent un ennemi puis se recomposent en cape.

**Intention gameplay :** Assaut ciblé et affaiblissement temporaire de la cible.

### 45. Marionnettiste des Tombes : La Danse des Tombes

**Animation :** Il croise les mains comme un marionnettiste ; deux bras de squelette surgissent brièvement, guidés par des fils, pour frapper en cadence.

**Intention gameplay :** Contrôle de deux cibles et frappes fantomatiques courtes.

### 46. Lame du Serment Brisé : Serment à Rebours

**Animation :** Elle traîne sa lame brisée, marque un arrêt, puis bondit : la portion manquante de la lame apparaît une fraction de seconde pour achever l'entaille.

**Intention gameplay :** Frappe lourde en ligne, dégâts accrus aux ennemis déjà blessés.

### 47. Sorcier de la Couronne Parasite : La Couronne qui Germe

**Animation :** La couronne parasite ouvre ses pointes comme des pétales ; trois graines sombres bondissent aux pieds adverses et s'enracinent.

**Intention gameplay :** Spore de petite zone, dégâts progressifs et affaiblissement.

### 48. Chasseur de Noms : Le Nom Rayé

**Animation :** Il harponne sa cible ; un parchemin se déroule sur la hampe et une barre noire traverse une rune avant qu'il tire violemment.

**Intention gameplay :** Harpon ciblé, rapprochement ou immobilisation et bonus de finition.

## Suprême — 1,4 à 1,8 s

### 49. Séraphin des Sept Sceaux : Les Sept Fermetures

**Animation :** Il tourne son épée-clé ; sept sceaux sacrés s'emboîtent en petite rosace autour des ennemis avant de claquer en silence.

**Intention gameplay :** Scelle temporairement les cibles et protège la première ligne.

### 50. Reine du Firmament Doré : Décret du Firmament

**Animation :** Elle élève son sceptre-astre ; trois étoiles dorées forment une couronne triangulaire, puis trois traits de lumière douce descendent sur des cibles.

**Intention gameplay :** Dégâts de zone contrôlés et bénédiction des alliés.

### 51. Chevalier de l'Aube Infinie : Premier Matin

**Animation :** Il lève son épée ; le demi-soleil derrière ses épaules s'élève de quelques degrés, puis la lame trace un arc horizontal couleur d'aube.

**Intention gameplay :** Percée frontale, légère protection de son groupe.

### 52. Oracle aux Cent Yeux : Tout Est Écrit

**Animation :** Son éventail d'yeux s'ouvre rang par rang ; elle pointe un ennemi et trois symboles de prédiction apparaissent au-dessus des attaques à venir.

**Intention gameplay :** Révèle les cibles prioritaires et accorde une esquive ou protection anticipée.

### 53. Forgeâme : Enclume de l'Âme

**Animation :** Il présente son marteau ; une enclume de lumière sobre apparaît à ses pieds et un seul coup de forge projette deux marques vers les alliés.

**Intention gameplay :** Amélioration temporaire des armes alliées et choc en mêlée.

### 54. Gardien du Trône Vide : Défense du Roi Absent

**Animation :** Il pose sa hallebarde devant lui ; l'ombre d'un trône vide se déploie derrière ses épaules, encadrée de deux gardes de pierre éphémères.

**Intention gameplay :** Gros bouclier de ligne et contre-attaque sur les assaillants.

## Calamité — 1,5 à 2 s

### 55. Marcheur du Cataclysme : La Chute en Marche

**Animation :** Il soulève sa masse-météore ; trois dalles fendues se décollent du terrain autour de la cible avant de retomber avec le coup.

**Intention gameplay :** Écrasement de zone localisée et bref renversement.

### 56. Reine de la Mer Renversée : L'Océan Debout

**Animation :** Elle relève son grand trident ; une paroi d'eau verticale se forme derrière l'ennemi puis se replie vers lui comme un rideau.

**Intention gameplay :** Rassemblement et coup de vague sur une petite zone.

### 57. Soleil Dévoré : Éclipse Affamée

**Animation :** Il ouvre sa faux en grand arc ; le soleil enfermé dans son torse s'obscurcit puis un croissant noir traverse les ennemis et revient se refermer.

**Intention gameplay :** Grand balayage, absorption modérée de vie et affaiblissement.

### 58. Titanide des Derniers Jours : La Dernière Terre

**Animation :** Elle traîne son épée-menhir ; une crête de ruines de pierre se soulève devant elle, puis se fracture exactement au passage de sa lame.

**Intention gameplay :** Lourds dégâts en ligne large et protection momentanée des alliés derrière elle.

## Transcendant — 1,7 à 2,2 s

### 59. Aureon, Porteur de la Première Aube : À la Première Lumière

**Animation :** Il abaisse sa longue lance ; le demi-disque d'aube derrière lui dessine un horizon, et trois rayons fins avancent successivement depuis sa pointe.

**Intention gameplay :** Triple percée lumineuse ciblée, bouclier bref aux alliés.

### 60. Elyria, Celle qui Marche Hors du Temps : La Seconde qui Manque

**Animation :** Elle incline sa glaive ; les anneaux armillaires s'arrêtent net tandis que deux silhouettes temporelles exécutent, à quelques pas d'écart, le même coup avant de se rejoindre.

**Intention gameplay :** Deux frappes quasi simultanées et immobilisation très brève de la cible, sans arrêter le jeu.

