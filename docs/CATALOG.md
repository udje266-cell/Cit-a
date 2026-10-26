# Catalogue des espèces et des traits

_Généré par `tools/gen_docs.py` depuis `data/`. Ne pas éditer à la main._

## Espèces

| Espèce | Longévité | Génération | Croissance | Magie | Milieux favoris | Description |
|---|---|---|---|---|---|---|
| Sylvains | 220 ans | 45 ans | 1.2 %/an | ×1.4 | Forêt tempérée, Jungle, Taïga | Peuple sylvestre à la peau d'écorce. Longévité élevée, reproduction lente, forte affinité magique. |
| Terragnes | 140 ans | 30 ans | 1.8 %/an | ×0.6 | Montagne, Prairie, Taïga | Bâtisseurs trapus nés de la roche. Robustes et habiles, peu enclins à la magie. |
| Ondins | 90 ans | 22 ans | 2.4 %/an | ×1.0 | Jungle, Prairie, Forêt tempérée | Amphibiens des rivages, pêcheurs et navigateurs, sensibles à la sécheresse. |
| Cendrés | 80 ans | 20 ans | 2.2 %/an | ×1.2 | Désert, Savane, Prairie | Nés des braises du désert, fougueux, résistants à la chaleur, d'une magie ardente. |
| Givrins | 160 ans | 35 ans | 1.4 %/an | ×1.1 | Toundra, Taïga, Montagne | Peuple des glaces au sang lent. Endurants, patients, méditatifs. |
| Vivaces | 45 ans | 14 ans | 3.2 %/an | ×0.8 | Prairie, Savane, Forêt tempérée | Petits êtres curieux des plaines, à vie courte et reproduction rapide, très inventifs. |

## Traits (104)

Coût = points de création des fondateurs (négatif = rend des points). Héréditaire : transmis et soumis à la sélection ; acquis : culture.
Les affinités Magie/Épée **ne sont pas des traits** (voir RULES.md §1).

### Constitution et apparence

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Grande taille | héréditaire | 2 | 0.6 | str +0.15, food -0.08 | Petite taille | Plus forts, mais mangent davantage. |
| Petite taille | héréditaire | 1 | 0.6 | str -0.10, food +0.10, fert +0.05 | Grande taille | Frugaux et prolifiques, moins robustes. |
| Pelage épais | héréditaire | 2 | 0.5 | cold +0.30, heat -0.20 | Peau fine | Protège du froid, accable sous la chaleur. |
| Peau fine | héréditaire | 1 | 0.5 | heat +0.20, cold -0.15 | Pelage épais, Écailles | Évacue la chaleur, craint le gel. |
| Écailles | héréditaire | 2 | 0.35 | heat +0.15, disease +0.10, aqua +0.10, cold -0.10 | Peau fine, Pelage épais | Carapace contre soleil et parasites. |
| Doigts palmés | héréditaire | 2 | 0.4 | aqua +0.30, craft -0.05 | — | Excellents nageurs et pêcheurs, gestes moins précis. |
| Vision nocturne | héréditaire | 2 | 0.4 | forest +0.15, food +0.05 | — | Chasse et cueillette en sous-bois sombres. |
| Poumons larges | héréditaire | 2 | 0.4 | mount +0.30, end +0.05 | — | Respirent sans peine en altitude. |

### Force, endurance et résistance

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Musculeux | héréditaire | 2 | 0.5 | str +0.20, food -0.05 | Frêle | Travaux de force et combat. |
| Endurant | héréditaire | 2 | 0.5 | end +0.20 | — | Supportent mieux disettes et longues marches. |
| Cicatrisation rapide | héréditaire | 3 | 0.35 | disease +0.10, end +0.10, lon +0.05 | — | Survivent mieux aux blessures. |
| Immunité forte | héréditaire | 3 | 0.4 | disease +0.30 | Sang fragile | Résistent aux épidémies des villes denses. |
| Métabolisme lent | héréditaire | 2 | 0.4 | food +0.20, str -0.05, cur -0.05 | Métabolisme vif | Mangent peu, agissent plus lentement. |
| Métabolisme vif | héréditaire | 2 | 0.4 | str +0.10, cur +0.10, food -0.15 | Métabolisme lent | Énergiques mais gourmands. |
| Os denses | héréditaire | 2 | 0.4 | str +0.10, end +0.10, aqua -0.15 | — | Solides, mais coulent comme des pierres. |

### Intelligence et curiosité

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Esprit vif | héréditaire | 3 | 0.5 | int +0.20 | Esprit lent | Apprennent plus vite. |
| Curieux | héréditaire | 2 | 0.5 | cur +0.25, coop -0.03 | Casanier | Explorent et cherchent : recherche et expansion accrues. |
| Mémoire prodigieuse | héréditaire | 3 | 0.25 | int +0.10, lon +0.10 | — | Le savoir se perd moins lors des crises. |
| Pensée abstraite | héréditaire | 3 | 0.3 | sci +0.15, mag +0.10, craft -0.05 | — | Théoriciens plutôt qu'artisans. |
| Observateur | héréditaire | 2 | 0.45 | sci +0.10, food +0.05 | — | Lisent les saisons et les plantes. |
| Esprit lent | héréditaire | -2 | 0.35 | int -0.20, coop +0.05 | Esprit vif | Apprentissage lent, mais grande docilité. |
| Rêveurs | héréditaire | 2 | 0.4 | mag +0.15, spi +0.10, craft -0.10 | — | Inspirés, peu pragmatiques. |

### Tempérament

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Calme | héréditaire | 2 | 0.5 | coop +0.10, agg -0.15 | Colérique | Stabilité sociale plus haute. |
| Colérique | héréditaire | -1 | 0.45 | agg +0.20, coop -0.10, str +0.05 | Calme | Querelles internes, guerriers redoutables. |
| Patient | héréditaire | 2 | 0.45 | craft +0.10, lon +0.05, cur -0.05 | Impulsif | Ouvrages durables, moins d'exploration. |
| Impulsif | héréditaire | 0 | 0.45 | cur +0.10, cou +0.10, coop -0.10 | Patient | Migrent et fondent vite, instables. |
| Optimiste | héréditaire | 2 | 0.5 | coop +0.05, fert +0.05, spi +0.05 | Mélancolique | Encaissent mieux les crises (moindre perte de stabilité). |
| Mélancolique | héréditaire | -1 | 0.4 | spi +0.10, fert -0.05, coop -0.05 | Optimiste | Plus pieux, moins féconds. |
| Tenace | héréditaire | 2 | 0.45 | end +0.10, cou +0.05 | — | Ne renoncent pas face aux difficultés. |

### Sociabilité et coopération

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Grégaire | héréditaire | 2 | 0.5 | soc +0.20, disease -0.05 | Solitaire | Villages plus grands avant de se diviser. |
| Solitaire | héréditaire | 0 | 0.4 | soc -0.20, cur +0.10, disease +0.05 | Grégaire | Essaiment vite en petits hameaux. |
| Altruiste | héréditaire | 3 | 0.45 | coop +0.20, agg -0.05 | Égoïste | Partagent la nourriture : famines moins meurtrières. |
| Égoïste | héréditaire | -1 | 0.4 | coop -0.20, craft +0.05 | Altruiste | Industrieux mais peu solidaires. |
| Empathique | héréditaire | 2 | 0.35 | coop +0.10, spi +0.05, agg -0.10 | — | Sensibles aux autres peuples et aux prédications. |
| Sens de la hiérarchie | héréditaire | 1 | 0.4 | coop +0.10, cur -0.05, str +0.05 | — | S'organisent vite en chefferies. |
| Xénophile | héréditaire | 2 | 0.35 | soc +0.10, cur +0.05, agg -0.10 | Xénophobe | Accueillent étrangers et idées nouvelles. |
| Xénophobe | héréditaire | -1 | 0.35 | agg +0.15, coop +0.05, cur -0.10 | Xénophile | Soudés entre eux, hostiles aux autres. |

### Courage et agressivité

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Brave | héréditaire | 2 | 0.5 | cou +0.20 | Craintif | Osent s'installer dans les milieux rudes. |
| Craintif | héréditaire | -1 | 0.45 | cou -0.20, spi +0.05, lon +0.05 | Brave, Téméraire | Restent près de chez eux, vivent vieux. |
| Belliqueux | héréditaire | 0 | 0.45 | agg +0.25, str +0.05, coop -0.05 | Pacifique | Cherchent le conflit avec les voisins. |
| Pacifique | héréditaire | 2 | 0.45 | agg -0.25, coop +0.05 | Belliqueux | Évitent les conflits. |
| Téméraire | héréditaire | 1 | 0.3 | cou +0.25, lon -0.10 | Craintif | Colonisent tout, meurent jeunes. |
| Protecteur | héréditaire | 2 | 0.4 | cou +0.10, coop +0.10 | — | Défendent les leurs, solidarité en crise. |
| Chasseur-né | héréditaire | 2 | 0.45 | food +0.10, agg +0.05, forest +0.05 | — | Tirent plus de gibier du territoire. |

### Spiritualité

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Pieux | héréditaire | 2 | 0.5 | spi +0.25 | Sceptique | Ferveur de base plus haute. |
| Sceptique | héréditaire | 0 | 0.45 | spi -0.25, sci +0.15 | Pieux, Mystique | Peu de foi, beaucoup de science. |
| Mystique | héréditaire | 3 | 0.3 | spi +0.20, mag +0.15, sci -0.05 | Sceptique | Perçoivent l'invisible ; voie magique favorisée. |
| Culte des ancêtres | acquis | 1 | 0.0 | spi +0.10, lon +0.05, cur -0.05 | — | La mémoire du culte décroît moitié moins vite. |
| Animisme | acquis | 1 | 0.0 | spi +0.10, forest +0.10 | — | Respect de la nature : bonus en forêt. |
| Sens des présages | héréditaire | 2 | 0.3 | spi +0.10, cur +0.05 | — | Les signes divins augmentent davantage la ferveur. |
| Fanatisme | acquis | 1 | 0.0 | spi +0.25, agg +0.15, cur -0.10 | — | Foi intense mais conversions plus difficiles dans les deux sens. |

### Sensibilité magique (distincte des affinités Magie/Épée)

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Canal éthéré | héréditaire | 3 | 0.35 | mag +0.25 | Insensibles à la magie | Manipulent naturellement l'éther. |
| Insensibles à la magie | héréditaire | 0 | 0.35 | mag -0.30, sci +0.10, disease +0.05 | Canal éthéré, Inclination ignée, Inclination aquatique, Inclination tellurique, Inclination vitale | Apprennent très mal la magie ; malédictions -50 %. |
| Inclination ignée | héréditaire | 2 | 0.3 | mag +0.10, heat +0.10, craft +0.05 | Insensibles à la magie, Inclination aquatique | Forge et magie ardente. |
| Inclination aquatique | héréditaire | 2 | 0.3 | mag +0.10, aqua +0.15 | Insensibles à la magie, Inclination ignée | Magie des marées et des pluies. |
| Inclination tellurique | héréditaire | 2 | 0.3 | mag +0.10, mount +0.10, craft +0.05 | Insensibles à la magie | Géomancie, mines facilitées. |
| Inclination vitale | héréditaire | 3 | 0.3 | mag +0.10, food +0.10, disease +0.05 | Insensibles à la magie | Cultures et guérison magiques. |
| Sang d'étoile | héréditaire | 4 | 0.1 | mag +0.30, spi +0.10, fert -0.10 | — | Puissance arcanique rare, fécondité réduite. |

### Aptitudes scientifiques

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Logiciens | héréditaire | 3 | 0.4 | sci +0.20, int +0.05 | — | Raisonnement rigoureux. |
| Bricoleurs | héréditaire | 2 | 0.45 | craft +0.15, sci +0.05 | — | Inventent des outils. |
| Sens du nombre | héréditaire | 2 | 0.35 | sci +0.15 | — | Mathématiques et astronomie. |
| Méthode | acquis | 1 | 0.0 | sci +0.10, lon +0.05 | — | Tradition d'expérimentation transmise. |
| Tradition écrite | acquis | 2 | 0.0 | int +0.05, lon +0.15 | — | Le savoir résiste aux crises (régressions moins probables). |
| Astronomes | acquis | 1 | 0.0 | sci +0.10, spi +0.05 | — | Observation du ciel. |
| Alchimie | acquis | 2 | 0.0 | sci +0.10, mag +0.10 | — | Pont entre science et magie : techniques hybrides moins chères. |

### Adaptation aux environnements

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Résistance au froid | héréditaire | 2 | 0.5 | cold +0.25 | Frileux | Survivent dans la toundra. |
| Résistance à la chaleur | héréditaire | 2 | 0.5 | heat +0.25 | Craint la chaleur | Supportent déserts et savanes. |
| Amphibie | héréditaire | 3 | 0.3 | aqua +0.30, desert -0.10 | — | Vivent entre terre et mer. |
| Montagnard | héréditaire | 2 | 0.45 | mount +0.25 | — | À l'aise en altitude. |
| Sylvestre | héréditaire | 2 | 0.45 | forest +0.25 | — | Prospèrent en forêt dense. |
| Nomade des sables | héréditaire | 2 | 0.4 | desert +0.25, end +0.05 | — | Trouvent de l'eau dans le désert. |
| Omnivore | héréditaire | 2 | 0.45 | food +0.15 | Régime strict | Mangent de tout. |
| Régime strict | héréditaire | -2 | 0.3 | food -0.20, spi +0.05 | Omnivore | Ne consomment qu'une partie des ressources. |

### Fertilité et longévité

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Fécond | héréditaire | 3 | 0.5 | fert +0.25, food -0.05 | Fertilité faible | Croissance démographique rapide. |
| Fertilité faible | héréditaire | -2 | 0.3 | fert -0.25, lon +0.05 | Fécond | Croissance lente. |
| Longévif | héréditaire | 3 | 0.35 | lon +0.25, fert -0.05 | Éphémère | Vivent longtemps : générations plus longues, savoir préservé. |
| Éphémère | héréditaire | 0 | 0.3 | lon -0.25, fert +0.15 | Longévif | Générations rapides : adaptation plus rapide. |
| Naissances gémellaires | héréditaire | 3 | 0.25 | fert +0.20, food -0.05 | — | Croissance accrue. |
| Maturité précoce | héréditaire | 2 | 0.35 | fert +0.10, int -0.05 | — | Adultes plus tôt, moins éduqués. |
| Vieillesse sage | héréditaire | 2 | 0.3 | lon +0.10, int +0.05, spi +0.05 | — | Les anciens transmettent. |

### Talents professionnels

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Agriculteurs | acquis | 2 | 0.0 | food +0.20 | — | Savoir agricole transmis. |
| Pêcheurs | acquis | 1 | 0.0 | aqua +0.15, food +0.05 | — | Tirent leur subsistance des eaux. |
| Bâtisseurs | acquis | 2 | 0.0 | craft +0.20 | — | Constructions plus rapides. |
| Marchands | acquis | 1 | 0.0 | soc +0.10, cur +0.05 | — | Échanges entre villages (partage des surplus). |
| Guérisseurs | acquis | 2 | 0.0 | disease +0.20 | — | Soignent maladies et blessures. |
| Mineurs | acquis | 1 | 0.0 | mount +0.10, craft +0.05 | — | Exploitent pierre et minerai. |
| Éleveurs | acquis | 1 | 0.0 | food +0.10, end +0.05 | — | Troupeaux : réserve de nourriture mobile. |
| Navigateurs | acquis | 2 | 0.0 | aqua +0.10, cur +0.10 | — | Peuvent coloniser au-delà de la mer (à venir : traversées). |

### Vulnérabilités

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Frêle | héréditaire | -2 | 0.4 | str -0.20, end -0.05 | Musculeux | Faibles physiquement. |
| Sang fragile | héréditaire | -2 | 0.35 | disease -0.30 | Immunité forte | Épidémies dévastatrices. |
| Frileux | héréditaire | -2 | 0.4 | cold -0.25 | Résistance au froid | Souffrent du froid. |
| Craint la chaleur | héréditaire | -2 | 0.4 | heat -0.25 | Résistance à la chaleur | Souffrent de la chaleur. |
| Casanier | héréditaire | -1 | 0.4 | cur -0.20, coop +0.05 | Curieux | Explorent peu. |
| Peur de l'eau | héréditaire | -2 | 0.35 | aqua -0.30 | Amphibie | Évitent côtes et lacs. |
| Allergie à l'éther | héréditaire | -2 | 0.3 | mag -0.15, disease -0.05 | Canal éthéré | La magie les rend malades. |
| Insomniaques | héréditaire | -1 | 0.3 | lon -0.10, craft +0.05, coop -0.05 | — | Travaillent plus, s'usent vite. |

### Caractéristiques rares

| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |
|---|---|---|---|---|---|---|
| Albinisme | héréditaire | 1 | 0.08 | heat -0.20, spi +0.15 | — | Considérés comme élus des dieux, craignent le soleil. |
| Bioluminescence | héréditaire | 3 | 0.06 | forest +0.15, soc +0.10, mag +0.05 | — | Communiquent par la lumière dans l'obscurité. |
| Télépathie latente | héréditaire | 5 | 0.05 | coop +0.20, mag +0.15, int +0.05 | — | Cohésion sociale exceptionnelle. |
| Gigantisme | héréditaire | 4 | 0.05 | str +0.35, food -0.25, fert -0.10 | Petite taille | Colosses affamés. |
| Ailes vestigiales | héréditaire | 4 | 0.04 | mount +0.20, cur +0.15, cou +0.05 | — | Planent entre les crêtes : exploration lointaine. |
| Peau chlorophyllienne | héréditaire | 5 | 0.04 | food +0.30, cold -0.10, forest +0.05 | — | Se nourrissent en partie de lumière. |
| Marque divine | héréditaire | 5 | 0.03 | spi +0.30, mag +0.10 | Sceptique | Ferveur exceptionnelle envers leur divinité. |
| Sang chimérique | héréditaire | 3 | 0.03 | cold +0.10, heat +0.10, aqua +0.10, fert -0.15 | — | S'adaptent partout, peu féconds. |

## États temporaires

| État | Effets | Description |
|---|---|---|
| Famine | fert -0.30, coop -0.10 | Manque de nourriture. |
| Épidémie | fert -0.20, str -0.10 | Maladie qui frappe la population. |
| Béni | fert +0.15, food +0.15, coop +0.10 | Bénédiction divine. |
| Protégé | disease +0.40, end +0.20 | Protection divine contre les fléaux. |
| Inspiré | int +0.20, cur +0.10 | Révélation divine récente. |
| Maudit | fert -0.20, food -0.15, coop -0.10 | Malédiction divine. |
| Traumatisé | coop -0.15, spi +0.10 | Catastrophe récente. |
| Saison douce | food +0.15, fert +0.05 | Climat apaisé par un dieu : protège des mauvaises années. |

## Statistiques (abréviations)

str force · end endurance · int intelligence · cur curiosité · soc sociabilité · coop coopération · agg agressivité · cou courage · spi spiritualité · mag aptitude à apprendre la magie · sci aptitude scientifique · fert fertilité · lon longévité · cold/heat/aqua/forest/mount/desert adaptation · disease résistance aux maladies · food efficacité alimentaire · craft artisanat.
