# Progression science / magie

_Généré par `tools/gen_docs.py` depuis `data/techs.json`._

Voies : **commune**, **science**, **magie**, **hybride**. Chaque peuple a une orientation (−1 magie … +1 science) issue de sa divinité, puis infléchie par ses découvertes. Une époque est atteinte avec 2 découvertes de cette époque (1 pour l'âge astral).

## 0. Âge tribal

| Découverte | Voie | Coût | Prérequis | Conditions | Effets |
|---|---|---|---|---|---|
| Maîtrise du feu | commune | 15 | — | — | food_mult +0.1, cold_shelter +0.15 |
| Outils de pierre | commune | 20 | — | ressources : pierre | craft +0.1 |
| Chasse organisée | commune | 20 | Outils de pierre | ressources : gibier | food_mult +0.1, military +0.1 |
| Rites et offrandes | commune | 25 | Maîtrise du feu | — | fervor +0.05 ; bâtiments : autel |

## 1. Âge des lames et des runes

| Découverte | Voie | Coût | Prérequis | Conditions | Effets |
|---|---|---|---|---|---|
| Agriculture | commune | 60 | Outils de pierre | fertilité ≥ 0.35 | capacity_mult +0.35 ; culture : Agriculteurs |
| Poterie et greniers | commune | 50 | Maîtrise du feu | — | storage +0.5 ; bâtiments : grenier |
| Maniement des armes | commune | 55 | Chasse organisée | — | military +0.2, sword_mastery_rate +0.5 |
| Bronze | science | 80 | Outils de pierre, Maîtrise du feu | ressources : minerai | craft +0.15, military +0.15 |
| Runes primordiales | magie | 80 | Rites et offrandes | porteurs Magie ≥ 4 % | magic_mastery_rate +0.5, fervor +0.03 |
| Herboristerie | hybride | 60 | Agriculture | ressources : bois | disease +0.15 ; culture : Guérisseurs |
| Pirogues et filets | commune | 50 | Outils de pierre | accès à la mer | fish_mult +0.5 ; culture : Pêcheurs |

## 2. Âge des royaumes

| Découverte | Voie | Coût | Prérequis | Conditions | Effets |
|---|---|---|---|---|---|
| Écriture | commune | 140 | Agriculture, Rites et offrandes | population ≥ 150 | research_mult +0.2 ; culture : Tradition écrite |
| Métallurgie du fer | science | 180 | Bronze | ressources : minerai; stabilité ≥ 0.4 | military +0.25, craft +0.15 |
| Fortifications | commune | 160 | Maniement des armes, Outils de pierre | ressources : pierre | defense +0.4, stability +0.05 ; bâtiments : remparts |
| Arcanes | magie | 180 | Runes primordiales | ressources : cristaux de mana; porteurs Magie ≥ 6 % | magic_mastery_rate +0.8, research_mult +0.1 |
| Clergé | commune | 150 | Rites et offrandes, Écriture | population ≥ 200 | fervor +0.1, stability +0.05 ; bâtiments : temple |
| Ordres de lames | commune | 170 | Maniement des armes, Métallurgie du fer | porteurs Épée ≥ 5 % | military +0.3, sword_mastery_rate +0.8 |
| Alchimie | hybride | 200 | Herboristerie, Runes primordiales | ressources : cristaux de mana | disease +0.15, research_mult +0.1 ; culture : Alchimie |

## 3. Âge des arcanes et des engrenages

| Découverte | Voie | Coût | Prérequis | Conditions | Effets |
|---|---|---|---|---|---|
| Mécanique | science | 380 | Métallurgie du fer, Écriture | ressources : bois, minerai; stabilité ≥ 0.5 | craft +0.25, capacity_mult +0.2 ; culture : Méthode |
| Lames enchantées | hybride | 400 | Arcanes, Ordres de lames | porteurs Magie ≥ 5 %; porteurs Épée ≥ 5 % | military +0.4 |
| Astronomie | science | 360 | Écriture | population ≥ 400 | research_mult +0.25 ; culture : Astronomes |
| Golems | hybride | 450 | Arcanes, Mécanique | ressources : pierre, cristaux de mana | craft +0.3, capacity_mult +0.15 |

## 4. Âge de l'éther et de la vapeur

| Découverte | Voie | Coût | Prérequis | Conditions | Effets |
|---|---|---|---|---|---|
| Machine à vapeur | science | 800 | Mécanique, Astronomie | ressources : bois, minerai; stabilité ≥ 0.55; population ≥ 800 | capacity_mult +0.4, craft +0.3 |
| Cristaux d'éther | magie | 800 | Arcanes, Alchimie | ressources : cristaux de mana; stabilité ≥ 0.5; porteurs Magie ≥ 8 % | capacity_mult +0.35, magic_mastery_rate +1.0 |
| Moteurs éthériques | hybride | 1000 | Machine à vapeur, Cristaux d'éther | ressources : minerai, cristaux de mana | capacity_mult +0.3, research_mult +0.2 |
| Électricité | science | 950 | Machine à vapeur | ressources : minerai; stabilité ≥ 0.6 | research_mult +0.3 |

## 5. Âge astral

| Découverte | Voie | Coût | Prérequis | Conditions | Effets |
|---|---|---|---|---|---|
| Fusion stellaire | science | 2200 | Électricité | stabilité ≥ 0.7; population ≥ 2000 | capacity_mult +0.6 |
| Portails astraux | magie | 2200 | Cristaux d'éther | stabilité ≥ 0.7; population ≥ 1500; porteurs Magie ≥ 10 % | capacity_mult +0.5, fervor +0.05 |
| Cités célestes | hybride | 2600 | Moteurs éthériques, Électricité | stabilité ≥ 0.7; population ≥ 2500 | capacity_mult +0.7 |

## Visuels par époque (jalon 1)

0 tentes coniques · 1 huttes cubiques · 2 maisons à pignon · 3 tours · 4 flèches lumineuses · 5 cristaux/spires astrales.
Prévu : variantes science (métal clair) / magie (cristaux violets) / hybride, routes, ports et véhicules.
