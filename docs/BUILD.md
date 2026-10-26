# Lancement, tests, compilation Android et vérifications

## Prérequis
- **Godot 4.4 ou plus récent** (version standard, pas .NET). Le projet utilise uniquement GDScript.
- Pour l'APK : modèles d'export Godot de la même version, **JDK 17**, **SDK Android** (platform-tools, build-tools
  34+, plateforme 34+), et un keystore de débogage.

## Lancer le jeu sur PC
```
godot --path .            # ouvre directement le jeu
godot -e --path .         # ouvre l'éditeur
```
Commandes à la souris : glisser = tourner, molette = zoom, clic = sélectionner.
Commandes tactiles : glisser = tourner, pincer = zoom, toucher = sélectionner, glisser en mode Pinceau = modeler.

## Lancer les tests sans interface
```
godot --headless --path . --import                       # première fois : importe le projet
godot --headless --path . -s tests/run_tests.gd          # code de sortie 0 = succès
godot --headless --path . -s tests/smoke_game.gd         # flux complet de l'interface
xvfb-run godot --path . --rendering-method gl_compatibility -s tests/art_showcase.gd -- <dossier>  # vitrine DA
xvfb-run godot --path . --rendering-method gl_compatibility -s tests/perf_view.gd                  # mesures rendu
xvfb-run godot --path . --rendering-method gl_compatibility -s tests/screenshot.gd -- <dossier>   # captures
```
29 tests couvrent : catalogues, déterminisme et structure de la planète, héritage, sélection, mutations,
incompatibilités, **répartition 2/3 – 1/3, naissances naturelles jamais doubles, distribution naturelle conforme,
absence d'attribution sans remplacement, attribution par règle (coût et explication), parents doublement dotés sans
transmission, génétique sans effet sur les affinités, interventions tardives, ordres manuels, budget, rechargement
sans nouveau tirage**, croissance bornée, pouvoirs (verrou, coût, effet réel), effets différés, conversions, retour
d'un dieu affaibli, sauvegarde aller-retour, fichiers, migration v0 → v1, export/import, absence (plafond, horloge
reculée, double application) et mesure de performance.

## Compiler un APK de test
1. Installer les modèles d'export : Éditeur → *Gérer les modèles d'export* → Télécharger.
2. Éditeur → Paramètres de l'éditeur → *Export → Android* : renseigner le chemin du SDK Android et le keystore de
   débogage (`keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 9999`).
3. Le préréglage `Android` est déjà défini dans `export_presets.cfg`. Il inclut `data/*.json` et exclut les tests
   et la documentation.
4. En ligne de commande :
```
godot --headless --path . --export-debug "Android" build/cit-a-debug.apk
adb install -r build/cit-a-debug.apk
```

## Vérifications réalisées (0.1.0, Godot 4.4.1 sur Linux)
| Vérification | Résultat |
|---|---|
| Compilation de tous les scripts (`--check-only`) | ✅ après correction de 10 erreurs de typage (`:=` sur des valeurs non typées, un type de conteneur) |
| `tests/run_tests.gd` | ✅ **29/29 tests, 343 assertions** (dont les 11 tests de la règle Magie/Épée) |
| Bugs trouvés par les tests et corrigés | les couples fondateurs ne se reproduisaient jamais (seuil de naissance à 2 habitants) ; un test d'explication fragile ; un test de capacité qui ne mesurait pas la durée du dépassement |
| `tests/smoke_game.gd` (flux complet du jeu : menu → fondateurs → 120 ans → pouvoirs → don d'affinité → 9 cartes → fiches → règles → export → sauvegarde → reprise) | ✅ aucune erreur |
| Rendu réel (Xvfb, moteur Compatibilité) : captures du menu, des fondateurs, de la planète, de la carte des peuples, de l'aperçu d'un pouvoir et des règles | ✅ ; corrigé : barres d'interface mal ancrées (HUD illisible, barre de pouvoirs invisible) |
| Mesures PC (1 cœur, sans GPU) | tick 8,5 ms/an avec 38 établissements à l'an 250 ; maillage 66 126 sommets reconstruit en 25–30 ms ; mémoire statique 21 Mo |
| Équilibre observé sur 2 ans × 3 peuples | 1 038 naissances ouvertes au divin et 519 naturelles (2:1 exact) ; ~38 établissements en 250 ans |
| APK Android | ❌ non produit : modèles d'export, JDK 17 et SDK Android absents |
| Gestes tactiles, IPS et mémoire sur appareil | ❌ non mesurés : aucun appareil ni émulateur |

Écart avec la cible : le tick (8,5 ms sur PC) dépasse déjà la cible mobile de 4 ms. Pistes pour le jalon 2 :
mettre en cache les statistiques par établissement (aujourd'hui recalculées plusieurs fois par tick) et calculer
les conversions seulement entre voisins proches.

## Vérifications de la refonte visuelle (0.2.0)
Environnement réellement testé : **Linux x86-64 (conteneur cloud, 4 cœurs), Godot 4.4.1, rendu Compatibilité
(OpenGL) en logiciel via Mesa llvmpipe sous Xvfb, 1280×720**. Aucun GPU, aucun téléphone, aucun émulateur :
les temps d'image ci-dessous sont ceux d'un rendu **logiciel** et ne préjugent pas d'un appareil Android.

| Vérification | Résultat |
|---|---|
| Tests de simulation | ✅ 29/29, 343 assertions (simulation inchangée) |
| Test de fumée (flux complet, 3 distances, 10 cartes, nouvelles fenêtres) | ✅ sans erreur |
| Vitrine de la région (baie, colline en terrasses, forêt, falaise, village), interface masquée | ✅ `tests/art_showcase.gd` : vues globale, régionale, rapprochée ×2 |
| Raccords du terrain | ✅ par construction (sommets uniques partagés) |
| Orientation des objets | ✅ verticale = normale de la sphère ; bâtiments tournés vers la place |
| Construction initiale du monde visuel | ≈ 3,4 s (une fois, au chargement) — **à réduire** (fils de calcul) |
| Modification locale du terrain | ≈ 160–180 ms |
| Primitives par image (ombres comprises) | loin 137 k · régional 345 k · près 443 k |
| Appels de dessin (interface 2D comprise) | loin 108 · régional 220 · près 232 |
| Sommets du terrain / mémoire | 92 162 ; mémoire statique 78 Mo ; vidéo 30 Mo |

À vérifier en priorité sur Android : temps d'image aux distances régionale et rapprochée. Leviers prévus si
nécessaire : densité forestière (`_build_chunk_props`), ombres des arbres, imposteurs pour les forêts lointaines,
construction initiale répartie sur plusieurs fils.

## Outils de l'environnement de développement (inspectés le 2026-10-26)
| Élément | État |
|---|---|
| Compétences Claude Code (gamedev-skills, game-designer, skill-creator, Blender, Scenario…) | installées dans `.claude/skills/` |
| Godot | absent ; installation refusée |
| Blender, MCP Blender | absents |
| Android SDK / adb / émulateur, Mobile MCP | absents |
| Context7 (`npx ctx7`) | non configuré |
| uv / uvx | présents (utilisés pour gdtoolkit) |

## Limites connues
- Effets visuels propres à chaque pouvoir non réalisés : surbrillance de la zone seulement.
- Bâtiments : une silhouette par époque, sans variante science / magie.
- Le maillage de la planète est reconstruit en entier à chaque modification (à mesurer, à découper par régions si
  besoin).
- Le partage en ligne n'est pas connecté ; seul l'export/import local de fichiers `.cworld` est fourni.
- L'import se limite au dossier d'export du jeu (pas de sélecteur de fichiers Android).
- L'équilibrage n'a pas été joué par un humain. La croissance est lente au début : environ 50 ans pour passer
  du couple fondateur à 10 habitants.
- Icône provisoire (`icon.svg`) inspirée de l'illustration fournie : l'image originale doit être ajoutée au dépôt
  (`icon.png`, 512×512 minimum) pour être utilisée comme icône Android.
