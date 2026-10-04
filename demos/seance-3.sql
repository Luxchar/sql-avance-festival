-- Séance 3 : CTE et fonctions de fenêtre, rôles, vues
-- Les exemples du cours, dans l'ordre. Fonctionne sur une base neuve comme
-- après les séances 1 et 2.
--   docker compose exec db psql -U festival -d festival -f /demos/seance-3.sql


-- 1. Une CTE, puis une fonction de fenêtre -----------------------------------

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

-- Une fonction de fenêtre : la part de chaque offre dans le total.
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


-- 2. Rôles et privilèges -----------------------------------------------------

-- Le rôle-métier : on lui donne les droits, on ne se connecte pas avec (NOLOGIN).
CREATE ROLE guichet NOLOGIN;

-- La personne : elle se connecte (LOGIN) et hérite du rôle-métier.
CREATE ROLE emma LOGIN PASSWORD 'emma' IN ROLE guichet;

-- Le guichet lit le programme et les offres, et quelques colonnes des clients.
GRANT SELECT ON offres, concerts, artistes, scenes TO guichet;
GRANT SELECT (id, prenom, nom, ville) ON clients TO guichet;

SET ROLE emma;
SELECT libelle, prix FROM offres ORDER BY id LIMIT 2;    -- autorisé
SELECT id, prenom, nom FROM clients WHERE id = 42;       -- autorisé : colonnes permises
SELECT email FROM clients WHERE id = 42;                 -- refusé
SELECT count(*) FROM commandes;                          -- refusé
RESET ROLE;

-- Retirer un droit.
REVOKE SELECT ON scenes FROM guichet;

SET ROLE emma;
SELECT nom FROM scenes;                                  -- refusé, maintenant
RESET ROLE;


-- 3. Les vues ----------------------------------------------------------------

-- Une vue qui cache la complexité : deux tables, un filtre, un regroupement.
CREATE VIEW ventes_par_jour AS
SELECT c.passee_le::date AS jour,
       c.canal,
       count(*)          AS billets,
       sum(b.prix_paye)  AS ca
FROM commandes c
JOIN billets b ON b.commande_id = c.id
WHERE c.statut = 'payee'
GROUP BY c.passee_le::date, c.canal;

SELECT * FROM ventes_par_jour WHERE jour = '2026-03-03' ORDER BY canal;

-- Une vue qui protège les données personnelles.
CREATE VIEW clients_masques AS
SELECT id,
       prenom,
       left(nom, 1) || '.'                                       AS nom,
       left(email, 1) || '***@' || split_part(email, '@', 2)     AS email,
       ville
FROM clients;

REVOKE SELECT (id, prenom, nom, ville) ON clients FROM guichet;
GRANT SELECT ON clients_masques TO guichet;

SET ROLE emma;
SELECT * FROM clients_masques WHERE id = 42;             -- autorisé, masqué
SELECT * FROM clients WHERE id = 42;                     -- refusé
RESET ROLE;
