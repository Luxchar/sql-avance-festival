-- Séance 1 : fonctions et procédures
-- Les démos du cours, dans l'ordre. L'enseignant les tape en direct ;
-- les étudiants qui ont pris du retard exécutent ce fichier pour rattraper :
--   docker compose exec db psql -U festival -d festival -f /demos/seance-1.sql


-- Partie 1 : les fonctions ---------------------------------------------------

-- Une fonction SQL : une requête, un résultat.
CREATE FUNCTION places_vendues(p_offre_id int)
RETURNS bigint
LANGUAGE sql
AS $$
    SELECT count(*)
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE b.offre_id = p_offre_id
      AND c.statut = 'payee';
$$;

SELECT libelle, quota, places_vendues(id) AS vendues, quota - places_vendues(id) AS restantes
FROM offres
ORDER BY id;

-- Une fonction PL/pgSQL : des conditions.
CREATE FUNCTION prix_reduit(p_prix numeric, p_age int)
RETURNS numeric
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_age < 12 THEN
        RETURN 0;                          -- gratuit pour les enfants
    ELSIF p_age < 26 THEN
        RETURN round(p_prix * 0.8, 2);     -- 20 % de réduction pour les jeunes
    ELSE
        RETURN p_prix;
    END IF;
END;
$$;

SELECT libelle, prix, prix_reduit(prix, 8) AS enfant, prix_reduit(prix, 20) AS jeune, prix_reduit(prix, 40) AS adulte
FROM offres
ORDER BY id;


-- Partie 2 : les procédures --------------------------------------------------

CREATE PROCEDURE acheter(p_client_id int, p_offre_id int, p_quantite int)
LANGUAGE plpgsql
AS $$
DECLARE
    v_restantes int;
    v_prix      numeric;
    v_commande  int;
BEGIN
    -- 1. Vérifier qu'il reste assez de places
    SELECT quota - places_vendues(id), prix
    INTO v_restantes, v_prix
    FROM offres
    WHERE id = p_offre_id;

    IF v_restantes < p_quantite THEN
        RAISE EXCEPTION 'Plus assez de places : % restante(s), % demandée(s)', v_restantes, p_quantite;
    END IF;

    -- 2. Écrire la commande, et récupérer son numéro
    INSERT INTO commandes (client_id, canal)
    VALUES (p_client_id, 'web')
    RETURNING id INTO v_commande;

    -- 3. Écrire les billets
    FOR i IN 1..p_quantite LOOP
        INSERT INTO billets (commande_id, offre_id, prix_paye)
        VALUES (v_commande, p_offre_id, v_prix);
    END LOOP;
END;
$$;

CALL acheter(42, 1, 2);        -- deux pass vendredi : ça passe
CALL acheter(42, 7, 2);        -- VIP samedi : il en reste une seule, refusé

-- Tout ou rien : l'offre 999 n'existe pas. La commande est écrite, puis le
-- billet échoue : la commande est annulée avec lui.
CALL acheter(42, 999, 1);

SELECT count(*) FROM commandes WHERE client_id = 42 AND passee_le > '2026-08-01';
-- 1 seule commande : les deux achats refusés n'ont rien laissé derrière eux
