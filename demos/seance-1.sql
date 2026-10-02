-- Séance 1 : fonctions et procédures
-- Les démos du cours, dans l'ordre. L'enseignant les tape en direct ;
-- les étudiants qui ont pris du retard exécutent ce fichier pour rattraper :
--   docker compose exec db psql -U festival -d festival -f /demos/seance-1.sql


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
