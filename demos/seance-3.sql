-- Séance 3 : CTE, fonctions de fenêtre, index
-- Les démos du cours, dans l'ordre. Fonctionne sur une base neuve comme après
-- les séances 1 et 2. La partie 1 ne modifie rien ; la partie 2 crée des index.
--   docker compose exec db psql -U festival -d festival -f /demos/seance-3.sql


-- Partie 1 : CTE et fonctions de fenêtre -------------------------------------

-- Une CTE : une étape nommée, réutilisée deux fois.
WITH ventes_jour AS (
    SELECT c.passee_le::date AS jour,
           count(*)          AS billets
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE c.statut = 'payee'
    GROUP BY c.passee_le::date
)
SELECT jour, billets
FROM ventes_jour
WHERE billets > 3 * (SELECT avg(billets) FROM ventes_jour)
ORDER BY jour;

-- Fenêtre 1 : la part de chaque offre dans le total.
WITH par_offre AS (
    SELECT o.libelle, count(*) AS billets
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    JOIN offres o ON o.id = b.offre_id
    WHERE c.statut = 'payee'
    GROUP BY o.libelle
)
SELECT libelle,
       billets,
       sum(billets) OVER ()                             AS total,
       round(100.0 * billets / sum(billets) OVER (), 1) AS part_pct
FROM par_offre
ORDER BY billets DESC;

-- Fenêtre 2 : un classement dans chaque groupe.
SELECT genre, nom, cachet,
       rank() OVER (PARTITION BY genre ORDER BY cachet DESC) AS rang
FROM artistes
ORDER BY genre, rang;

-- Fenêtre 3 : un cumul, mois après mois.
WITH ventes_mois AS (
    SELECT date_trunc('month', c.passee_le)::date AS mois, count(*) AS billets
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE c.statut = 'payee'
    GROUP BY 1
)
SELECT mois,
       billets,
       sum(billets) OVER (ORDER BY mois) AS cumul
FROM ventes_mois
ORDER BY mois;


-- Partie 2 : index et EXPLAIN ------------------------------------------------

-- Les billets d'un client : sans index.
EXPLAIN ANALYZE
SELECT b.*
FROM billets b
JOIN commandes c ON c.id = b.commande_id
WHERE c.client_id = 1234;

CREATE INDEX commandes_client_idx ON commandes (client_id);
CREATE INDEX billets_commande_idx ON billets (commande_id);

-- La même requête, avec les index.
EXPLAIN ANALYZE
SELECT b.*
FROM billets b
JOIN commandes c ON c.id = b.commande_id
WHERE c.client_id = 1234;

-- Un index n'est pas toujours utilisé : trop de lignes correspondent.
CREATE INDEX commandes_canal_idx ON commandes (canal);
EXPLAIN SELECT * FROM commandes WHERE canal = 'guichet';   -- 4 % des commandes : l'index sert
EXPLAIN SELECT * FROM commandes WHERE canal = 'web';       -- 60 % : PostgreSQL lit toute la table
DROP INDEX commandes_canal_idx;

-- Ce que coûtent les index : de la place, et du temps à chaque écriture.
SELECT indexrelname AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS taille
FROM pg_stat_user_indexes
WHERE indexrelname IN ('commandes_client_idx', 'billets_commande_idx');


-- Pour aller plus loin -------------------------------------------------------

-- Le top 1 de chaque genre : on classe dans une CTE, puis on filtre.
WITH classement AS (
    SELECT genre, nom, cachet,
           row_number() OVER (PARTITION BY genre ORDER BY cachet DESC) AS rang
    FROM artistes
)
SELECT genre, nom, cachet
FROM classement
WHERE rang = 1
ORDER BY cachet DESC;

-- Comparer à la ligne d'avant : les ventes mois par mois.
WITH ventes_mois AS (
    SELECT date_trunc('month', c.passee_le)::date AS mois, count(*) AS billets
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE c.statut = 'payee'
    GROUP BY 1
)
SELECT mois,
       billets,
       lag(billets) OVER (ORDER BY mois) AS mois_precedent
FROM ventes_mois
ORDER BY mois;

-- Une fonction sur la colonne empêche d'utiliser son index : on indexe l'expression.
EXPLAIN SELECT * FROM clients WHERE lower(email) = 'maelys.simon.1@proton.me';
CREATE INDEX clients_email_lower_idx ON clients (lower(email));
EXPLAIN SELECT * FROM clients WHERE lower(email) = 'maelys.simon.1@proton.me';
