# Règles du jeu (référence)

Les valeurs chiffrées viennent de `data/config.json`, sauf mention contraire. Cette page explique ce qu'elles font.

## 1. Règle centrale : affinités Magie et Épée

### 1.1 Quatre états, séparés des traits
Chaque habitant a exactement un état d'affinité : **Sans affinité**, **Magie**, **Épée**, **Magie et Épée**.
Les affinités ne sont pas des traits : elles ne figurent pas dans `data/traits.json`, ne sont jamais héritées et ne
subissent ni mutation ni sélection. Un test vérifie qu'aucun trait ne porte ces identifiants.

- **Magie** : aptitude à *apprendre* la pratique magique. La maîtrise (`mastery.magic`, 0–100 %) progresse chaque
  année par l'apprentissage (techniques Runes, Arcanes, Cristaux d'éther…).
- **Épée** : talent exceptionnel pour les armes et le combat physique. Elle n'implique aucune aura ni énergie
  surnaturelle. Sa maîtrise (`mastery.sword`) progresse par l'expérience (Maniement des armes, Ordres de lames…).
- Avoir une affinité ne donne aucune maîtrise immédiate.
- **Compétence ordinaire distincte** : l'*entraînement aux armes* (`training`) concerne tout le monde et vient des
  techniques militaires. Il ne confère jamais l'affinité Épée.

### 1.2 Répartition des naissances (implémentée dans `sim/affinity.gd`)
Un **compteur mondial de naissances** découpe les naissances en cycles de 3 :
- **2 naissances sur 3 sont ouvertes à l'attribution divine** (`divine_slots_per_cycle = 2`).
  Le dieu concerné est tiré selon les parts religieuses de l'établissement. Si les parents ne croient en aucun dieu,
  personne ne décide.
  - Le dieu peut attribuer Magie, Épée ou les deux : d'abord par ses **ordres manuels**, puis par ses **règles
    automatiques**, dans l'ordre de priorité.
  - **Sans attribution, l'enfant naît sans affinité. Il n'y a pas de tirage naturel de remplacement.**
- **1 naissance sur 3 est naturelle** (`natural_slots_per_cycle = 1`). Le hasard y tire **uniquement** parmi :

| Résultat naturel | Probabilité par défaut | Clé de configuration |
|---|---|---|
| Sans affinité | 80 % | `affinity.natural_probabilities.none` |
| Magie | 12 % | `affinity.natural_probabilities.magic` |
| Épée | 8 % | `affinity.natural_probabilities.sword` |

  Les trois valeurs sont normalisées : leur somme peut être différente de 1. Toute autre clé, y compris `both`,
  est **ignorée** : la double affinité ne peut jamais apparaître naturellement.

### 1.3 Exclusivité divine
- Seul un dieu peut conférer **Magie et Épée**, que ce soit à la naissance (ordre ou règle) ou plus tard (pouvoir
  *Don d'affinité*).
- L'hérédité est ignorée : des parents « Magie et Épée » n'ont pas plus de chances d'avoir un enfant doublement doté.
- Un habitant né sans affinité ne peut en recevoir une plus tard que par le pouvoir **Don d'affinité**. Son coût est
  multiplié par `late_grant_cost_multiplier` (×2 par défaut).

### 1.4 Coûts et limites (ressources divines)
| Attribution | Coût en énergie (à la naissance) | Coût tardif (×2) |
|---|---|---|
| Magie | 0,6 | 1,2 |
| Épée | 0,6 | 1,2 |
| Magie et Épée | 2,5 | 5,0 |

- Chaque dieu a un **budget automatique annuel** (`auto_budget`, 4 par défaut, modifiable dans l'écran
  « Affinités »). Les règles ne dépensent jamais au-delà, ni au-delà de l'énergie disponible.
- Chaque règle a un **plafond annuel** (`max_per_year`).
- Les ordres manuels ne sont limités que par l'énergie disponible au moment de la naissance.

### 1.5 Règles automatiques
Une règle contient : nom, *active / inactive*, priorité (la plus petite passe en premier), conditions (toutes doivent
être vraies), résultat (Magie, Épée ou les deux), plafond annuel, et des statistiques (total, cette année, refus faute
de budget).

| Condition | Paramètres | Sens |
|---|---|---|
| Toujours | — | toujours vraie |
| Peuple d'origine du dieu | — | l'établissement appartient au peuple créé par ce dieu |
| Espèce | espèce | espèce du peuple |
| Région (biome) | biome | biome de la cellule de l'établissement |
| Part de la lignée | affinité, <, ≥, % | part des habitants de l'établissement portant cette affinité (« lignée ») |
| Fréquence d'un trait | trait, <, ≥, % | fréquence d'un trait héréditaire dans l'établissement |
| Besoin du peuple | défense / recherche magique / famine / ferveur faible | état actuel du peuple |
| Population | <, ≥, nombre | taille de l'établissement |

Chaque attribution est **expliquée** et conservée dans l'historique (ex. « Règle « Lames en temps de guerre » :
besoin : Menace ou guerre »). L'historique est regroupé par année, établissement, source et résultat, avec 200
lignes au maximum.

Les règles automatiques sont des décisions déléguées par le dieu : elles comptent comme attributions **divines**,
jamais comme naturelles.

Les **dieux rivaux** reçoivent des règles déduites de leur personnalité (`Affinity.rival_rules`) : Épée en temps de
guerre s'ils sont agressifs, Magie pour la recherche s'ils penchent vers la magie, quelques élus doublement dotés.
Ils obéissent aux mêmes budgets et coûts que le joueur.

### 1.6 Sauvegarde et rechargement
Le résultat de chaque naissance est stocké tout de suite dans l'établissement (`aff`), les statistiques et
l'historique. L'état du générateur aléatoire et le compteur de naissances sont aussi sauvegardés. Recharger une
partie reprend donc **exactement la même suite** : aucune naissance n'est retirée, et une attribution déjà payée ne
peut pas être obtenue deux fois. Un test le vérifie.

## 2. Population et milieu
- **Capacité d'accueil** K d'un établissement = somme, sur son territoire, de la nourriture que fournit chaque
  cellule (fertilité × adaptation de l'espèce et des traits au biome, plus gibier et poisson), × 40, × bonus
  techniques.
- Les **naissances** décroissent quand la population approche de K. L'équilibre se situe vers 75 % de K. Au-delà
  de K, une surmortalité s'applique.
- Les naissances sont des **entiers** (accumulateur fractionnaire) et chacune passe par la répartition des affinités.
- **Famine** quand les réserves s'épuisent : surmortalité réduite par la coopération et l'endurance, stabilité en
  baisse, doute religieux.
- **Épidémies** possibles au-delà de 250 habitants selon la densité et la résistance aux maladies.
- **Territoire** : rayon 0 à 3 cellules selon la taille, uniquement sur des cellules libres.
- **Expansion** : quand la population dépasse ~70 % de K et un seuil lié à la sociabilité, avec une probabilité
  liée à la curiosité et au courage, 30 % des habitants fondent un nouvel établissement. La destination est la
  meilleure cellule libre dans un rayon de 5 sauts (80 cellules examinées au maximum). Les colons emportent leurs
  affinités au prorata et des fréquences de traits légèrement modifiées (effet fondateur).

## 3. Hérédité, mutations, milieu
- **Héréditaires** : fréquence par établissement. Les fondateurs fixent les fréquences de départ (trait présent chez
  les deux = 100 %, chez un seul = 50 %).
- À chaque **génération** (durée propre à l'espèce, allongée par la longévité), trois mécanismes s'appliquent :
  - **sélection** : un trait progresse s'il aide à survivre dans ce milieu (froid, chaleur, côtes, forêt, montagne,
    désert, famine, densité) ;
  - **dérive** : un écart aléatoire, plus fort dans les petites populations ;
  - **mutation** : un trait absent apparaît à 3 %, pondéré par sa rareté.
- Deux traits **incompatibles** ne coexistent pas chez un individu : leurs fréquences sont normalisées.
- **Acquis** : traits de culture du peuple, issus des découvertes (ex. Écriture → tradition écrite). Ils ne se
  transmettent pas par le sang.
- **Temporaires** : états de durée limitée (famine, épidémie, béni, protégé, inspiré, maudit, traumatisé).
- Le journal signale les mutations et les traits qui deviennent majoritaires, avec leur cause. L'histoire du peuple
  garde les transformations marquantes. Le bouton « Habitants » montre des **individus représentatifs**, tirés de la
  distribution réelle de l'établissement.

## 4. Progression science / magie
Voir `PROGRESSION.md`. Une découverte demande ses prérequis, des ressources présentes dans le territoire, ainsi
qu'un minimum de stabilité, de population et de porteurs d'affinité selon le cas. Les points de recherche dépendent
de la population, de l'intelligence, de la curiosité, de la stabilité et de la voie du peuple (−1 magie … +1 science).
Chaque découverte déplace légèrement la voie vers sa branche.
- **Stagnation** : aucune découverte possible. Le journal l'indique après 60 ans et la fiche du peuple liste les
  obstacles.
- **Régression** : si la stabilité moyenne reste sous 25 %, la dernière découverte peut être perdue. La longévité et
  la tradition écrite réduisent ce risque.
- **Époque** : la plus haute dont au moins 2 découvertes sont connues (1 pour l'âge astral). Elle détermine la
  silhouette des bâtiments.

## 5. Foi
| Grandeur | Définition |
|---|---|
| Fidèles | Σ population × part de la religion |
| Ferveur | 0–1 par établissement ; tend vers 0,15 + 0,55 × spiritualité + bonus religieux (autel, temple) |
| Production de foi | Σ fidèles × ferveur × 0,005 × bonus des temples, par an |
| Énergie divine | réserve plafonnée (60 + 40 × niveau) alimentée par la production |
| Progression | XP gagnée par les accomplissements (`data/powers.json`) → niveau → pouvoirs |

- **Doute** : une famine ou une épidémie sans aide divine depuis 10 ans fait baisser la ferveur et la part de la
  religion.
- **Conversions** : la foi se diffuse entre établissements proches, de la religion la plus fervente vers la moins
  fervente, quel que soit le peuple. Le fanatisme freine les conversions.
- **Mémoire du culte** : trace qui décroît lentement (deux fois moins vite avec le culte des ancêtres) et permet
  une *redécouverte* spontanée.
- **Dieu affaibli** : sous 10 fidèles, regain de 0,3 énergie par an jusqu'à 12. **Murmure** (coût 2, toujours
  disponible) ramène des fidèles, surtout là où la mémoire du culte subsiste. La partie continue toujours.

## 6. Relations
- Contact quand deux territoires se touchent.
- La relation évolue selon l'agressivité et la coopération, une religion commune et l'entente entre les dieux.
- **Guerre** sous −0,5 : pertes proportionnelles au rapport des forces militaires, où comptent la population, la
  force, l'entraînement, ainsi que les porteurs d'Épée et de Magie et leur maîtrise. Paix après épuisement.
- **Alliance** au-dessus de 0,6.
- Organisation politique : tribu, chefferie, royaume, empire. **Sécession** d'un grand peuple instable.
- Les dieux nouent des pactes ou des rivalités selon leurs personnalités et la concurrence pour les fidèles.
  Il n'y a pas d'affrontement direct entre dieux.

## 7. Absence
- 1 an simulé pour 10 minutes réelles, plafonné à 8 heures (48 ans), calculé par lots de 10 ans par image.
- La période est marquée comme consommée **avant** le calcul.
- Si l'horloge recule, aucune progression n'est appliquée.
- Les mondes importés ne rattrapent pas d'absence.
