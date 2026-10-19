# Design system UI

Référence pour **toutes** les interfaces du jeu : HUD, fenêtres, préparation de combat, panneaux
dans le monde. Les valeurs vivent dans un seul module, `src/shared/Config/UITheme.lua`
(`ReplicatedStorage.Shared.Config.UITheme`). **Aucune couleur, transparence, police, rayon ou
durée en dur dans un Controller** : on lit `UITheme`.

Référence visuelle : les **captures des écrans réels**, une par écran, dans
`docs/references/ui/ecrans/` (inventaire, procédure et état dans `docs/references/ui/README.md`).
La maquette `docs/references/ui/maquette_v1.jpg`, construite avant les écrans, est **périmée** :
ne plus s'en servir pour juger une interface.

## 1. Charte en une phrase

L'UI est faite **des mêmes matières que la map** (bois, sable, toile, pierre), en **formes
rondes et généreuses**, avec un **contour noir chaud net** et du **texte Fredoka One
contouré**, posée en **semi-transparence** pour que l'on voie toujours le monde derrière.

```
monde 3D toujours visible
+ panneau légèrement teinté (bois sombre ou crème, semi-transparent)
+ contour Ink net qui suit les coins arrondis
+ texte Fredoka One clair, contour Ink
```

Ce qui est **hors DA** : gros rectangles opaques plein écran, dégradés glossy, textures
réalistes, icônes plates génériques ou emoji, traits fins, style futuriste ou « app mobile »,
liseré marron semi-transparent, texte blanc sans contour sur fond transparent.

## 2. Palette

Les couleurs « matière » sont **relevées dans la map** (surfaces de `PlotTravail`, `Lobby` et
`PlotsZones` pondérées par leur taille), pas inventées.

### Matières

| Token | Hex | Vient de | Usage UI |
| --- | --- | --- | --- |
| `Ink` | `#1F1A17` | — | contours, voile, fond des barres |
| `InkSoft` | `#3A2C22` | — | texte sur fond clair (infobulle) |
| `TextLight` | `#FFF6E4` | — | texte sur fond foncé ou coloré |
| `TextMuted` | `#CDBFA6` | — | texte secondaire sur fond foncé |
| `Cream` | `#F3E6C8` | murs, tour | cartes, infobulles |
| `Sand` | `#E2D4B8` | dallage | zone d'illustration des cartes |
| `SandWarm` | `#DEBC82` | clairières | variantes de cartes |
| `SandGold` | `#E8C670` | chemins, pont | progression |
| `Stone` / `StoneDark` / `StoneGrey` | `#D6C6A8` / `#A89880` / `#968A7E` | bordures, murets, rochers | neutre, verrouillé |
| `WoodLight` / `Wood` / `WoodDark` | `#BA8454` / `#96623E` / `#6C442A` | pont, palissade, troncs | boutons secondaires, bandeaux de titre |
| `WoodDeep` | `#3E2A1C` | bois très sombre | fond des panneaux et du HUD |
| `Grass` / `GrassLight` / `Leaf` | `#7AB854` / `#8CC050` / `#408E4A` | herbe, buissons, feuillage | décor, succès |
| `River` / `RiverLight` / `Foam` | `#46A2EC` / `#76CCF6` / `#ECF8FF` | eau, cascade | information, énergie |
| `Gold` / `GoldLight` / `GoldDeep` | `#E6B23A` / `#F5CB5C` / `#C98E22` | emblèmes, bordures | bouton principal, sélection, or |
| `RoyalRed` | `#B83E30` | toiles, drapeaux | fermer, danger, « Nouveau » |
| `RoyalBlue` | `#3460B0` | drapeau du royaume | identité du royaume (rare) |
| `Torch` / `Crystal` | `#FF8C28` / `#48E8E8` | torches, cristaux | accents très rares |

### États

| Token | Hex | Règle |
| --- | --- | --- |
| `Success` | `#5DB043` | quête terminée, « Disponible », gain |
| `Error` | `#D9483B` | refus, perte, PV ennemis |
| `Warning` | `#F2A93B` | attention, ressource presque vide |
| `Info` | `#46A2EC` | aide, information neutre |
| `Disabled` | `#8F8478` | fond gris pierre, contenu à `Transparency.Disabled` |
| `Selected` | `#F5C542` | contour doré épais (4 px) ou onglet doré |
| Hover | — | voile clair `Transparency.Hover` + `Animation.Scale.Hover` ; jamais seul indicateur (tactile) |

### Barres et monnaies

`Health #6CC04A`, `HealthLow #E04A3A` (≤ 30 %), `EnemyHealth #D9483B`, `Energy #46A2EC`,
`EnergyFull #F5C542` (pulse), `Progress #E8C670`, fond `BarTrack` = `Ink`.
Monnaies : `CurrencyGold #E6B23A`, `CurrencyGems #48C8E8`, `CurrencyTickets #B83E30`.

**Rareté des héros** (`UITheme.Rarity`, paliers de `RarityConfig`, voir `docs/HEROES.md`) :

| Rareté | Couleur |
| --- | --- |
| Commun | `#B9B0A3` (pierre claire) |
| Peu commun | `#6CC04A` (vert prairie) |
| Rare | `#46A2EC` (bleu rivière) |
| Épique | `#A45BE0` (violet) |
| Légendaire | `#F5C542` (or) |
| Mythique | `#FF5A8A` (rose rubis) |
| Maudit | `#7B2FA8` (violet sombre), avec de l'ombre (`Ink`) plutôt que de la lumière |
| Suprême | `#EAF3FF` (blanc céleste) |
| Calamité | `#D2321E` (braise rouge) |
| Transcendant | dégradé `UITheme.RarityPrism` qui tourne (jamais une seule couleur) |

Usage :

- badge de rareté (pastille contourée `Ink`, texte clair) ;
- contour de carte et rayons du reveal ;
- lumière de l'effet d'invocation.

Rendu commun : `src/client/UI/RarityStyle.lua`. Hors invocation, le cadre des cartes reste
neutre (`Ink`). Les **monstres n'ont aucune rareté**.

Règle de dosage, reprise de la DA : base **bois/sable** désaturée, accents saturés (or, rouge,
bleu) **rares** et porteurs de sens.

## 3. Transparence

`BackgroundTransparency` (0 = opaque). Le monde doit rester visible derrière tout ce qui n'est
pas une infobulle.

| Token | Valeur | Composant |
| --- | --- | --- |
| `Panel` | 0,25 | grand panneau, fenêtre (fond `WoodDeep`) |
| `PanelStrong` | 0,12 | sous-panneau, carte, slot, onglet inactif |
| `HUD` | 0,45 | HUD permanent (monnaies, barre de combat) |
| `Overlay` | 0,5 | voile `Ink` derrière une fenêtre modale (jamais noir plein) |
| `Tooltip` | 0,04 | infobulle (fond `Cream`, texte `InkSoft`) |
| `Track` | 0,35 | fond des barres |
| `Shadow` | 0,75 | ombre portée |
| `Disabled` | 0,45 | texte et icône d'un élément désactivé |

**Lisibilité garantie** : tout texte Fredoka posé sur un fond transparent porte un contour
`Ink` (§ 5). Un **texte long** (Builder Sans) ne se pose **jamais** directement sur un
`Panel` : il va dans un sous-panneau `PanelStrong` ou une infobulle, sinon un fond clair du
monde peut le rendre illisible.

## 4. Typographie

| Rôle | Police | Taille (px, écran 1080) | Contour |
| --- | --- | --- | --- |
| Victoire / Défaite | Fredoka One | `Hero` 56 | 4 |
| Titre de fenêtre | Fredoka One | `Title` 32 | 3 |
| Section, nom de héros | Fredoka One | `Heading` 24 | 3 |
| Bouton | Fredoka One | `Button` 22 | 3 |
| Onglet, compteur, label | Fredoka One | `Label` 18 | 2 |
| Badge, mention courte | Fredoka One | `Caption` 14 (minimum absolu) | 2 |
| Description longue | Builder Sans Medium | `Body` 18 | aucun (fond renforcé) |

- **Fredoka One** est déjà la police de tous les textes du monde (476 textes) : l'UI la reprend.
  Builder Sans (police Roblox gratuite) sert uniquement aux phrases longues.
- Texte Fredoka : couleur `TextLight` + `UIStroke` `Contextual` `Ink`. Sur infobulle crème :
  `InkSoft`, sans contour.
- Tailles fixes + `UIScale` global pour adapter à l'écran. `TextScaled` est réservé aux
  panneaux du monde.
- Labels courts, en majuscule initiale uniquement. Pas de phrases dans les boutons.
- La police n'a pas tous les symboles (« ✕ » s'affiche en carré vide) : utiliser « X » ou une icône.

## 5. Contours

- Couleur **`Ink` `#1F1A17`**, opaque, `LineJoinMode.Round`. Plus aucun liseré marron
  semi-transparent ni `TextStroke` (1 px, trop fin).
- **Panneaux, boutons, cartes** : `UIStroke` en mode `Border` sur la `Frame` qui porte le
  `UICorner` : le contour suit les coins arrondis.
- **ScreenGui** : épaisseur fixe en pixels (`StrokeSizingMode.FixedSize`), donc constante quelle
  que soit la taille du panneau : `Thin` 2 (badge, slot, barre), `Regular` 3 (bouton, carte),
  `Thick` 4 (fenêtre).
- **Panneaux du monde** (BillboardGui ou SurfaceGui dimensionnés en studs) : épaisseur relative
  (`StrokeSizingMode.ScaledSize`, `WorldScaled` = 0,08), pour qu'elle reste proportionnée de près
  comme de loin. Exemple appliqué : titre « Zone 1 » de `PlotTravail`.
- **Sélection** : le contour passe en `Selected`, épaisseur 4. Pas de deuxième contour.

## 6. Composants

Rayons : `Small` 8 (badge), `Medium` 12 (bouton, carte, slot), `Large` 18 (panneau),
`Pill` (pastille, barre, bouton rond). Espacements sur une grille de 4 (`XS` 4 → `XXL` 32),
marge d'écran 16, zone tactile minimale 44 × 44.

### Boutons (« chunky »)
Une **face** et une **lèvre** : la lèvre est une copie plus sombre décalée de `ButtonLip`
(4 px) vers le bas, avec le même contour. Face : `UIGradient` vertical **léger** (pas de reflet).

| Type | Face (haut → bas) | Lèvre | Texte |
| --- | --- | --- | --- |
| Principal | `GoldLight` → `GoldDeep` | brun doré foncé | `TextLight` + contour |
| Secondaire | `WoodLight` → `Wood` | `WoodDark` | `TextLight` + contour |
| Danger / fermer | `RoyalRed` (rond, « X ») | — | `TextLight` + contour |
| Désactivé | `Disabled` → `StoneGrey` | gris foncé | contenu à 0,45 |

États : **normal** ; **hover** = scale 1,04 + voile clair ; **pressed** = la face descend sur la
lèvre (lèvre masquée) et scale 0,94 ; **disabled** = gris pierre, aucun retour ; **selected** =
contour `Selected` 4 px. **Un seul bouton principal par écran.**

### Panneaux et fenêtres
- Fond `WoodDeep` à `Panel`, contour `Thick`, rayon `Large`, ombre `Shadow` (décalée, sans flou).
- Titre dans un **bandeau en bois** (`Wood`, opaque, contour `Thick`) à cheval sur le bord haut.
- Bouton fermer : rond `RoyalRed` à cheval sur le coin haut droit.
- Fenêtre modale : voile `Ink` à `Overlay` derrière. Aucune fenêtre plein écran opaque.

### Onglets
Pastilles `Medium` : actif `Gold` opaque, inactif `WoodDeep` à `PanelStrong`. Texte `Label`.

### Cartes de héros, slots, inventaire, récompenses
- Carte `Cream` à `PanelStrong`, contour `Regular`, rayon `Medium`.
- **Grande zone d'illustration** (≥ 60 % de la hauteur) en `Sand` semi-transparent : portrait
  (ViewportFrame) ou icône. Nom court dessous, en `Heading` ou `Label`.
- **Badge d'état** à cheval sur le bord haut : `Disponible` (`Success`), `Équipé` (`Gold`, et
  contour `Selected` sur la carte), `Nouveau` (`RoyalRed`, petit pop), `Verrouillé`
  (`StoneGrey`, carte à 0,4), `Max` (`Gold`).
- Slot vide : même cadre, fond `WoodDeep` à `PanelStrong`, sans contenu.
- **Items 2D** (équipements) : même carte, icône dans la zone d'illustration, cadre neutre (pas de
  couleur de rareté). Vitrine `Workspace.Bestiaire.Inventaire.Equipement` puis Sacoche : voir
  `docs/ITEMS.md`.
- **Ressources 2D** : même carte, icône dans la zone d'illustration, cadre neutre (aucune rareté).
  Catalogue, vitrine `Workspace.Bestiaire.Inventaire.Ressources` et production des icônes : voir
  `docs/RESOURCES.md`.

### Badges
Pastille `Pill`, couleur d'état, contour `Thin`, texte `Caption`. Un seul badge par carte.

### Infobulles
`Cream` à `Tooltip`, contour `Regular`, titre Fredoka `InkSoft`, texte Builder Sans `InkSoft`.

### Barres (PV, énergie, progression)
Fond `BarTrack` à `Track`, contour `Thin`, rayon `Pill`, remplissage opaque. PV au-dessus de
l'énergie ; PV `HealthLow` sous 30 % ; énergie pleine `EnergyFull` qui pulse. Ennemis :
`EnemyHealth`. Mini-boss : barre plus large. Progression (quêtes, niveau) : `Progress`.

### Monnaies
Capsule (`WoodDeep` à 0,45, contour `Regular`, mesures `Pack.Currency`) avec l'**icône PNG « _small »**
du pack (`CurrencyVisualConfig`) qui déborde à gauche et le montant en `Label`. Gain : le montant défile
(`Animation.Count`) et l'icône fait un pop. Icônes : `Small` (HUD, < 64 px), `Normal` (fenêtres),
`Glow` (gain, reveal). Monnaies 3D (`ReplicatedStorage.Assets.Currencies` : Gold, Gems, SummonTicket,
reproduites d'après « Monnaies 3D.html ») : feedback seulement (`UI/CurrencyFx` :
`SpawnCurrencyReward(kind, origin, destination?)`, `Preview(kind, parent)`), jamais une attribution.

### Récompenses
Cartes de récompense = cartes standard, la monnaie 3D du pack qui tourne au centre, quantité en bas à
droite (« ×3 »). Apparition en cascade (pop décalé de 0,05 s par carte). Reveal de quête (maquette
« Quêtes HUD ») : voile, rayons dorés, icônes `Glow` qui jaillissent avec le montant coloré,
« Récompense ! », « Toucher pour continuer » ; puis les monnaies 3D volent vers le HUD et une pastille
verte résume le gain.

### Quêtes
Suivi (HUD) = sous-panneau : icône Quête du pack, titre `Label`, barre `Progress`, compteur « 3/5 ».
Terminée : badge `Success` et bouton « Récupérer » qui ouvre le panneau Quêtes.
Panneau Quêtes (maquette « Quêtes HUD », mesures `Pack.Quest`) : voile, fenêtre `WoodDeep`, plaque
bois avec l'icône Quête et « Quêtes », X rouge royal ; une carte par quête (à récupérer : fond `SandGold`,
contour `Selected`, pastille « Terminée », barre `Success`, « Récupérer » doré qui pulse ; en cours :
barre `Progress`, bouton gris « En cours » ; récupérée : « ✓ Récupéré » vert, carte estompée), récompenses
en tuiles `Sand` avec l'icône `Small` et « ×n ».

## 7. Icônes

Une icône est **un petit objet du monde**, pas un pictogramme.

- **Même construction que les props** : formes chunky arrondies, couleurs de la palette
  matière, éclairage chaud venant d'en haut à gauche, légère ombre propre (volume).
- **Silhouette forte** : lisible en 32 px. L'objet occupe environ 80 % du cadre ; aucun détail
  sous 6 % de la taille. Une couleur dominante + un accent.
- **Contour `Ink`** cuit dans l'image (environ 6 % de la taille), comme le texte.
- Peut **déborder** légèrement de son cadre (pastille de monnaie, carte), pour l'effet chunky.
- Interdits : emoji (provisoires actuels du combat), icônes plates génériques, traits fins,
  style futuriste, photoréalisme.

**Fabrication** : modéliser l'objet en Studio avec les matières de la map (ou réduire un prop
existant : tonneau, pièce, parchemin, tour), le rendre de trois quarts sur fond transparent en
256 ou 512 px, ajouter le contour, puis l'importer en `ImageLabel`. Héros et monstres : portrait
3D en **ViewportFrame** (déjà le cas dans la main de préparation).

Icônes à produire en priorité : pièce d'or, gemme, ticket d'invocation, collection de héros,
quêtes (parchemin), royaume (tour), carte des zones, combat (épées croisées), paramètres
(roue en bois), cadenas, coche, ultime (éclat doré), icône de chaque classe de héros.

## 8. Animations

Courtes, douces, jamais agressives. Durées dans `UITheme.Animation`.

| Situation | Effet |
| --- | --- |
| Pression | scale 0,94 en 0,08 s, retour en 0,12 s |
| Survol | scale 1,04 en 0,12 s |
| Ouverture de fenêtre | 0,9 → 1 en 0,22 s (`Back Out`, petit dépassement) + fondu du voile |
| Fermeture | 1 → 0,9 + fondu en 0,12 s |
| Toast / annonce | glisse et pop en 0,25 s, reste 2 à 3 s, disparaît en fondu |
| Gain, badge « Nouveau » | pop 1 → 1,12 → 1 |
| Compteur | défile en 0,4 s |
| Mana pleine | pulse lent et continu de la barre |

Aucune animation au-delà de 0,4 s, pas de motion blur, un seul rebond au maximum.

**Guidage du tutoriel** (`UITheme.World.Guide`, `src/client/UI/WorldPulse.lua`). Une cible à utiliser
(portail, pancarte du stage, dalle) est « vivante », jamais signalée par une pancarte ni par un gros
contour permanent : léger voile doré qui respire (`FillFrom` → `FillTo`, contour seulement au sommet du
battement), lumière douce (`LightFrom` → `LightTo`), quelques étincelles ; battement plus marqué quand le
joueur est arrivé (`Near`). Le même langage s'applique à l'interface : raccourci de hotbar à prendre
(lueur dorée qui respire), pastille « F · Lancer » (contour doré), bouton « Récupérer » d'une quête
(contour doré qui pulse, bouton qui respire, petit rebond régulier ; au clic : pop puis désactivé).
Flèches du tutoriel (`docs/TUTORIAL_GUIDANCE.md`) : une flèche dorée chunky (icône 3D `Fleche`), au sol en
chaîne, au-dessus de la cible dans le monde, ou en flèche UI (`UI/GuidePointer`, une seule à la fois) qui
rebondit vers un élément et l'entoure d'une lueur dorée, avec une légende de 2 à 4 mots au plus.
Menu principal (`MenuView`) : icônes PNG du ZIP « Icones Menu » (`MenuIconConfig`), sans panneau, nom
Fredoka dessous ; sélectionné : pastille ronde WoodDeep à HUD et contour Selected sous l'icône ; attention :
variante PNG « ! » ; mis en avant : halo doré `World.Guide` qui respire (`Animation.Scale.Highlight`).

## 9. Tokens Roblox

Module `UITheme` (structure) :

```lua
UITheme = {
	Colors = { Ink, InkSoft, TextLight, TextMuted, Cream, Sand, …, Success, Error, Warning,
		Info, Disabled, Selected, Health, HealthLow, EnemyHealth, Energy, EnergyFull, Progress,
		BarTrack, CurrencyGold, CurrencyGems, CurrencyTickets },
	Transparency = { Panel = 0.25, PanelStrong = 0.12, HUD = 0.45, Overlay = 0.5,
		Tooltip = 0.04, Track = 0.35, Shadow = 0.75, Disabled = 0.45, Hover = 0.08 },
	Typography = { Display (Fredoka One), Body / BodyBold (Builder Sans), Size = {…},
		TextStroke = { Small = 2, Medium = 3, Large = 4 } },
	Radius = { Small, Medium, Large, Pill },
	Stroke = { Color, Thin = 2, Regular = 3, Thick = 4, WorldScaled = 0.08, LineJoin },
	Spacing = { XS = 4, S = 8, M = 12, L = 16, XL = 24, XXL = 32, ScreenMargin = 16, TouchTarget = 44 },
	Shadow = { Color, Transparency, Offset, ButtonLip = 4 },
	Animation = { Press, Hover, Open, Close, Fade, Toast, Count, Scale = {…} },
}
```

Utilisation : `local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)`, puis
`frame.BackgroundColor3 = UITheme.Colors.WoodDeep`. Une nouvelle couleur passe d'abord par ce
module et par ce document.

## 10. Exemples appliqués aux écrans existants

### Hotbar, sacoche et placement (`HeroBarController`, `ArenaPlacementController`)
Moins de fenêtres, plus d'interaction avec le monde : on **prend** un héros et on le **pose**.
- **Hotbar** : panneau `HUD` en bas, 10 raccourcis `Cream` semi-transparents, contour Ink,
  numéro de touche en `Caption`. Raccourci choisi : surélevé, contour `Selected` épais, pop.
  Héros posé sur l'arène : pastille `Selected`. Grisée pendant le combat.
- **Sacoche** : ouverte par le bouton Sac du menu, fenêtre **centrée** (voir § Sacoche ci-dessous).
- **Placement** : feedback dans le monde (états des cases en surbrillance claire, `Selected`
  doré, `Error` discret), petit aperçu du héros au curseur, pastille de statut `HUD`
  (« Archer en main · choisis une case 2/4 », boutons secondaires Retirer / Annuler).
- **Refus** : toast `Tooltip` crème en haut (« 4 héros maximum », « Arène occupée par … »).

### Combat (`ArenaPlacementController`, `CombatViewController`)
- Les informations des unités restent **dans le monde** : barres PV/énergie (§ 6 ; héros : PV
  8 px puis énergie (barre d'ultime) 8 px, séparées de 4 px pour que les contours ne se chevauchent pas), icône de
  classe au-dessus des barres, chiffres de dégâts Fredoka contourés : coup de base `Heading`
  (contour `Medium`), ultime `Title` doré suivi de « ! » (contour `Large`, rebond `Pop`).
  Ultimes automatiques : éclat doré sur `UltimateUsed`, aucun bouton ; sur le héros qui le lance,
  annonce « ULTIME ! » (`Title`, `GoldLight`, contour `Large`, rebond `Pop`), colonne de lumière
  dorée et onde au sol (`UltimateEffectController.Announce`).
- **Barre basse légère** : une pastille `HUD` centrée en bas, avec « Vague 1/1 », x1/x2 (onglets,
  actif doré) et un bouton rond « X » pour quitter. Pas de portraits permanents ni de doublon
  des PV.
- **Annonces** (vague, mini-boss) : texte `Title` contouré, sans fond, pop puis fondu.
- **Victoire / Défaite** : texte `Hero` (Victoire en `Gold`, Défaite en `Error`, contour 4),
  récompenses en cartes sous le titre (fournies par RewardService, #9), bouton principal « Continuer ».
  Voile `Overlay`, jamais d'écran noir.

### Panneaux du monde
- Titres des zones (`AffichageZone`, `EtiquetteZone`) : Fredoka One, contour `Ink` en
  `ScaledSize` (déjà appliqué à « Zone 1 » de `PlotTravail`). Les panneaux Zone 2 à 6
  (`Workspace.PlotsZones`) sont à aligner. Les bordures dorées de cadre peuvent rester : ce sont
  des éléments du décor, pas des contours UI.

## 11. Contrôle avant de livrer une interface

1. Capture réelle en Studio **par-dessus le monde** (fond clair et fond sombre).
2. Le monde se voit derrière tous les panneaux, sauf les infobulles.
3. Tout texte se lit à 100 % sur les deux fonds ; aucun texte sous 14 px.
4. Contours `Ink`, coins arrondis, épaisseurs `Thin` / `Regular` / `Thick` uniquement.
5. Un seul bouton principal visible ; zones tactiles ≥ 44 px.
6. Aucune valeur de style en dur dans le Controller : tout vient de `UITheme`.
7. Pas d'emoji ni d'icône générique dans une version livrée.
8. Écran nouveau ou modifié : sa capture de référence est ajoutée ou remplacée dans
   `docs/references/ui/ecrans/` dans la même PR, et l'inventaire mis à jour
   (`docs/references/ui/README.md`, contrôle `tools/test-ui-captures.ps1`).

## 12. Implémentation : UIKit (issue #19)

Les composants de ce document existent en code, côté client, dans un seul module :
`src/client/UI/UIKit.lua` (`StarterPlayerScripts.Client.UI.UIKit`). Un écran se construit avec
eux plutôt qu'à la main.

**Briques de base** (utilisées par la préparation, la hotbar et la sacoche) :

| Fonction | Composant (§) |
| --- | --- |
| `UIKit.text(parent, texte, taille, couleur ou { Color, Stroke, Align, Font })` | texte Fredoka contouré Ink, épaisseur selon la taille (§ 4) ; `Stroke = false` pour un texte sombre sur fond clair |
| `UIKit.button(parent, texte, "Primary"/"Secondary"/"Danger"/"Tab", taille, action)` | bouton chunky ; `setEnabled`, `setSelected` (§ 6) |
| `UIKit.panel(parent, transparence?, rayon?, contour?)` | panneau bois sombre contouré |
| `UIKit.badge(parent, texte, couleur)` | pastille d'état (largeur automatique) |
| `UIKit.pop(objet)` | pop de gain 1,12 → 1 (§ 8) |
| `UIKit.corner`, `UIKit.stroke`, `UIKit.textStroke` | coins, contour Ink, épaisseur de contour du texte |

**Écrans et fenêtres** :

| Fonction | Composant (§) |
| --- | --- |
| `UIKit.screen(nom, ordre?)` | ScreenGui + `UIScale` global (écran de référence 1080 px, entre 0,7 et 1,25) |
| `UIKit.window(parent, { Size, Title, OnClose })` | fenêtre : fond `WoodDeep`, ombre, bandeau de titre en bois, fermer ; renvoie la fenêtre et son contenu |
| `UIKit.roundButton(parent, { Text = "X", ... })` | bouton rond (fermer) |
| `UIKit.subPanel`, `UIKit.pill` | sous-panneau `PanelStrong`, pastille `HUD` |
| `UIKit.edgeBadge(parent, texte, couleur)` | badge d'état à cheval sur le bord haut d'une carte |
| `UIKit.bar(parent, { Color, Size })` | barre PV / énergie / progression (`Set(ratio, animate?)`) |
| `UIKit.card(parent, { Name, Model, Badge, Selected, Locked, Empty })` | carte standard avec portrait 3D |
| `UIKit.portrait(parent, modèle, enPied?)` | portrait 3D trois quarts (ViewportFrame) |
| `UIKit.overlay`, `UIKit.open`, `UIKit.close`, `UIKit.popIn`, `UIKit.announce` | voile, ouverture / fermeture, apparition, annonce (§ 8) |
| `UIKit.rays(parent, longueur)` | rayons dorés tournants (victoire, héros obtenu) |
| `UIKit.curtain(titre?, auMilieu?)` | transition entre deux scènes (voile Ink + titre) |

Une seule `UIScale` par élément : ouverture, pop et survol partagent la même (Roblox n'en
applique qu'une).

Icônes (§ 7) : `src/client/UI/Icons.lua`, petits objets 3D avec silhouette Ink, dans un
ViewportFrame. Classes de combat (`Archer` arc, `Epeiste` épée, `Barbare` hache, `Paladin`
bouclier, `Magicien` bâton, `Tireur` cible) : ce sont les `CombatProfile` de `HeroConfig`
(icône de classe au-dessus des unités). Héros dans la hotbar et la sacoche : **portrait 3D du vrai
modèle** (`UIKit.portrait` sur `Icons.heroModel(HeroId)`, modèles de `ReplicatedStorage.Assets.Heros`),
le monogramme provisoire (`PlaceholderIcon`) ne sert plus qu'en attendant la réplication.
Objets : `Parchemin`, `Or`, `Gemmes`, `Ticket`, `Combat`, `Cadenas`.

### Écrans

Branchés sur des états réels :

- barres de PV / mana et icône de classe au-dessus des unités (`CombatViewController`) ;
- écran Victoire / Défaite et récompenses (`RewardScreenController`), affiché sur `CombatEnded`
  par `ArenaPlacementController`.

Vues prêtes à brancher par les contrôleurs de #11 (`src/client/UI/Views`, présentation seule,
aucune règle de jeu) :

| Vue | API | Données attendues |
| --- | --- | --- |
| `QuestView` | `Show(quest, { OnClaim })`, `Hide()` | `QuestService:GetActiveQuest` : `{ Title, Progress, Target, Completed }` |
| `CurrencyView` | `Set(currencies, animate?)`, `Hide()` | `PlayerData.Currencies` : `{ Gold, Gems, SummonTickets }` |
| `ExpeditionView` | `Show(data, { OnLaunch, OnClose, Selected, OnSelect, Team, OnPrepare, Guide })`, `Hide()` | `{ Zone, Title, Subtitle?, Stages, EliteStages?, EliteUnlocked, Mode }`, entrées complètes d’ArenaService (voir `docs/ZONES.md` § Fenêtre Expédition) ; `Team = { Placed, Max, Heroes }` ; ouverte par la pancarte : `OnSelect` → `SelectStage`, `OnLaunch` → `Ready`, `OnPrepare` → dalles en évidence |
| `SummonView` | `Show(state, { OnSummon(quantity), OnRefresh, OnClose })`, `RevealBatch(batch, { OnContinue, OnAgain })`, `Reveal(hero, options)`, `Hide()` | bannière active, taux serveur, x1/x10/x100 et reveals selon le volume ; design figé #80 |
| `CollectionView` | `Show(heroes, { OnClose, OnSelect })`, `Hide()` | `{ { Name, Model, ClassId, Count, New, Equipped } }` depuis `Heroes` / la hotbar |

### Sacoche (maquette figée « Sacoche.dc.html »)

- **Source** : `Sacoche.dc.html` et `assets/sacoche/LISEZMOI.txt` (ZIP « Mid-century desk lamp (1) »). La vue `Views.SacocheView` la reproduit, avec une différence voulue : la maquette colle la fenêtre au menu (`winL` = 130 / 96 / 10 px), le jeu la **centre**.
- **Centrage** (`Shared.Sacoche.SacocheModel.frame`) :
  - AnchorPoint (0,5 ; 0,5) ;
  - X = milieu de l'écran ; Y = milieu de la zone libre entre le bas des monnaies (`Currency.*`, plaque « Sacoche » comprise) et le haut de la hotbar (`Hotbar.Bar`) ;
  - UIScale pour tenir dans cette zone (bornes `MinScale` / `MaxScale`) ;
  - sur téléphone, la fenêtre prend presque tout l'écran au-dessus de la hotbar.
  - Note : `AbsolutePosition` est mesurée sous la barre Roblox ; on ajoute `GuiService:GetGuiInset()`.
- **Ouverture** : scale 0,94 → 1,01 → 1 + fondu, au centre, sans glissement. Le menu principal se masque tant que la Sacoche est ouverte et revient à sa fermeture.
- **Écrans** : la Sacoche s'ouvre seulement si `ScreenState` est libre, et se ferme dès qu'un écran modal s'ouvre (Expédition, invocation, récompenses, Quêtes). `DisplayOrder` : HUD 2, menu 3, Sacoche 3, hotbar 4 (fantôme du drag visible au-dessus de la fenêtre).
- **Tokens** : `UITheme.Pack.Sacoche` (`Wide`, surcharges `Tablet`, `Phone` avec onglets verticaux et fiche compacte). Aucune couleur nouvelle : toutes celles de la maquette existent dans `UITheme.Colors`.
- **Icônes** : `SacocheVisualConfig` (onglets, 7 emplacements, raccourci, loupe, PV, ATK).
  - Réutilisées : icône Sac (`MenuIconConfig`), coche (`ExpeditionVisualConfig.Check`), items (`ItemConfig.Items[id].Icon`).
  - Les portraits du ZIP sont provisoires : on affiche les vrais modèles (`UIKit.portrait`).
- **Héros** :
  - cartes avec vrai modèle, Nv., touche du raccourci, « Nouveau » (exemplaire apparu pendant la session) et « Posé » ;
  - carte choisie : soulevée de 6 px, contour `Selected`, lueur et pop ;
  - fiche : nom, rareté, Nv., XP, PV et ATK (`HeroesChanged`, calcul serveur `combatStats`) ;
  - **une** action principale : **Placer**, ou **Retirer de l'arène** (`Remove`) pour un héros posé ;
  - action raccourci secondaire : les cases pulsent et « Choisis une case / Annuler » s'affiche, ce qui sert d'alternative au drag ;
  - le drag reste possible.
- **Équipement / Ressources** : #72 et #73 ne sont pas livrés, donc états vides honnêtes (poupée aux 7 emplacements vides, « Aucun équipement », « Tes ressources apparaîtront ici »), sans aucun faux inventaire.
- **Guidage** : `Bag.FirstHero` (première carte), `Bag.Place` (action principale, ou la première carte tant qu'aucun héros n'est choisi), `Hotbar.Guide`, `Menu.Bag`, drapeau « Bag ».

### Expédition (maquette figée « Expedition.dc.html »)

- **Source** : la maquette du ZIP « Mid-century desk lamp » (`Expedition.dc.html`, `assets/expedition/LISEZMOI.txt`). La vue la reproduit sans la redessiner.
- **Tokens** : `UITheme.Pack.Expedition`. Trois dispositions : `Wide` (PC, écran de référence 1600 × 900), `Tablet` (surcharges d'espacement, 1180 × 820) et `Phone` (844 × 390, ses propres tailles et des sections compactes). Le choix vient de `ExpeditionModel.device` : téléphone si la hauteur est < 520 ; tablette si la largeur est < 1300 ou le ratio < 1,5. Chaque disposition a son UIScale, borné.
- **Couleurs Élite** : `EliteTop/Bottom`, `EliteFaceTop/Bottom`, `EliteCardTop/Bottom`, `EliteLip`, `ElitePale`, avec l'accent `GoldLight`. L'Élite verrouillée est grise (`LockedTop/Bottom`).
- **Icônes** : `ExpeditionVisualConfig` (check, crown, lock, skull, swords, xp), seule source de leurs AssetIds.
- **Portraits** : les portraits du ZIP sont **provisoires**. On affiche les vrais modèles (`Icons.enemyModel`, `Icons.heroModel`) via `UIKit.portrait`.
- **Rail** : 5 cartes ; badges Disponible / Terminé / Verrouillé / Élite / Boss / Boss · Terminé. La carte choisie est soulevée (`Lift`), avec un contour `Selected` (`GoldLight` en Élite), une lueur et une pointe.
- **Boutons chunky** : face en dégradé, contour Ink 4 px, lèvre de 5 px, rayon 14.
  - `Préparer` respire quand aucun héros n'est posé.
  - `Lancer` respire et brille quand il est actif. Inactif, il est gris, avec un cadenas et la raison.
- **Logique** : `Shared.Expedition.ExpeditionModel` (pure, testée par `tools/test-expedition.ps1`).

Placement : quête en haut à gauche, monnaies en haut au centre (la liste des joueurs de Roblox
occupe le haut à droite), fenêtres centrées avec voile.

### Démonstrations Studio (sans serveur)

`Workspace.ApercuUI` = `Quete`, `Monnaies`, `Expedition`, `Invocation`, `Collection`,
`Transition` ou `Tout` (`UIPreviewController`) ; modifiable en cours de Play. Les héros de
démonstration sont les copies de `ReplicatedStorage.AtelierInvocation` (attributs `NomAffiche`,
`Classe`). Écran de fin : `Workspace.ApercuEcranRecompenses = true`.

## 13. États UI et branchement de la vertical slice (issue #11)

Le client ne reçoit que des **vues en lecture seule**, jamais `PlayerData`. L'interface affiche ces
états ; elle ne décide d'aucune récompense, quête, ticket, HeroId, stage ou résultat de combat.

| État | Source serveur | Contrôleur client | Vue |
| --- | --- | --- | --- |
| Quête active | `GetActiveQuest`, `QuestChanged`, `ClaimQuest` (QuestService) | `QuestController` | `QuestView` |
| Monnaies (Gold, Gems, SummonTickets) | `GetCurrencies` (PlayerStateService) | `CurrencyController` | `CurrencyView` |
| Héros / hotbar | `GetHeroes`, `HeroesChanged`, `HotbarAction` (HeroService) | `HeroBarController` (via `ArenaStore`) | hotbar, sacoche |
| Arène / stage | `GetArenaState`, `ArenaState`, `ArenaAction` (ArenaService) | `ArenaPlacementController` | pancarte, `ExpeditionView` |
| Combat, fin, récompenses | `CombatEvent` (CombatService, RewardService) | `ArenaPlacementController`, `CombatViewController` | HUD combat, `RewardScreenController` |
| Invocation | `GetSummonState`, `RequestSummon`, `HeroObtained` (HeroService) | `SummonController` | `SummonView`, `SummonReveal` |

**Monnaies.** `CurrencyController` relit `GetCurrencies`, sans jamais calculer de valeur :
- au join ;
- après une invocation (`HeroesChanged`, `HeroObtained`) ;
- au « Continuer » de l'écran de fin : les récompenses, déjà sauvegardées, défilent alors sur le HUD.

**Un écran modal à la fois** (`src/client/UI/ScreenState.lua`) : `Stage` (fenêtre des stages),
`Summon` (invocation, cinématique, carte) et `Reward` (écran de fin).
- Un écran ne s'ouvre pas par-dessus un autre, et les prompts (pancarte, portail, dalles) sont
  désactivés tant qu'un écran est ouvert.
- Un combat fini pendant une invocation affiche son écran de fin après la carte du héros.

### Ancienne checklist #11 → architecture actuelle

| Case historique | Réalisée par |
| --- | --- |
| ZoneController / lancement de stage | `ArenaPlacementController` : pancarte → E → `ExpeditionView` → Préparer l'équipe → Lancer (#49). Pas de ZoneController séparé. |
| CombatController | `ArenaPlacementController` (x1 / x2 / quitter, fin) et `CombatViewController` (barres, chiffres, ultimes). Pas de second contrôleur. |
| Brancher l'ultime | Ultime **automatique** (énergie pleine → `UltimateUsed`, animation, VFX, son). Pas de bouton. |
| Retour au Plot | L'arène **fait partie du plot** : après « Continuer », l'écran se ferme et le joueur reprend la main dans son plot. Aucune téléportation ; `PlotService:TeleportToPlot` reste prévu pour un futur vrai départ en expédition. |
| KingdomController | Pas d'action joueur : KingdomService (serveur) place les héros et l'état du royaume ; `KingdomChangeController` et `KingdomAmbientController` animent côté client. Pas de nouveau contrôleur. |
| Collection | La sacoche et la hotbar (`HeroBarController`) servent de collection ; le nouveau héros y apparaît via `HeroesChanged` après sa carte. `CollectionView` reste une vue de design non branchée. |
| QuestController, CurrencyController, SummonController | Créés (#11, #50), voir le tableau ci-dessus. |


## Invocation V2 — référence figée (#80)

Le ZIP final est archivé dans `docs/references/ui/invocation-v2` : `Invocation.dc.html`, `HeroCard.dc.html`, README et PNG d'invocation, monnaies et manifest SHA-256. Ce design est figé ; toute évolution visuelle doit partir de ces sources.

`HeroCard` emploie les dix cadres PNG par rang RarityConfig, les zones portrait/plaque fournies et les effets teintés par UITheme. Les identifiants sont centralisés dans `InvocationVisualConfig`. Le PNG bannière @2x importé est réduit par Roblox à 1024×580 : son SliceCenter est ajusté proportionnellement à `Rect(102,102,922,478)` ; SliceScale réduit les coins à la taille de la maquette.

`SummonView` compose la bannière unique et les commandes x1/x10/x100 ; `SummonLayout` porte la géométrie et la vue Taux ; `SummonReveal` porte les phases visuelles. UIKit fournit fenêtres, textes, boutons et portraits, ScreenState réserve le modal. La grille x100 a un scroll et deux onglets (regroupés/tous). Les vrais résultats et les taux viennent du serveur, les données factices du prototype ne sont jamais employées en gameplay. Voir `SUMMON.md` et `INVOCATION_V2_QA.md`.
