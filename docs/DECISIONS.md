# Registre des décisions — « Cit-a » (titre de travail)

Fichier de référence du projet. Chaque décision structurante y est consignée avec sa date et sa raison.
Toute décision qui la contredit doit d'abord modifier ce fichier.

| # | Date | Décision | Raison |
|---|------|----------|--------|
| D1 | 2026-10-26 | Moteur : **Godot 4.x, GDScript uniquement**. Projet créé pour **Godot 4.4** (syntaxe compatible 4.4 → 4.7). | Aucun projet existant fourni : pas de version à respecter. 4.4 est la plus ancienne version stable compatible avec toutes les API utilisées ; un projet 4.4 s'ouvre sans migration manuelle dans les versions 4.5+. |
| D2 | 2026-10-26 | Moteur de rendu : **Mobile** (Vulkan), repli **Compatibility** (OpenGL ES 3) pour les appareils anciens. | Android prioritaire, iOS ensuite (Metal via MoltenVK / renderer Mobile). |
| D3 | 2026-10-26 | Planète = **grille géodésique** (icosaèdre subdivisé). Chaque sommet est une **cellule** ; le rendu affiche le **polygone de Voronoï** de chaque cellule (hexagones + 12 pentagones). | Une seule représentation pour le terrain visible, les déplacements, les territoires et la sélection. Pas de distorsion aux pôles. |
| D4 | 2026-10-26 | Taille du monde jalon 1 : **niveau 4 = 2 562 cellules**. Cible version complète : niveau 5 = 10 242 cellules. | Niveau 4 suffisant pour valider la boucle ; niveau 5 à mesurer sur appareil avant adoption. |
| D5 | 2026-10-26 | **Simulation agrégée** : les peuples sont des *populations regroupées par établissement* avec des **fréquences de traits** (0–1), plus des **individus représentatifs** tirés à la demande pour l'affichage. Aucun habitant n'est un objet 3D ou un agent individuel. | Exigence §6 ; seul moyen d'avoir un grand monde sur téléphone. |
| D6 | 2026-10-26 | 1 *tick* de simulation = **1 an**. Vitesse ×1 = 1 tick/s ; ×2, ×4 ; pause. | Échelle adaptée à des civilisations qui évoluent sur des siècles. |
| D7 | 2026-10-26 | Code découpé en couches : `sim/` (données + règles, `RefCounted`, **aucun Node, aucun rendu**), `game/` (rendu, entrées, interface), `data/` (catalogues JSON), `tests/` (exécutables sans interface). La sauvegarde (`sim/save_system.gd`) ne dépend que de `sim/`. | Exigence §15 : systèmes testables sans lancer l'interface. |
| D8 | 2026-10-26 | Les scripts se référencent par `preload` et non par `class_name`. | Permet `godot --headless -s tests/run_tests.gd` sans import préalable du projet (cache de classes absent en CI). |
| D9 | 2026-10-26 | Aléatoire : **un seul `RandomNumberGenerator`** par monde, graine + état sauvegardés. Bruit de terrain : `FastNoiseLite` avec graine dérivée. | Génération et simulation reproductibles. |
| D10 | 2026-10-26 | Les modifications du joueur sur le terrain sont stockées comme **deltas par cellule** (`height_delta`) en plus de l'état complet. | Permet d'exporter un « monde initial » (graine + deltas) distinct d'un monde évolué. |
| D11 | 2026-10-26 | Foi : 5 grandeurs distinctes — *fidèles* (nombre), *ferveur* (0–1 par établissement), *production de foi* (par an), *énergie divine* (réserve plafonnée), *progression* (XP → niveau du dieu). | Exigence §9. |
| D12 | 2026-10-26 | Divinité affaiblie : régénération plancher de **0,3 énergie/an** (plafonnée à 12) + pouvoir **Murmure** (coût 3) + **mémoire du culte** dans les établissements (décroît lentement). | Pas de blocage si le peuple disparaît ou cesse de croire (§9). |
| D13 | 2026-10-26 | Divinités rivales : mêmes règles, mêmes coûts, même catalogue que le joueur ; décisions par **IA d'utilité** locale. Aucune ressource infinie. | §10. |
| D14 | 2026-10-26 | Progression hors-ligne : **1 an par 10 min réelles**, plafond **8 h** (configurable dans `data/config.json`). Calcul par lots de 10 ans par image pour ne pas bloquer. | §12. |
| D15 | 2026-10-26 | Protection horloge : si l'heure système est antérieure à la dernière sauvegarde → aucune progression, horodatage conservé ; `offline_consumed_until` empêche de réappliquer une même période. | §12 (pas de double récompense). |
| D16 | 2026-10-26 | Sauvegardes : JSON compressé (`FileAccess.open_compressed`, GZIP) dans `user://worlds/<id>/`, champ `version` + chaîne de migrations. Export `.cworld` (même format, `kind` = `seed` ou `evolved`). | §14. |
| D17 | 2026-10-26 | Partage en ligne : **non connecté** au jalon 1. Architecture proposée dans `ARCHITECTURE.md` (§ Partage). Aucun bouton de partage en ligne présenté comme fonctionnel. | §14. |
| D18 | 2026-10-26 | Jeu gratuit, sans publicité, sans achat intégré, sans service d'IA payant. Aucune dépendance réseau pour jouer. | §2. |

| D19 | 2026-10-26 | Cahier des charges v2 adopté (remplace la v1 reçue le même jour). Ajout de la **règle centrale Magie/Épée** ; ambiance de départ **épée et magie**, évolution possible vers un futur magie + technologie. | Mise à jour du commanditaire. |
| D20 | 2026-10-26 | Les affinités (none / magic / sword / both) sont un **état par habitant**, compté par établissement (`settlement.aff`), géré **uniquement** par `sim/affinity.gd`. Elles ne sont jamais dans le catalogue de traits ni dans la génétique. | Exclusivité divine garantie par construction et testable. |
| D21 | 2026-10-26 | Répartition 2/3 – 1/3 **exacte** par un compteur mondial de naissances (cycle de 3), pas par tirage aléatoire. | Aucun écart statistique sur la règle fondamentale ; reproductible. |
| D22 | 2026-10-26 | Naissance divine : le dieu décideur est celui de la religion des parents (tirage selon les parts religieuses). Aucun croyant → aucun dieu → 'none'. | Le dieu n'agit que par ses fidèles ; cohérent avec la foi comme ressource. |
| D23 | 2026-10-26 | Coûts d'attribution : Magie 0,6, Épée 0,6, les deux 2,5 ; tardif ×2 ; budget automatique annuel par dieu (4 par défaut) ; plafond annuel par règle. | Limiter l'automatisation par les ressources divines. |
| D24 | 2026-10-26 | Maîtrise (magie, épée) distincte de l'affinité, et **entraînement aux armes** (compétence ordinaire) distinct de l'affinité Épée. | Exigence « apprendre à manier une arme ≠ recevoir Épée ». |
| D25 | 2026-10-26 | Les traits « magiques » du catalogue sont renommés **Inclinations** (sensibilité à l'apprentissage magique) pour ne pas être confondus avec l'affinité Magie. | Clarté des règles. |
| D26 | 2026-10-26 | Orientation écran **paysage** (capteur). Interface construite en code, police 22 px de base, cibles tactiles ≥ 52 px. | Lisibilité d'une planète large sur téléphone. |


| D27 | 2026-10-26 | Référence de direction artistique : douceur et lisibilité de *Godus*, sur notre planète sphérique. Détails dans `docs/ART_DIRECTION.md`. | Demande du commanditaire (DA v3). |
| D28 | 2026-10-26 | **Habillage visuel séparé de la grille de simulation** : sommets partagés sur toute la planète, hauteur lissée, terrasses radiales, aplanissement des villages, normales lissées, couleurs par biome/pente/altitude/profondeur. La grille n'est visible qu'en mode « Grille ». Simulation et données inchangées. | Formes douces, aucune fissure, triangulation invisible. |
| D29 | 2026-10-26 | Subdivision visuelle **6 × 6 par triangle de simulation** (92 162 sommets). La subdivision 8 a été essayée : contours plus nets mais construction 4,8 s et modification locale 329 ms, rejetée. | Compromis qualité / coût mobile. |
| D30 | 2026-10-26 | Construction par 80 chunks (modifications locales), affichage par 20 groupes (appels de dessin). Végétation calculée par chunk, fusionnée par groupe. | Réactivité des pouvoirs de terrain et coût GPU. |
| D31 | 2026-10-26 | Niveaux de détail : **loin** (> 2,55) continents, reliefs, bannières agrandies, sans végétation ni ombres ; **régional** 70 % de la végétation, bâtiments ; **près** (< 1,6) toute la végétation et ses ombres, habitants représentatifs. | Le zoom révèle un monde plus riche. |
| D32 | 2026-10-26 | Villages = reflet des établissements : famille de 4 bâtiments (habitation, production, culte, collectif) conditionnée par les techniques et la population, place, abords, champs (Agriculture), murailles (Fortifications), bannière par espèce aux couleurs du peuple et du dieu. | Différencier les peuples, lier le visuel aux données. |
| D33 | 2026-10-26 | Éclairage doux : soleil chaud rasant lié à la caméra, ambiance bleutée 0,55, tonemap filmique, matériaux mats, ombres floues coupées de loin, halo additif. Pas de glow, SSAO ni brouillard volumétrique. | Couleurs préservées, volumes lisibles, coût mobile. |
| D34 | 2026-10-26 | Interface : zone de sécurité de l'écran, barre d'état à pastilles explicatives, sélecteur de vitesse avec état actif doré + libellé, rail de navigation (Pouvoirs, Foi, Peuples, Affinités, Journal, Cartes, Menu), tiroir de pouvoirs, icônes SVG intégrées (pas de glyphes Unicode). | Lisibilité et cohérence sur téléphone. |

## Hypothèses à confirmer par le commanditaire

- Titre définitif du jeu (« Cit-a » = nom du dépôt, utilisé provisoirement).
- Langue : interface en **français** au jalon 1 ; textes centralisés pour une traduction ultérieure.
