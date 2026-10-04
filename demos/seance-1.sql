-- Séance 1 : fonctions et procédures
-- Les exemples du cours, dans l'ordre. L'enseignant les lance en direct ;
-- les étudiants qui ont pris du retard exécutent ce fichier pour rattraper :
--   docker compose exec db psql -U festival -d festival -f /demos/seance-1.sql


-- 1. Une fonction SQL : une requête, un résultat -----------------------------

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


-- 2. Une fonction avec des conditions ----------------------------------------

-- L'état d'une offre : le site, l'appli et le guichet doivent afficher le même.
CREATE FUNCTION etat_offre(p_restantes bigint)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_restantes <= 0 THEN
        RETURN 'complet';
    ELSIF p_restantes < 100 THEN
        RETURN 'dernières places';
    ELSE
        RETURN 'disponible';
    END IF;
END;
$$;

SELECT libelle,
       quota - places_vendues(id)             AS restantes,
       etat_offre(quota - places_vendues(id)) AS etat
FROM offres
ORDER BY id;


-- 3. Une procédure : elle agit, et elle refuse quand il le faut ---------------

CREATE PROCEDURE rembourser(p_commande_id int)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM commandes WHERE id = p_commande_id) THEN
        RAISE EXCEPTION 'Commande % inconnue', p_commande_id;
    END IF;

    UPDATE commandes SET statut = 'remboursee' WHERE id = p_commande_id;
END;
$$;

CALL rembourser(5);                                  -- la commande 5 est remboursée
SELECT id, statut FROM commandes WHERE id = 5;
CALL rembourser(999999);                             -- refusé : cette commande n'existe pas
