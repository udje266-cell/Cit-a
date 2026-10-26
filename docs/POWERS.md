# Catalogue des pouvoirs

_Généré par `tools/gen_docs.py` depuis `data/powers.json`._

Tous les pouvoirs se prévisualisent (zone surlignée + coût + conséquences différées + avertissements) avant validation.

## Terrain, relief et océans

### Soulever la terre

- **Coût** : 4
- **Déblocage** : niveau divin 0
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : height 0.22
- **Conséquences différées** : aucune
- **Effet visuel** : `dust_up` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Recalcule température (altitude), humidité, biome et ressources des cellules touchées ; peut rendre une cellule inhabitable ou ouvrir un passage.
- Élève le relief. Peut faire émerger des îles.

### Creuser

- **Coût** : 4
- **Déblocage** : niveau divin 0
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : height -0.22
- **Conséquences différées** : aucune
- **Effet visuel** : `dust_down` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Une cellule habitée submergée perd sa population (les survivants migrent). Les côtes créées favorisent les pêcheurs.
- Abaisse le relief ; sous le niveau de la mer, crée des baies ou des lacs.

## Climat et saisons

### Pluie bienfaisante

- **Coût** : 6
- **Déblocage** : niveau divin 0
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : moisture 0.2
- **Conséquences différées** : fertility 0.08 après 2 ans
- **Effet visuel** : `rain` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Peut transformer désert en savane, savane en prairie ; la fertilité augmente 2 ans plus tard. Les fidèles témoins gagnent en ferveur.
- Humidifie durablement la région.

### Souffle chaud

- **Coût** : 6
- **Déblocage** : niveau divin 1
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : temperature 0.08
- **Conséquences différées** : aucune
- **Effet visuel** : `heat` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Fait fondre glaces et toundras ; la sélection naturelle favorisera peu à peu la résistance à la chaleur.
- Réchauffe la région.

### Souffle glacé

- **Coût** : 6
- **Déblocage** : niveau divin 1
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : temperature -0.08
- **Conséquences différées** : aucune
- **Effet visuel** : `frost` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Favorise à long terme les traits de résistance au froid ; réduit la fertilité des régions déjà froides.
- Refroidit la région.

### Saison douce

- **Coût** : 9
- **Déblocage** : niveau divin 2
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : status saison_douce (8 ans)
- **Conséquences différées** : aucune
- **Effet visuel** : `sun` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Contre les années climatiques défavorables.
- Apaise le climat local pendant 8 ans : récoltes meilleures, aucune perte due aux sécheresses ou aux hivers rudes.

## Végétation et fertilité

### Floraison

- **Coût** : 8
- **Déblocage** : niveau divin 1
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : fertility 0.15
- **Conséquences différées** : resource wood après 3 ans
- **Effet visuel** : `bloom` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Augmente la capacité d'accueil : la population grandit, puis la ressource bois apparaît.
- Rend les sols fertiles ; une forêt pousse quelques années plus tard.

### Source sacrée

- **Coût** : 12
- **Déblocage** : niveau divin 2
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : moisture 0.25, fervor 0.05
- **Conséquences différées** : fertility 0.1 après 1 ans
- **Effet visuel** : `spring` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Peut verdir un désert ; lieu de pèlerinage pour vos fidèles.
- Fait jaillir une source : la terre s'humidifie, puis devient plus fertile.

## Création de la vie

### Semer la vie

- **Coût** : 10
- **Déblocage** : niveau divin 1
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : resource game
- **Conséquences différées** : resource fish après 5 ans
- **Effet visuel** : `sparkles` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Nourriture accrue ; favorise les traits de chasseur.
- Crée du gibier, puis des poissons dans les eaux voisines.

### Grande migration

- **Coût** : 14
- **Déblocage** : niveau divin 3
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : resource game
- **Conséquences différées** : fertility 0.05 après 3 ans
- **Effet visuel** : `flock` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Nourriture accrue ; favorise les chasseurs.
- Des troupeaux s'installent dans la région, puis enrichissent les sols.

## Influence sur l'évolution

### Éveil adaptatif

- **Coût** : 14
- **Déblocage** : niveau divin 3
- **Portée** : cible établissement, rayon 0 saut(s)
- **Effets immédiats** : evolve 0.15
- **Conséquences différées** : aucune
- **Effet visuel** : `dna` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : N'agit que sur les traits héréditaires ; ne crée jamais d'affinité.
- Accélère fortement la sélection naturelle : l'équivalent de 4 générations de sélection par le milieu.

### Hybridation

- **Coût** : 22
- **Déblocage** : niveau divin 5
- **Portée** : cible établissement, rayon 0 saut(s)
- **Effets immédiats** : mutate 0.1
- **Conséquences différées** : aucune
- **Effet visuel** : `dna` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Le trait est tiré parmi les traits héréditaires absents, selon leur rareté ; jamais une affinité Magie/Épée.
- Fait apparaître un trait héréditaire nouveau (10 % de la population).

## Attribution des affinités

### Don d'affinité

- **Coût** : variable (coût d'attribution tardive × nombre)
- **Déblocage** : niveau divin 0
- **Portée** : cible établissement, rayon 0 saut(s)
- **Effets immédiats** : grant_affinity 5
- **Conséquences différées** : aucune
- **Effet visuel** : `halo` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Seule voie d'obtention tardive d'une affinité. Ne donne aucune maîtrise : elle s'acquiert ensuite par l'apprentissage.
- Confère Magie, Épée ou les deux à des habitants nés sans cette affinité. Coût = coût d'attribution × multiplicateur tardif, par personne.

## Guérison et protection

### Guérison

- **Coût** : 8
- **Déblocage** : niveau divin 1
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : cleanse ['epidemie', 'famine', 'maudit'], status protege (10 ans), fervor 0.08
- **Conséquences différées** : aucune
- **Effet visuel** : `heal` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Annule épidémie, famine et malédiction ; la ferveur des témoins augmente.
- Soigne et protège pendant 10 ans.

## Bénédictions et malédictions

### Bénédiction

- **Coût** : 10
- **Déblocage** : niveau divin 2
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : status beni (15 ans), fervor 0.1
- **Conséquences différées** : aucune
- **Effet visuel** : `blessing` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Peut rendre envieux les voisins d'autres religions (conversions vers vous).
- Fertilité, nourriture et cohésion accrues pendant 15 ans.

### Malédiction

- **Coût** : 12
- **Déblocage** : niveau divin 2
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : status maudit (10 ans), conversion -0.05
- **Conséquences différées** : fervor -0.1 après 3 ans
- **Effet visuel** : `curse` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Effet réduit de moitié sur les peuples insensibles à la magie. Vos propres fidèles touchés doutent de vous.
- Affaiblit une région pendant 10 ans.

### Âge d'or

- **Coût** : 45
- **Déblocage** : niveau divin 7
- **Portée** : cible établissement, rayon 0 saut(s)
- **Effets immédiats** : status beni (30 ans), status inspire (10 ans), fervor 0.2
- **Conséquences différées** : aucune
- **Effet visuel** : `blessing` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Le pouvoir le plus coûteux ; rend envieux les voisins (conversions).
- Trente années de prospérité et dix d'inspiration pour un établissement.

## Inspirations et révélations

### Révélation

- **Coût** : 15
- **Déblocage** : niveau divin 2
- **Portée** : cible établissement, rayon 0 saut(s)
- **Effets immédiats** : research 0.4, status inspire (8 ans)
- **Conséquences différées** : fervor 0.08 après 5 ans
- **Effet visuel** : `light_beam` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Les conditions de la découverte (ressources, stabilité) restent nécessaires.
- Inspire une découverte (40 % du coût de la recherche en cours).

## Manifestations religieuses

### Signe céleste

- **Coût** : 5
- **Déblocage** : niveau divin 0
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : fervor 0.12, conversion 0.06, memory 0.1
- **Conséquences différées** : aucune
- **Effet visuel** : `aurora` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Les peuples dotés du trait « Sens des présages » réagissent davantage.
- Une aurore surnaturelle : ferveur et conversions.

### Murmure

- **Coût** : 2
- **Déblocage** : toujours disponible
- **Portée** : cible établissement, rayon 0 saut(s)
- **Effets immédiats** : conversion 0.03, memory 0.15
- **Conséquences différées** : aucune
- **Effet visuel** : `whisper` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Plus efficace là où subsiste la mémoire de votre culte.
- Une voix dans les rêves. Pouvoir de dernier recours, utilisable même sans fidèles.

### Aurore sacrée

- **Coût** : 7
- **Déblocage** : niveau divin 1
- **Portée** : cible cellule, rayon 3 saut(s)
- **Effets immédiats** : fervor 0.08, memory 0.2
- **Conséquences différées** : aucune
- **Effet visuel** : `aurora` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Ferveur des fidèles ; les autres peuples se souviendront de vous (retour facilité plus tard).
- Des voiles de lumière dansent dans le ciel de la région.

## Catastrophes, destruction et renaissance

### Séisme

- **Coût** : 20
- **Déblocage** : niveau divin 3
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : height 0.12, pop -0.15, status traumatise (6 ans)
- **Conséquences différées** : resource ore après 4 ans
- **Effet visuel** : `quake` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Peut provoquer une régression technique par perte de stabilité.
- Secoue la région : morts et destructions, puis des filons de minerai apparaissent.

### Déluge

- **Coût** : 25
- **Déblocage** : niveau divin 4
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : moisture 0.35, height -0.08, pop -0.2, status traumatise (6 ans)
- **Conséquences différées** : fertility 0.2 après 6 ans
- **Effet visuel** : `flood` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Destruction puis renaissance agricole.
- Inonde la région ; les terres limoneuses deviennent très fertiles ensuite.

### Renaissance

- **Coût** : 18
- **Déblocage** : niveau divin 3
- **Portée** : cible cellule, rayon 1 saut(s)
- **Effets immédiats** : fertility 0.25, cleanse ['traumatise', 'maudit', 'famine']
- **Conséquences différées** : status beni après 3 ans
- **Effet visuel** : `rebirth` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Idéal après une catastrophe.
- Fait renaître une terre dévastée.

### Éruption

- **Coût** : 30
- **Déblocage** : niveau divin 5
- **Portée** : cible cellule, rayon 2 saut(s)
- **Effets immédiats** : height 0.15, pop -0.2, status traumatise (8 ans)
- **Conséquences différées** : fertility 0.15 après 6 ans, resource ore après 6 ans
- **Effet visuel** : `eruption` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Peut faire régresser un peuple ; la région devient ensuite très productive.
- Un volcan s'éveille : destruction, puis des cendres très fertiles et du minerai.

### Grand froid

- **Coût** : 40
- **Déblocage** : niveau divin 6
- **Portée** : cible cellule, rayon 3 saut(s)
- **Effets immédiats** : temperature -0.25, pop -0.05, status traumatise (5 ans)
- **Conséquences différées** : temperature 0.2 après 20 ans
- **Effet visuel** : `frost` (prévu : surbrillance de zone au jalon 1)
- **Interactions** : Favorise les traits de résistance au froid ; les peuples du froid y prospèrent.
- Un froid durable s'abat sur une vaste région ; il s'atténue au bout de 20 ans.

## Progression divine (accomplissements)

| Objectif | Condition | XP |
|---|---|---|
| Premier village | Votre peuple fonde un deuxième établissement. | 15 |
| Une terre peuplée | Vos fidèles vivent dans 5 établissements. | 30 |
| Cent fidèles | 100 fidèles croient en vous. | 20 |
| Une foi qui grandit | 500 fidèles. | 40 |
| Une religion | 2 000 fidèles. | 80 |
| Premier miracle | Utiliser un pouvoir. | 10 |
| Présence divine | Utiliser 10 pouvoirs. | 25 |
| Loi divine | Activer une règle d'attribution d'affinité. | 10 |
| Dispensateur de dons | Attribuer 50 affinités. | 30 |
| Âge des lames et des runes | Un peuple fidèle atteint l'époque 1. | 30 |
| Âge des royaumes | Un peuple fidèle atteint l'époque 2. | 60 |
| Prosélyte | Des fidèles d'un autre peuple vous vénèrent (≥ 50). | 40 |
| Terre promise | 20 établissements vous vénèrent. | 80 |
| Foi des multitudes | 10 000 fidèles. | 100 |
| Faiseur de prodiges | 100 pouvoirs utilisés. | 80 |
| Dispensateur | 1 000 affinités conférées. | 80 |
| Âge des savoirs | Un peuple fidèle atteint l'époque 4. | 120 |
| Foi sans frontières | 2 000 fidèles parmi d'autres peuples. | 100 |

Seuils de niveau (XP) : 0, 20, 55, 110, 190, 300, 450, 650, 900
