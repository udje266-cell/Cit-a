# Direction artistique

Référence d'intention : la lisibilité des paysages de *Godus*, en **low poly stylisé à facettes franches** :
un monde sculpté, légèrement anguleux, chaleureux et lisible, à la géométrie volontaire (révision v4).

**Règle des facettes** : les facettes sont révélées par l'éclairage et l'orientation des surfaces (normale par
face), jamais par une couleur différente par triangle. Chaque volume ou région garde une couleur unie ou un
dégradé continu par sommet ; l'eau reste lisse pour contraster avec les terres. Le monde doit sembler **composé et habité** : de
grandes formes lisibles, peu de couleurs, des détails à leur place.

## 1. Formes du terrain
| Principe | Mise en œuvre (`game/planet_view.gd`) |
|---|---|
| Surface continue, sans plaques ni fissures | Sommets partagés sur toute la planète (clé coin / arête / intérieur) : chaque sommet est calculé une fois. |
| Grandes formes arrondies | Hauteur des cellules interpolée, bruit de grande échelle, puis **deux passes de lissage** sur le graphe des sommets. |
| Terrasses qui épousent la courbure | `terrace()` quantifie la hauteur radiale : plateaux plats, contremarches courtes (55–95 % de chaque palier). Basses terres étirées pour multiplier les paliers dans les plaines. Une passe de lissage après les terrasses arrondit les contours. |
| Falaises épaisses | Contremarches et rives raides colorées en terre/roche chaude selon la pente. Le relief est exagéré (×0,11) pour que les ruptures se lisent. |
| Plaines calmes pour les villages | Le terrain est **aplani** sous chaque village (plateau jusqu'à 1,8 R, raccord jusqu'à 2,3 R) au niveau de terrasse de son centre. |
| Côtes sinueuses, plages propres | La côte naît de l'intersection du terrain lissé avec la sphère de mer ; le sable couvre la terre basse au contact de l'eau. |
| Grands plans légèrement anguleux | La terre est dessinée sur une grille 2× plus large que celle des hauteurs (`FACET = 2`) avec une **normale par face** : grandes facettes, couleurs continues par sommet (pas de mosaïque). La grille de simulation n'apparaît qu'en mode « Grille (consultation) ». |
| Arêtes franches, sommets marqués | Lissage réduit (une passe légère), crêtes en `ridge³` plus hautes. |

## 2. Palette limitée
| Rôle | Couleur (sRGB) |
|---|---|
| Plaines | vert doux `#91A15E` (0,57 0,63 0,37) |
| Forêts (sol) | vert profond `#5C804A` · jungle `#4D7545` · taïga `#668C69` |
| Savane / désert | ocre `#B8AD73` · sable clair `#E6CF99` |
| Sable des plages | crème `#EBD9A8` |
| Contremarches, falaises | terre/roche chaude `#A38C73` |
| Roches | gris chaud `#877F75` / `#736B63` |
| Neige | blanc bleuté `#E8F0FC` |
| Eau | turquoise côtier `#5CABAD` → bleu moyen `#33739A` → bleu profond `#214570` |

Les changements de couleur ne viennent que du **biome** (aplats aux transitions douces, poids des cellules à la
puissance 4), de la **pente**, de l'**altitude** (neige selon la température), de la **profondeur** et de
l'**aménagement** (place, abords, champs). Une modulation très lente (±4 %, bruit de basse fréquence) évite les
aplats morts, sans jamais varier d'un triangle à l'autre.

## 3. Végétation
- Tous les volumes sont **à facettes** (`facet_prism`, `facet_blob` : faces planes, couleur unie par volume).
- **Feuillus** : tronc prismatique, canopée de 2 polyèdres irréguliers à grandes facettes (2 variantes) ; **conifères** : 3 cônes
  étagés ou 1 cône élancé ; **conifère enneigé** ; **palmier** ; **acacia** à couronne plate ; **buisson** ;
  **rochers** polyédriques irréguliers ; **cactus**.
- Composition : un masque de bruit (`_noise_forest`) crée des **forêts denses** (40 essais par triangle en biome
  forestier), des **bosquets** en prairie et des **clairières** là où le masque est bas. Pas d'arbre sur les
  contremarches, les plages, ni dans le plateau des villages.
- Taille : 0,015–0,021 (présence nette au zoom régional) ; 70 % des instances à distance moyenne, toutes de près.

## 4. Architecture (famille par espèce, `game/world_art.gd`)
| Bâtiment | Condition dans la simulation | Volume |
|---|---|---|
| Habitation | toujours ; nombre ∝ √population | forme propre à l'espèce (ronde, pierre, pilotis, adobe, dôme, chaumière) |
| Bâtiment de production | Outils de pierre, Poterie ou Agriculture | grenier rond + atelier à pignon |
| Lieu de culte | Rites ou Clergé | socle, colonnes, toit doré ; clocher à partir de l'époque 2 |
| Bâtiment collectif | population > 40 ou organisation ≥ chefferie | grande halle, porche |
| Champs | Agriculture (sinon jardins au-delà de 30 habitants) | parcelles à sillons |
| Palissade / muraille | Fortifications, ou époque ≥ 1 et > 200 habitants | segments en anneau, ouverts sur les accès |

Matériaux partagés par toute la famille d'une espèce : murs, toits, boiseries. La **couleur du peuple** est
réservée au bandeau des murs, au porche et à la bannière (emblème aux couleurs du dieu). Le village s'organise
autour d'une **place** ; les portes font face à la place ; chaque maison a ses **abords de terre battue** ;
la production est en périphérie, les champs au-delà.

## 5. Lumière et présentation
- Soleil chaud (0,95, `#FFF2DB`) lié à la caméra, incidence rasante (≈ 35–55°) pour révéler les volumes.
- Ambiance ciel bleutée modérée (0,55), tonemap filmique, exposition 1,0 : pas de blancs brûlés.
- Matériaux mats (rugosité 1, spéculaire 0,15) ; eau légèrement satinée (rugosité 0,45).
- Ombres portées douces (2 cascades, flou 1,6), coupées de loin ; les arbres ne projettent d'ombre que de près.
- Halo atmosphérique en un passage additif, fond sombre uni.
- Caméra : de loin, vue centrée ; en se rapprochant, elle s'incline vers l'horizon et vise la surface ; un cap
  (`rig.heading`) permet de choisir l'angle de la vue régionale.

## 6. Limites actuelles et pistes
- Les contremarches suivent encore la résolution du maillage (≈ 0,0125) : contours un peu crénelés sur les
  grandes falaises. Pistes : subdivision adaptative près des contremarches, ou parois verticales générées le long
  des courbes de niveau.
- Coût : voir BUILD.md. La construction initiale (≈ 3,4 s sur PC) doit être répartie sur plusieurs fils
  (`WorkerThreadPool`) avant la diffusion sur mobile.
