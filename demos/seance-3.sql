-- Séance 3 : CTE et fonctions de fenêtre
-- Les démos du cours, dans l'ordre. Ne modifie pas la base : tout est en lecture.


-- Partie 1 : les CTE ---------------------------------------------------------

-- Une étape nommée, réutilisée deux fois
WITH ventes_jour AS (
    SELECT c.passee_le::date AS jour,
           count(*)          AS billets,
           sum(b.prix_paye)  AS ca
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE c.statut = 'payee'
    GROUP BY 1
)
SELECT jour, billets, ca
FROM ventes_jour
WHERE billets > 3 * (SELECT avg(billets) FROM ventes_jour)
ORDER BY jour;

-- Plusieurs étapes à la suite
WITH paniers AS (
    SELECT c.id, c.canal, sum(b.prix_paye) AS montant
    FROM commandes c
    JOIN billets b ON b.commande_id = c.id
    WHERE c.statut = 'payee'
    GROUP BY c.id, c.canal
),
moyenne AS (
    SELECT avg(montant) AS globale FROM paniers
)
SELECT p.canal,
       round(avg(p.montant), 2)              AS panier_moyen,
       round(avg(p.montant) - m.globale, 2)  AS ecart_a_la_moyenne
FROM paniers p
CROSS JOIN moyenne m
GROUP BY p.canal, m.globale
ORDER BY panier_moyen DESC;


-- Partie 2 : les fonctions de fenêtre ----------------------------------------

-- La part de chaque offre dans le total : le total est calculé sans écraser les lignes
WITH par_offre AS (
    SELECT o.libelle, count(*) AS billets
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    JOIN offres o ON o.id = b.offre_id
    WHERE c.statut = 'payee'
    GROUP BY o.libelle
)
SELECT libelle,
       billets,
       round(100.0 * billets / sum(billets) OVER (), 1) AS part_pct
FROM par_offre
ORDER BY billets DESC;

-- Un classement par groupe : les artistes par genre, du mieux payé au moins payé
SELECT genre, nom, cachet,
       rank() OVER (PARTITION BY genre ORDER BY cachet DESC) AS rang
FROM artistes
ORDER BY genre, rang;

-- Le top 1 de chaque genre : on classe dans une CTE, puis on filtre
WITH classement AS (
    SELECT genre, nom, cachet,
           row_number() OVER (PARTITION BY genre ORDER BY cachet DESC) AS rang
    FROM artistes
)
SELECT genre, nom, cachet
FROM classement
WHERE rang = 1
ORDER BY cachet DESC;

-- Le cumul des ventes, et la moyenne sur 7 jours glissants
WITH ventes_jour AS (
    SELECT c.passee_le::date AS jour, count(*) AS billets
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE c.statut = 'payee'
    GROUP BY 1
)
SELECT jour,
       billets,
       sum(billets) OVER (ORDER BY jour) AS cumul,
       round(avg(billets) OVER (ORDER BY jour ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) AS moyenne_7j
FROM ventes_jour
ORDER BY jour
LIMIT 12;

-- Comparer à la ligne d'avant : les ventes mois par mois
WITH ventes_mois AS (
    SELECT date_trunc('month', c.passee_le)::date AS mois, count(*) AS billets
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE c.statut = 'payee'
    GROUP BY 1
)
SELECT mois,
       billets,
       lag(billets) OVER (ORDER BY mois) AS mois_precedent,
       round(100.0 * (billets - lag(billets) OVER (ORDER BY mois)) / lag(billets) OVER (ORDER BY mois), 1) AS evolution_pct
FROM ventes_mois
ORDER BY mois;


-- Partie 3 : fabriquer des données -------------------------------------------

-- generate_series produit des lignes ; random() les varie
SELECT i,
       'capteur-' || lpad(i::text, 3, '0') AS nom,
       (ARRAY['ok', 'ok', 'ok', 'alerte', 'panne'])[1 + floor(random() * 5)::int] AS etat,
       timestamp '2026-10-01' + random() * interval '15 days' AS vu_le
FROM generate_series(1, 5) AS i;
