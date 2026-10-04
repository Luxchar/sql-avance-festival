-- Séance 2 : triggers, transactions, index
-- Les démos du cours, dans l'ordre. À lancer sur une base qui a reçu
-- demos/seance-1.sql (il faut places_vendues() et acheter()) :
--   docker compose exec db psql -U festival -d festival -f /demos/seance-2.sql


-- Partie 1 : les triggers ----------------------------------------------------

-- Démo 1 : un compteur tenu à jour tout seul (AFTER).
ALTER TABLE offres ADD COLUMN vendus integer NOT NULL DEFAULT 0;
UPDATE offres SET vendus = places_vendues(id);

CREATE FUNCTION compter_billet()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE offres SET vendus = vendus + 1 WHERE id = NEW.offre_id;
    RETURN NULL;   -- AFTER : la valeur renvoyée est ignorée
END;
$$;

CREATE TRIGGER billets_compter
AFTER INSERT ON billets
FOR EACH ROW
EXECUTE FUNCTION compter_billet();

SELECT libelle, vendus FROM offres WHERE id = 1;
CALL acheter(42, 1, 1);
SELECT libelle, vendus FROM offres WHERE id = 1;    -- un de plus, sans rien recompter

-- Démo 2 : la survente refusée, par tous les canaux (BEFORE).
CREATE FUNCTION refuser_survente()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_vendus int;
    v_quota  int;
BEGIN
    SELECT vendus, quota INTO v_vendus, v_quota
    FROM offres
    WHERE id = NEW.offre_id;

    IF v_vendus >= v_quota THEN
        RAISE EXCEPTION 'Offre % complète : % places vendues sur %', NEW.offre_id, v_vendus, v_quota;
    END IF;

    RETURN NEW;    -- BEFORE : la ligne continue son chemin
END;
$$;

CREATE TRIGGER billets_refuser_survente
BEFORE INSERT ON billets
FOR EACH ROW
EXECUTE FUNCTION refuser_survente();

-- Le guichet insère directement, sans passer par acheter() :
INSERT INTO commandes (client_id, canal) VALUES (7, 'guichet');
INSERT INTO billets (commande_id, offre_id, prix_paye) VALUES (currval('commandes_id_seq'), 7, 169);   -- la dernière place : acceptée
INSERT INTO billets (commande_id, offre_id, prix_paye) VALUES (currval('commandes_id_seq'), 7, 169);   -- refusée
SELECT libelle, vendus, quota FROM offres WHERE id = 7;


-- Partie 2 : les transactions ------------------------------------------------

-- Tout ou rien, à la main.
BEGIN;
UPDATE offres SET prix = prix * 2;
SELECT libelle, prix FROM offres ORDER BY id LIMIT 3;    -- les prix ont doublé...
ROLLBACK;
SELECT libelle, prix FROM offres ORDER BY id LIMIT 3;    -- ... et non : rien n'a été gardé


-- Partie 3 : index et EXPLAIN ------------------------------------------------

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

-- La course à la dernière place (à deux terminaux, voir la fin du support) :
-- le correctif verrouille la ligne de l'offre avant de lire le compteur.
CREATE OR REPLACE FUNCTION refuser_survente()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_vendus int;
    v_quota  int;
BEGIN
    SELECT vendus, quota INTO v_vendus, v_quota
    FROM offres
    WHERE id = NEW.offre_id
    FOR UPDATE;                  -- les autres attendent ici que la transaction se termine

    IF v_vendus >= v_quota THEN
        RAISE EXCEPTION 'Offre % complète : % places vendues sur %', NEW.offre_id, v_vendus, v_quota;
    END IF;

    RETURN NEW;
END;
$$;

-- Une fonction sur la colonne empêche d'utiliser son index : on indexe l'expression.
EXPLAIN SELECT * FROM clients WHERE lower(email) = 'maelys.simon.1@proton.me';
CREATE INDEX clients_email_lower_idx ON clients (lower(email));
EXPLAIN SELECT * FROM clients WHERE lower(email) = 'maelys.simon.1@proton.me';
