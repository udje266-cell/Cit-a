# Plan de développement et état des fonctionnalités

Légende :
- ✅ **vérifié** : exécuté et testé.
- 🟡 **codé** : présent dans les sources et validé syntaxiquement, mais **pas encore exécuté** (voir BUILD.md : Godot n'a pas pu tourner dans l'environnement de développement).
- ⬜ **prévu** : pas encore commencé.

> État honnête du jalon 1 : tout le code ci-dessous est 🟡. Aucune fonctionnalité n'est ✅ tant que
> `tests/run_tests.gd` n'a pas été lancé avec Godot et que le jeu n'a pas été ouvert sur un appareil.

## Jalon 0 — Références (✅ rédigés)
Vision, architecture, règles, catalogues (6 espèces, 104 traits, 29 découvertes, 18 pouvoirs, 12 accomplissements),
plan, registre des décisions.

## Jalon 1 — Première boucle jouable (🟡 codé)
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

## Jalon 2 — Vérification et réglages (⬜ prochaine étape)
1. Lancer `tests/run_tests.gd`, corriger les échecs, puis mesurer le temps d'un tick.
2. Ouvrir le jeu sur PC : parcours complet du menu à la reprise de partie.
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
