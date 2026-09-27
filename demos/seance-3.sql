-- Séance 3 : droits, vues, transactions, index
-- Les démos du cours, dans l'ordre. À lancer sur une base qui a reçu
-- demos/seance-1.sql (il faut la colonne vendus, les triggers et acheter()).


-- Partie 1 : rôles et privilèges ---------------------------------------------

-- Les rôles-métiers : on ne se connecte pas avec (NOLOGIN), on les attribue
CREATE ROLE guichet NOLOGIN;
CREATE ROLE compta  NOLOGIN;

-- Les personnes : elles se connectent (LOGIN) et héritent d'un rôle-métier
CREATE ROLE emma LOGIN PASSWORD 'emma' IN ROLE guichet;
CREATE ROLE hugo LOGIN PASSWORD 'hugo' IN ROLE compta;

-- Le guichet lit le programme et les offres, et quelques colonnes des clients
GRANT SELECT ON offres, concerts, artistes, scenes TO guichet;
GRANT SELECT (id, prenom, nom, ville) ON clients TO guichet;

SET ROLE emma;
SELECT libelle, prix FROM offres ORDER BY id LIMIT 2;    -- autorisé
SELECT id, prenom, nom FROM clients WHERE id = 42;       -- autorisé : colonnes permises
SELECT email FROM clients WHERE id = 42;                 -- refusé
SELECT count(*) FROM commandes;                          -- refusé
RESET ROLE;

-- Vendre sans avoir le droit d'écrire partout : SECURITY DEFINER
SET ROLE emma;
CALL acheter(42, 1, 1);                                  -- refusé : emma ne peut pas lire billets
RESET ROLE;

ALTER PROCEDURE acheter(int, int, int, text) SECURITY DEFINER SET search_path = public;
REVOKE EXECUTE ON PROCEDURE acheter(int, int, int, text) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE acheter(int, int, int, text) TO guichet;

SET ROLE emma;
CALL acheter(42, 1, 1);                                  -- autorisé : la procédure agit avec les droits de son propriétaire
INSERT INTO billets (commande_id, offre_id, prix_paye) VALUES (1, 1, 0);   -- refusé : pas de raccourci
RESET ROLE;

-- Retirer un droit
GRANT SELECT ON commandes TO compta;
REVOKE SELECT ON commandes FROM compta;

-- Qui a quoi ?
\dp offres
\du


-- Partie 2 : les vues --------------------------------------------------------

-- Une vue qui masque les données personnelles
CREATE VIEW clients_masques AS
SELECT id,
       prenom,
       left(nom, 1) || '.'                                    AS nom,
       left(email, 1) || '***@' || split_part(email, '@', 2)  AS email,
       left(telephone, 2) || ' ** ** ** ' || right(telephone, 2) AS telephone,
       ville
FROM clients;

REVOKE SELECT (id, prenom, nom, ville) ON clients FROM guichet;
GRANT SELECT ON clients_masques TO guichet;

SET ROLE emma;
SELECT * FROM clients_masques WHERE id = 42;             -- autorisé, masqué
SELECT * FROM clients WHERE id = 42;                     -- refusé
RESET ROLE;

-- Une vue qui cache la complexité : trois tables, un filtre, un regroupement
CREATE VIEW ventes_par_jour AS
SELECT c.passee_le::date AS jour,
       c.canal,
       count(*)          AS billets,
       sum(b.prix_paye)  AS ca
FROM commandes c
JOIN billets b ON b.commande_id = c.id
WHERE c.statut = 'payee'
GROUP BY 1, 2;

GRANT SELECT ON ventes_par_jour TO compta;

SET ROLE hugo;
SELECT * FROM ventes_par_jour WHERE jour = '2026-03-03' ORDER BY canal;
RESET ROLE;

-- Une vue matérialisée : le résultat est stocké, on le rafraîchit quand on veut
CREATE MATERIALIZED VIEW remplissage AS
SELECT libelle, quota, vendus, round(100.0 * vendus / quota, 1) AS remplissage_pct
FROM offres;

SELECT * FROM remplissage ORDER BY remplissage_pct DESC;
REFRESH MATERIALIZED VIEW remplissage;


-- Partie 3 : les transactions ------------------------------------------------

-- Tout ou rien, à la main
BEGIN;
UPDATE offres SET prix = prix * 2;
SELECT libelle, prix FROM offres ORDER BY id LIMIT 3;    -- les prix ont doublé...
ROLLBACK;
SELECT libelle, prix FROM offres ORDER BY id LIMIT 3;    -- ... et non : rien n'a été gardé

-- La course à la dernière place se joue à deux terminaux : voir le support.
-- Le correctif : verrouiller la ligne de l'offre avant de lire le compteur.
CREATE OR REPLACE FUNCTION refuser_survente()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_offre offres%ROWTYPE;
BEGIN
    SELECT * INTO v_offre
    FROM offres
    WHERE id = NEW.offre_id
    FOR UPDATE;                  -- les autres attendent ici que la transaction se termine

    IF v_offre.vendus >= v_offre.quota THEN
        RAISE EXCEPTION 'Offre « % » complète (% / %)', v_offre.libelle, v_offre.vendus, v_offre.quota;
    END IF;

    RETURN NEW;
END;
$$;


-- Partie 4 : index et EXPLAIN ------------------------------------------------

-- Les billets d'un client : sans index
EXPLAIN ANALYZE
SELECT b.*
FROM billets b
JOIN commandes c ON c.id = b.commande_id
WHERE c.client_id = 1234;

CREATE INDEX commandes_client_idx ON commandes (client_id);
CREATE INDEX billets_commande_idx ON billets (commande_id);

-- La même requête, avec les index
EXPLAIN ANALYZE
SELECT b.*
FROM billets b
JOIN commandes c ON c.id = b.commande_id
WHERE c.client_id = 1234;

-- Un index n'est pas toujours utilisé : trop de lignes correspondent
CREATE INDEX commandes_canal_idx ON commandes (canal);
EXPLAIN SELECT * FROM commandes WHERE canal = 'guichet';   -- 4 % des commandes : l'index sert
EXPLAIN SELECT * FROM commandes WHERE canal = 'web';       -- 60 % : PostgreSQL lit toute la table
DROP INDEX commandes_canal_idx;

-- Une fonction sur la colonne empêche d'utiliser son index
EXPLAIN SELECT * FROM clients WHERE lower(email) = 'maelys.simon.1@proton.me';
CREATE INDEX clients_email_lower_idx ON clients (lower(email));
EXPLAIN SELECT * FROM clients WHERE lower(email) = 'maelys.simon.1@proton.me';

-- Ce que coûtent les index : de la place, et du temps à chaque écriture
SELECT indexrelname AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS taille
FROM pg_stat_user_indexes
WHERE relname IN ('billets', 'commandes', 'clients')
ORDER BY pg_relation_size(indexrelid) DESC;
