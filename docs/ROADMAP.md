# Plan de développement et état des fonctionnalités

Légende :
- ✅ **vérifié** : exécuté et testé.
- 🟡 **codé** : présent dans les sources et validé syntaxiquement, mais **pas encore exécuté** (voir BUILD.md : Godot n'a pas pu tourner dans l'environnement de développement).
- ⬜ **prévu** : pas encore commencé.

> État du jalon 1 : simulation ✅ (29 tests), flux d'interface ✅ (test de fumée + captures sur PC).
> Reste 🟡 : gestes tactiles et performances **sur Android** (pas d'appareil ni de SDK disponible).

## Jalon 0 — Références (✅ rédigés)
Vision, architecture, règles, catalogues (6 espèces, 104 traits, 29 découvertes, 18 pouvoirs, 12 accomplissements),
plan, registre des décisions.

## Jalon 1 — Première boucle jouable (✅ sur PC, 🟡 sur Android)
| # | Exigence | Implémentation |
|---|---|---|
| 1 | Petite planète sphérique | `sim/planet.gd` (2 562 cellules, graine), `game/planet_view.gd` |
| 2 | Personnaliser les fondateurs | `game/founder_screen.gd` (espèce, 2 fondateurs, traits à points, incompatibilités, don d'affinité facultatif) |
| 3 | Deux peuples rivaux et leurs dieux | `World.create_rivals` (fondateurs générés, personnalité, règles d'affinité) |
| 4 | Premiers villages | `sim/civ_system.gd` (croissance bornée, expansion, territoires, époques visibles) |
| 5 | Naissances 2/3 divines – 1/3 naturelles | `sim/affinity.gd` + 11 tests dédiés |
| 6 | Règle d'attribution + intervention manuelle | écran « Affinités » (règles, priorités, conditions, budget, stats, historique) + fiche de village (réservation, don immédiat) |
| 7 | Foi et quelques pouvoirs | `sim/faith_system.gd`, `sim/powers.gd` : 18 pouvoirs, prévisualisation zone et coût |
| 8 | Sauvegarder et reprendre | `sim/save_system.gd` : multi-mondes, sauvegarde automatique, version 1 et migration v0, export/import |

Déjà présents en version simple (🟡) : diplomatie minimale (contact, relations, guerre, paix, alliance), conversions,
sécessions, progression pendant l'absence avec résumé, tutoriel en 5 étapes, cartes thématiques (9).

## Jalon 1b — Direction artistique et interface (✅ PC en rendu logiciel, 🟡 Android)
Terrain doux en terrasses, palette limitée, végétation composée, famille architecturale, villages aménagés,
lumière douce, halo, 3 niveaux de détail, interface mobile refaite (voir ART_DIRECTION.md, D27–D34).
Prévu : contremarches plus nettes, effets visuels des pouvoirs, routes entre villages, ports, animation des
habitants, construction initiale multi-fils.

## Jalon 1c — Simulation compréhensible (✅ PC, 🟡 Android) — voir DEMO.md
Tutoriel en pause avec gestes vérifiés, catégories de pouvoirs lisibles, explications des pouvoirs indisponibles,
fiche de village complète, noms et frontières activables, origine des affinités, retour visuel des pouvoirs,
démonstration pilotée par de vrais événements d'entrée (47 vérifications).

## Jalon 2 — Vérification et réglages (⬜ prochaine étape)
1. ✅ Tests lancés et corrigés ; parcours complet vérifié sur PC.
2. Réduire le coût d'un tick (8,5 ms sur PC, cible ≤ 4 ms sur mobile) et la construction visuelle initiale (3,4 s).
3. Compiler l'APK et tester sur un Android milieu de gamme : gestes, lisibilité, IPS, mémoire.
4. Équilibrage : rythme d'apparition des villages, revenus de foi, coûts des pouvoirs et des affinités.
5. Enregistrer les mesures dans ARCHITECTURE.md (cibles initiales → mesurées).

## Jalon 3 — Hérédité avancée et époques
- Lignées nommées, arbre d'origine du peuple, graphiques d'évolution des traits.
- Bâtiments par voie (science : métal ; magie : cristaux ; hybride), routes, ports, véhicules.
- Familles de pouvoirs encore peu fournies : climat saisonnier (saisons réelles), création d'espèces animales.
- Effets visuels propres à chaque pouvoir (particules low poly).

## Jalon 4 — Diplomatie et religions
- Négociation explicite (traités, tributs, échanges commerciaux de ressources).
- Fusions de peuples, royaumes multi-espèces, guerres de religion.
- Diplomatie du joueur avec les dieux rivaux (pactes proposés, non-agression).

## Jalon 5 — Monde vaste et performances
- Planète niveau 5 (10 242 cellules) si les mesures Android le permettent.
- LOD de simulation (régions calmes un tick sur deux), découpage du maillage par régions, mise à jour partielle.
- Budget mesuré : CPU par système, GPU, mémoire.

## Jalon 6 — Partage en ligne
- Service à choisir par le commanditaire (voir ARCHITECTURE.md § Partage). Client `online/share_client.gd`.
- Avant cela, seul l'export/import local de fichiers `.cworld` existe.

## Jalon 7 — iOS
- Export iOS (macOS + Xcode), zones sûres, tests sur iPhone.
