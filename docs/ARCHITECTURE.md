# Architecture technique

## Couches
```
data/       Catalogues JSON (espèces, traits, techniques, pouvoirs, configuration). Modifiables sans code.
sim/        Modèle + règles. RefCounted uniquement. Aucune dépendance au rendu ni à l'interface.
  catalog.gd        Chargement/validation des catalogues.
  planet.gd         Grille géodésique, génération du terrain, climat, biomes, ressources, édition.
  genetics.gd       Fréquences de traits, héritage, mutations, sélection, individus représentatifs.
  affinity.gd       Affinités Magie/Épée : naissances divines/naturelles, règles, ordres manuels, dons tardifs, historique.
  world.gd          État complet d'une partie + tick annuel + journal + (dé)sérialisation.
  civ_system.gd     Nourriture, croissance bornée, territoires, expansion, recherche, bâtiments, crises.
  faith_system.gd   Religions, ferveur, conversions, production de foi, énergie, progression des dieux.
  powers.gd         Catalogue de pouvoirs : déblocage, prévisualisation, coûts, effets immédiats et différés.
  rival_ai.gd       IA d'utilité des divinités rivales.
  save_system.gd    Fichiers, versions, migrations, export/import, progression hors-ligne.
game/       Rendu et interface (Nodes). Lit `sim/`, n'écrit que via des commandes (pouvoirs, création).
  main.gd           Orchestration : boucle de temps, sauvegarde auto, cycle de vie Android.
  planet_view.gd    Maillage Voronoï low poly, cartes thématiques, marqueurs (MultiMesh), prévisualisation.
  camera_rig.gd     Orbite, zoom, gestes tactiles (glisser, pincer, toucher), souris.
  ui.gd             HUD, barre de pouvoirs, fiches, journal, tutoriel.
  founder_screen.gd Création des fondateurs.
tests/      run_tests.gd : tests de la simulation sans interface (`godot --headless -s`).
tools/      gen_docs.py : régénère CATALOG.md, POWERS.md, PROGRESSION.md depuis data/.
online/     (prévu) client de partage — non implémenté.
```
Règle : `game/` peut lire `sim/` ; `sim/` n'importe jamais `game/`. La sauvegarde sérialise uniquement `sim/`.

## Modèle de données (résumé)
- **Planet** : tableaux parallèles indexés par cellule (`pos`, `height`, `height_delta`, `temperature`, `moisture`,
  `fertility`, `biome`, `resources{}`), `neighbors[]`, `owner[]` (id d'établissement ou -1).
- **People** : espèce, nom, couleur, divinité d'origine, connaissances, voie science↔magie, traits culturels acquis,
  historique (origines, transformations).
- **Settlement** : cellule, peuple, population (float), réserves, bâtiments, territoire, fréquences de traits,
  parts religieuses, ferveur, mémoire du culte, effets temporaires, stabilité.
- **Religion** : divinité, nom, peuple fondateur. Indépendante des peuples (D11).
- **Deity** : énergie, plafond, XP/niveau, accomplissements, pouvoirs débloqués, personnalité (IA).
- **Pending effects** : file d'effets différés (tick d'échéance, effet, zone, source).

## Ordonnancement et coûts
- Tick annuel découpé : chaque système traite tous les établissements (O(établissements)) ; la génétique ne tourne
  que tous les `generation_years` de l'espèce ; la recherche d'emplacement (BFS) est limitée à 5 sauts et à
  80 cellules visitées. Aucun A* global.
- Rendu : un seul `ArrayMesh` pour la planète (reconstruit uniquement quand le terrain ou la carte thématique change),
  un `MultiMeshInstance3D` par silhouette d'époque pour les établissements.
- LOD (prévu) : à grande distance, marqueurs agrégés et pas de bâtiments ; à courte distance, détails locaux.
  LOD de simulation (prévu) : régions sans joueur ni conflit simulées tous les 2 ticks.

## Cible de performance initiale (à vérifier sur appareil)
| Mesure | Cible jalon 1 | Méthode |
|---|---|---|
| Monde | 2 562 cellules, 3 peuples, ≤ 60 établissements | `data/config.json` |
| Tick de simulation | ≤ 4 ms sur appareil milieu de gamme (≈ Snapdragon 7-series) | `tests/run_tests.gd` (bench) + `Performance` en jeu |
| Rendu | 60 i/s, ≤ 60 k sommets planète, ≤ 30 appels de dessin | moniteur Godot sur appareil |
| Mémoire | ≤ 250 Mo | moniteur Godot |
| Reconstruction du maillage | ≤ 120 ms (événement ponctuel) | chronométrage `planet_view.gd` |

## Sauvegarde
`user://worlds/<id>/save.cworld` (JSON GZIP) + `meta.json` (nom, année, date). Écriture atomique : fichier `.tmp`
puis renommage. `version` actuelle = 1 ; `SaveSystem.MIGRATIONS` transforme une version n en n+1.

## Partage en ligne (architecture proposée, non connectée)
- Format d'échange = fichier `.cworld` exporté (déjà fonctionnel en local).
- Service minimal : stockage d'objets (ex. Supabase Storage / Cloudflare R2) + petite API (envoi, liste, code de
  partage à 6 caractères, signalement). Aucun compte obligatoire : jeton anonyme par installation.
- Client : `HTTPRequest` dans `online/share_client.gd`, entièrement optionnel ; si l'URL du service n'est pas
  configurée, l'interface n'affiche que l'export/import local.
- Modération : taille maximale, validation du schéma à l'import, noms filtrés.
- **Services nécessaires à fournir** : un hébergement de fichiers + une fonction serverless. Coût nul possible
  dans les quotas gratuits ; à décider par le commanditaire.

## Portage iOS
Aucune API spécifique Android dans `sim/`. Points d'attention : `NOTIFICATION_APPLICATION_PAUSED` (déjà géré pour
la sauvegarde), zones sûres (`DisplayServer.get_display_safe_area`), export iOS nécessite macOS + Xcode.
