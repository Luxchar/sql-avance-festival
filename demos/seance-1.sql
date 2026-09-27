-- Séance 1 : fonctions, procédures, triggers
-- Les démos du cours, dans l'ordre. L'enseignant les tape en direct ;
-- les étudiants qui ont pris du retard exécutent ce fichier avant le mini-TP :
--   docker compose exec -T db psql -U festival -d festival < ../demos/seance-1.sql


-- Partie 1 : fonctions -------------------------------------------------------

-- Une fonction SQL : une seule requête, un résultat.
CREATE FUNCTION places_vendues(p_offre_id int)
RETURNS bigint
LANGUAGE sql STABLE
AS $$
    SELECT count(*)
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE b.offre_id = p_offre_id
      AND c.statut = 'payee';
$$;

SELECT libelle, quota, places_vendues(id), quota - places_vendues(id) AS restantes
FROM offres
ORDER BY id;

-- Une fonction PL/pgSQL : variables, conditions.
CREATE FUNCTION tranche_age(p_naissance date)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
    v_age int := extract(year FROM age(date '2026-07-10', p_naissance));
BEGIN
    IF v_age < 18 THEN
        RETURN 'mineur';
    ELSIF v_age < 26 THEN
        RETURN '18-25';
    ELSIF v_age < 36 THEN
        RETURN '26-35';
    ELSE
        RETURN '36 et plus';
    END IF;
END;
$$;

SELECT tranche_age(date_naissance) AS tranche, count(*)
FROM clients
GROUP BY 1
ORDER BY 1;

-- Une fonction qui renvoie une table.
CREATE FUNCTION programme(p_jour date)
RETURNS TABLE (heure time, scene text, artiste text)
LANGUAGE sql STABLE
AS $$
    SELECT c.debut::time, s.nom, a.nom
    FROM concerts c
    JOIN scenes s ON s.id = c.scene_id
    JOIN artistes a ON a.id = c.artiste_id
    WHERE c.debut::date = p_jour
    ORDER BY c.debut DESC, s.id;
$$;

SELECT * FROM programme('2026-07-11');


-- Partie 2 : procédures ------------------------------------------------------

CREATE PROCEDURE acheter(p_client_id int, p_offre_id int, p_quantite int, p_canal text DEFAULT 'web')
LANGUAGE plpgsql
AS $$
DECLARE
    v_restantes bigint;
    v_prix      numeric;
    v_commande  int;
BEGIN
    IF p_quantite NOT BETWEEN 1 AND 4 THEN
        RAISE EXCEPTION 'Entre 1 et 4 billets par commande (demandé : %)', p_quantite;
    END IF;

    SELECT quota - places_vendues(id), prix
    INTO v_restantes, v_prix
    FROM offres
    WHERE id = p_offre_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offre % inconnue', p_offre_id;
    END IF;

    IF v_restantes < p_quantite THEN
        RAISE EXCEPTION 'Plus assez de places : % restante(s), % demandée(s)', v_restantes, p_quantite;
    END IF;

    INSERT INTO commandes (client_id, canal)
    VALUES (p_client_id, p_canal)
    RETURNING id INTO v_commande;

    INSERT INTO billets (commande_id, offre_id, prix_paye)
    SELECT v_commande, p_offre_id, v_prix
    FROM generate_series(1, p_quantite);

    RAISE NOTICE 'Commande % : % billet(s)', v_commande, p_quantite;
END;
$$;

CALL acheter(42, 1, 2);        -- deux pass vendredi : ça passe
CALL acheter(42, 7, 2);        -- VIP samedi : il en reste une seule, refusé
SELECT count(*) FROM commandes WHERE client_id = 42 AND passee_le > '2026-08-01';
-- 1 seule commande : la seconde a été annulée en entier, rien n'est resté à moitié


-- Partie 3 : triggers --------------------------------------------------------

-- 3.1 Un compteur tenu à jour tout seul.
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

-- 3.2 La survente refusée, par tous les canaux.
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

-- 3.3 Un journal d'audit.
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
