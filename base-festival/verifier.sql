-- La base est-elle bien chargée ?
-- docker compose exec db psql -U festival -d festival -f /verifier.sql
--
-- Résultat attendu :
--   artistes 36 | scenes 4 | concerts 36 | offres 9 | clients 150000
--   commandes 220000 | billets 408325 | equipe 24

SELECT (SELECT count(*) FROM artistes)  AS artistes,
       (SELECT count(*) FROM scenes)    AS scenes,
       (SELECT count(*) FROM concerts)  AS concerts,
       (SELECT count(*) FROM offres)    AS offres,
       (SELECT count(*) FROM clients)   AS clients,
       (SELECT count(*) FROM commandes) AS commandes,
       (SELECT count(*) FROM billets)   AS billets,
       (SELECT count(*) FROM equipe)    AS equipe;
