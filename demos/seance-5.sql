-- Séance 5 : transactions et index
-- Les démos du cours, dans l'ordre. À lancer sur une base qui a reçu
-- demos/seance-1.sql et demos/seance-2.sql (il faut la colonne vendus et les triggers).


-- Partie 1 : les transactions ------------------------------------------------

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


-- Partie 2 : index et EXPLAIN ------------------------------------------------

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
