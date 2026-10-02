# Antisèche SQL : les bases à revoir

**SQL avancé · Bachelor 2 · Ycode A2627_4728**
**À relire, et à essayer, avant la première séance du mercredi 7 octobre**

Le module repart de ce que vous avez vu en B1 : lire, joindre, regrouper. Si une ligne de cette page ne vous dit rien, c'est elle qu'il faut revoir. Tous les exemples tournent sur la base du cours : la billetterie d'un festival.

---

## Avant mercredi : installer et lancer la base

Il faut **Git** et **Docker Desktop**, lancé. Le premier démarrage télécharge PostgreSQL (environ 150 Mo) : faites-le chez vous, pas sur le Wi-Fi de l'école.

```bash
git clone https://github.com/Luxchar/sql-avance-festival.git
cd sql-avance-festival/base-festival
docker compose up -d
docker compose logs -f db        # attendez « PostgreSQL init process complete », puis Ctrl+C
docker compose exec db psql -U festival -d festival
```

Vous êtes dans `psql`, le terminal de PostgreSQL. Pour vérifier que tout est chargé : `SELECT count(*) FROM billets;` doit répondre 408 325.

| Dans `psql` | Ce que ça fait |
|---|---|
| `\dt` | la liste des tables |
| `\d billets` | les colonnes d'une table |
| `\x` | affichage vertical, pour les lignes trop larges ; retapez `\x` pour revenir |
| `q` | sortir d'un résultat trop long |
| `\q` | quitter `psql` |
| flèche du haut | rappeler la requête précédente |

Une requête se termine par `;`. Si l'invite devient `festival-#`, PostgreSQL attend la suite : tapez `;` puis Entrée.

Tout cassé ? `docker compose down -v` puis `docker compose up -d` : la base repart de zéro, identique.

## Les tables

Un client passe des commandes, une commande contient des billets, un billet correspond à une offre.

| Table | Une ligne, c'est | Colonnes utiles |
|---|---|---|
| `clients` | un client | `id`, `prenom`, `nom`, `email`, `ville` |
| `commandes` | une commande d'un client | `id`, `client_id`, `passee_le`, `canal`, `statut` |
| `billets` | un billet d'une commande | `id`, `commande_id`, `offre_id`, `prix_paye`, `scanne_le` |
| `offres` | ce qu'on vend : pass 1 jour, 3 jours, VIP | `id`, `libelle`, `jour`, `prix`, `quota` |
| `artistes`, `scenes`, `concerts` | la programmation | `nom`, `genre`, `pays`, `cachet` |
| `equipe` | l'organigramme | `nom`, `poste`, `responsable_id` |

---

## Lire : SELECT

```sql
SELECT nom, genre, cachet        -- les colonnes
FROM artistes                    -- la table
WHERE pays = 'FR'                -- le filtre
ORDER BY cachet DESC             -- le tri, du plus grand au plus petit
LIMIT 5;                         -- les cinq premières lignes
```

| Dans le `WHERE` | Exemple |
|---|---|
| égal, différent | `pays = 'FR'`, `pays <> 'FR'` |
| comparer | `cachet >= 100000` |
| combiner | `pays = 'FR' AND genre = 'rap'`, `genre = 'rap' OR genre = 'rock'` |
| une liste | `genre IN ('rap', 'rock')` |
| un intervalle | `cachet BETWEEN 50000 AND 100000` |
| un texte qui ressemble | `nom LIKE 'Les %'` ; `ILIKE` ignore les majuscules |
| une valeur vide | `scanne_le IS NULL`, `scanne_le IS NOT NULL` |

## Joindre : JOIN

Les informations sont réparties dans plusieurs tables. On les relie par la clé étrangère d'un côté, la clé primaire de l'autre.

```sql
SELECT cl.prenom, cl.nom, c.passee_le, c.canal
FROM commandes c
JOIN clients cl ON cl.id = c.client_id
WHERE cl.id = 42;
```

`c` et `cl` sont des alias : ils évitent de répéter le nom des tables.

| Jointure | Garde |
|---|---|
| `JOIN` | les lignes qui ont une correspondance des deux côtés |
| `LEFT JOIN` | toutes les lignes de la table de gauche ; sans correspondance, les colonnes de droite sont vides |

## Regrouper : GROUP BY

```sql
SELECT canal, count(*) AS commandes
FROM commandes
WHERE statut = 'payee'           -- filtre les lignes, avant de regrouper
GROUP BY canal
HAVING count(*) > 10000          -- filtre les groupes, après
ORDER BY commandes DESC;
```

| Fonction | Calcule |
|---|---|
| `count(*)` | le nombre de lignes |
| `count(colonne)` | le nombre de valeurs non vides |
| `sum`, `avg` | la somme, la moyenne |
| `min`, `max` | la plus petite valeur, la plus grande |

La règle : une colonne du `SELECT` est soit dans le `GROUP BY`, soit dans une fonction.

## L'ordre où on écrit, l'ordre où ça s'exécute

| On écrit | PostgreSQL exécute |
|---|---|
| `SELECT` | 1. `FROM` et `JOIN` : les tables |
| `FROM` … `JOIN` | 2. `WHERE` : le filtre sur les lignes |
| `WHERE` | 3. `GROUP BY` : le regroupement |
| `GROUP BY` | 4. `HAVING` : le filtre sur les groupes |
| `HAVING` | 5. `SELECT` : les colonnes et les calculs |
| `ORDER BY` | 6. `ORDER BY` : le tri |
| `LIMIT` | 7. `LIMIT` |

D'où : un alias créé dans le `SELECT` s'utilise dans le `ORDER BY`, pas dans le `WHERE`. On s'en resservira en séance 3.

## Écrire : INSERT, UPDATE, DELETE

Sur une table d'essai, pour ne pas abîmer la base du cours :

```sql
CREATE TABLE essai (
    id     serial PRIMARY KEY,          -- un numéro automatique, unique
    nom    text NOT NULL,               -- obligatoire
    ville  text DEFAULT 'Paris',        -- valeur par défaut
    age    integer CHECK (age >= 0)     -- une règle à respecter
);

INSERT INTO essai (nom, age) VALUES ('Ada', 36), ('Linus', 54);
UPDATE essai SET ville = 'Lyon' WHERE nom = 'Ada';
DELETE FROM essai WHERE age > 50;
SELECT * FROM essai;
DROP TABLE essai;
```

Un `UPDATE` ou un `DELETE` sans `WHERE` touche **toutes** les lignes. Écrivez d'abord le `SELECT` avec le même `WHERE`, regardez ce qu'il renvoie, puis transformez-le.

---

## Les pièges classiques

| Ce que vous voyez | Ce qu'il faut savoir |
|---|---|
| `column "FR" does not exist` | `'FR'`, avec des apostrophes, est un texte ; `"FR"`, avec des guillemets, est un nom de colonne |
| `WHERE scanne_le = NULL` ne renvoie rien | rien n'est égal à `NULL` : écrivez `IS NULL` |
| `must appear in the GROUP BY clause` | une colonne du `SELECT` n'est ni regroupée ni dans une fonction |
| `column reference "id" is ambiguous` | deux tables ont cette colonne : préfixez-la, `c.id` |
| l'invite affiche `festival-#` et rien ne se passe | il manque le `;` |
| `SELECT 7 / 2;` répond `3` | entre deux entiers, la division est entière : écrivez `7 / 2.0` |
| beaucoup trop de lignes après une jointure | la condition du `ON` est fausse ou absente : chaque ligne est combinée avec toutes les autres |

---

## Pour s'échauffer

Cinq requêtes pour vérifier que les bases sont là. Les réponses sont juste en dessous : écrivez la requête avant de regarder.

1. Combien d'artistes viennent de France (`FR`) ?
2. Les trois artistes les mieux payés, avec leur cachet.
3. Le nombre de concerts sur chaque scène, avec le nom de la scène.
4. Le nombre de commandes par statut.
5. Le prénom et la ville du client qui a passé la commande n° 1000.

**Réponses**

1. 17 artistes.
2. Neon Kraken (250 000 €), Mama Bouillon (220 000 €), Les Rats de Cave (180 000 €).
3. 9 concerts sur chacune des quatre scènes.
4. 213 440 commandes payées, 6 560 remboursées.
5. Jade, à Paris.
