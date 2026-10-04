-- Séance 2 : triggers, transactions, index
-- Les exemples du cours, dans l'ordre. À lancer sur une base qui a reçu
-- demos/seance-1.sql (il faut places_vendues()) :
--   docker compose exec db psql -U festival -d festival -f /demos/seance-2.sql


-- 1. Un trigger qui refuse (BEFORE) ------------------------------------------

CREATE FUNCTION refuser_survente()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF places_vendues(NEW.offre_id) >= (SELECT quota FROM offres WHERE id = NEW.offre_id) THEN
        RAISE EXCEPTION 'Offre % complète', NEW.offre_id;
    END IF;

    RETURN NEW;    -- la ligne continue son chemin
END;
$$;

CREATE TRIGGER billets_refuser_survente
BEFORE INSERT ON billets
FOR EACH ROW
EXECUTE FUNCTION refuser_survente();

-- Il reste une seule place en VIP samedi. Le guichet en vend deux :
INSERT INTO commandes (client_id, canal) VALUES (7, 'guichet');
INSERT INTO billets (commande_id, offre_id, prix_paye) VALUES (currval('commandes_id_seq'), 7, 169);   -- la dernière place : acceptée
INSERT INTO billets (commande_id, offre_id, prix_paye) VALUES (currval('commandes_id_seq'), 7, 169);   -- refusée
SELECT libelle, quota, places_vendues(id) AS vendues FROM offres WHERE id = 7;


-- 2. Un trigger qui écrit ailleurs (AFTER) -----------------------------------

CREATE TABLE journal_prix (
    id            serial PRIMARY KEY,
    offre_id      integer NOT NULL,
    ancien_prix   numeric NOT NULL,
    nouveau_prix  numeric NOT NULL,
    par           text NOT NULL DEFAULT current_user,
    le            timestamp NOT NULL DEFAULT now()
);

CREATE FUNCTION journaliser_prix()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO journal_prix (offre_id, ancien_prix, nouveau_prix)
    VALUES (NEW.id, OLD.prix, NEW.prix);

    RETURN NULL;
END;
$$;

CREATE TRIGGER offres_journaliser_prix
AFTER UPDATE OF prix ON offres
FOR EACH ROW
EXECUTE FUNCTION journaliser_prix();

UPDATE offres SET prix = 75 WHERE id = 1;
UPDATE offres SET prix = 69 WHERE id = 1;
SELECT offre_id, ancien_prix, nouveau_prix, par FROM journal_prix ORDER BY id;


-- 3. Une transaction : tout ou rien ------------------------------------------

BEGIN;
UPDATE offres SET prix = prix * 2;
SELECT libelle, prix FROM offres ORDER BY id LIMIT 3;    -- les prix ont doublé...
ROLLBACK;
SELECT libelle, prix FROM offres ORDER BY id LIMIT 3;    -- ... et non : rien n'a été gardé


-- 4. Index et EXPLAIN --------------------------------------------------------

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

-- Ce que coûte un index : de la place, et du temps à chaque écriture.
SELECT pg_size_pretty(pg_relation_size('billets_commande_idx')) AS taille;
