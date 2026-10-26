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

## Vérifications réalisées dans cette version (0.1.0)
| Vérification | Résultat |
|---|---|
| Analyse syntaxique de tous les scripts (`gdparse` de gdtoolkit 4) | ✅ 16/16 fichiers valides |
| Validité JSON et cohérence des catalogues (incompatibilités et prérequis existants, 104 traits) | ✅ (script Python) |
| Exécution des tests Godot | ❌ **non réalisée** : le téléchargement et l'exécution du binaire Godot ont été refusés dans l'environnement de développement |
| Lancement du jeu, rendu, gestes tactiles | ❌ non réalisé (pas de Godot) |
| APK Android | ❌ non produit : Godot, les modèles d'export, le JDK et le SDK Android sont absents, ainsi que tout appareil ou émulateur |
| Mesures CPU / GPU / mémoire sur Android | ❌ non réalisées ; cibles proposées dans ARCHITECTURE.md |

Conséquence : il faut s'attendre à des erreurs d'exécution au premier lancement. L'analyse syntaxique ne vérifie ni
les types ni les noms d'API. Premier travail du jalon 2 : lancer les tests et les corriger.

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
- L'équilibrage n'a pas été joué.
