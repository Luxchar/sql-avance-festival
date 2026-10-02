-- Séance 2 : triggers
-- Les démos du cours, dans l'ordre. À lancer sur une base qui a reçu
-- demos/seance-1.sql (il faut places_vendues() et acheter()) :
--   docker compose exec db psql -U festival -d festival -f /demos/seance-2.sql


-- Partie 1 : triggers --------------------------------------------------------

-- Un compteur tenu à jour tout seul.
ALTER TABLE offres ADD COLUMN vendus integer NOT NULL DEFAULT 0;
UPDATE offres SET vendus = places_vendues(id);

CREATE FUNCTION compter_billet()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE offres SET vendus = vendus + 1 WHERE id = NEW.offre_id;
    RETURN NULL;   -- ignoré pour un trigger AFTER
END;
$$;

CREATE TRIGGER billets_compter
AFTER INSERT ON billets
FOR EACH ROW
EXECUTE FUNCTION compter_billet();

-- La survente refusée, par tous les canaux.
CREATE FUNCTION refuser_survente()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_offre offres%ROWTYPE;
BEGIN
    SELECT * INTO v_offre FROM offres WHERE id = NEW.offre_id;

    IF v_offre.vendus >= v_offre.quota THEN
        RAISE EXCEPTION 'Offre « % » complète (% / %)', v_offre.libelle, v_offre.vendus, v_offre.quota;
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
INSERT INTO billets (commande_id, offre_id, prix_paye) VALUES (currval('commandes_id_seq'), 7, 169);   -- la dernière place : OK
INSERT INTO billets (commande_id, offre_id, prix_paye) VALUES (currval('commandes_id_seq'), 7, 169);   -- refusé
SELECT libelle, vendus, quota FROM offres WHERE id = 7;

-- Un journal d'audit.
CREATE TABLE journal_clients (
    id          bigserial PRIMARY KEY,
    client_id   integer NOT NULL,
    operation   text NOT NULL,
    avant       jsonb,
    apres       jsonb,
    par         text NOT NULL DEFAULT current_user,
    le          timestamp NOT NULL DEFAULT now()
);

CREATE FUNCTION journaliser_client()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO journal_clients (client_id, operation, avant)
        VALUES (OLD.id, TG_OP, to_jsonb(OLD));
    ELSE
        INSERT INTO journal_clients (client_id, operation, avant, apres)
        VALUES (NEW.id, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER clients_journaliser
AFTER UPDATE OR DELETE ON clients
FOR EACH ROW
EXECUTE FUNCTION journaliser_client();

UPDATE clients SET telephone = '0700000000' WHERE id = 42;
SELECT client_id, operation, avant ->> 'telephone' AS avant, apres ->> 'telephone' AS apres, par, le
FROM journal_clients;
