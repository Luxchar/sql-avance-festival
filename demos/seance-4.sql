-- Séance 4 : rôles et vues
-- Les démos du cours, dans l'ordre. Les parties 1 et 2 fonctionnent sur une
-- base neuve. La dernière section (pour aller plus loin) suppose que
-- demos/seance-1.sql et demos/seance-2.sql sont passées.
--   docker compose exec db psql -U festival -d festival -f /demos/seance-4.sql


-- Partie 1 : rôles et privilèges ---------------------------------------------

-- Les rôles-métiers : on ne se connecte pas avec (NOLOGIN), on leur donne les droits.
CREATE ROLE guichet NOLOGIN;
CREATE ROLE compta  NOLOGIN;

-- Les personnes : elles se connectent (LOGIN) et héritent d'un rôle-métier.
CREATE ROLE emma LOGIN PASSWORD 'emma' IN ROLE guichet;
CREATE ROLE hugo LOGIN PASSWORD 'hugo' IN ROLE compta;

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

GRANT SELECT ON scenes TO guichet;                       -- on le lui rend

-- Qui a quoi ?
\du
\dp offres


-- Partie 2 : les vues --------------------------------------------------------

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

GRANT SELECT ON ventes_par_jour TO compta;

SET ROLE hugo;
SELECT * FROM ventes_par_jour WHERE jour = '2026-03-03' ORDER BY canal;   -- autorisé
RESET ROLE;

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


-- Pour aller plus loin -------------------------------------------------------

-- Vendre sans avoir le droit d'écrire partout : SECURITY DEFINER.
SET ROLE emma;
CALL acheter(42, 1, 1);                                  -- refusé : emma ne peut pas lire billets
RESET ROLE;

ALTER PROCEDURE acheter(int, int, int) SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON PROCEDURE acheter(int, int, int) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE acheter(int, int, int) TO guichet;

SET ROLE emma;
CALL acheter(42, 1, 1);                                  -- autorisé : la procédure agit avec les droits de son propriétaire
INSERT INTO billets (commande_id, offre_id, prix_paye) VALUES (1, 1, 0);   -- refusé : pas de raccourci
RESET ROLE;

-- Une vue matérialisée : le résultat est stocké, on le rafraîchit quand on veut.
CREATE MATERIALIZED VIEW remplissage AS
SELECT libelle, quota, vendus, round(100.0 * vendus / quota, 1) AS remplissage_pct
FROM offres;

SELECT * FROM remplissage ORDER BY remplissage_pct DESC;
REFRESH MATERIALIZED VIEW remplissage;
