-- Festival Contre-Temps : jeu de données
-- 10, 11 et 12 juillet 2026. Billetterie ouverte le 15 janvier 2026.
--
-- Tout est généré en SQL (generate_series + random) : pas besoin de Python.
-- La graine fixe rend les données identiques chez tout le monde.

SET max_parallel_workers_per_gather = 0;
SELECT setseed(0.42);

-- Artistes -------------------------------------------------------------------

INSERT INTO artistes (nom, genre, pays, cachet) VALUES
    ('Les Rats de Cave',        'rock',        'FR', 180000),
    ('Neon Kraken',             'électro',     'GB', 250000),
    ('Mama Bouillon',           'rap',         'FR', 220000),
    ('Solstice Brutal',         'metal',       'NO',  90000),
    ('Kiki Détonante',          'pop',         'BE', 140000),
    ('Orchestre du Parking',    'jazz',        'FR',  35000),
    ('DJ Tartiflette',          'électro',     'FR',  60000),
    ('Velvet Chaussette',       'indie',       'US',  75000),
    ('Soleil de Minuit',        'pop',         'SE',  95000),
    ('Brigade Sonore',          'rap',         'FR', 110000),
    ('Les Poulpes Électriques', 'rock',        'FR',  48000),
    ('Moussa & les Satellites', 'afrobeat',    'SN',  70000),
    ('Hyperglace',              'électro',     'DE', 130000),
    ('La Chorale Interdite',    'folk',        'FR',  22000),
    ('Tempête Tropicale',       'reggae',      'JM',  55000),
    ('Ghost Wi-Fi',             'indie',       'CA',  42000),
    ('Béton Armé',              'metal',       'FR',  38000),
    ('Luna Pixel',              'pop',         'JP',  88000),
    ('Les Fils du Métro',       'rap',         'FR',  66000),
    ('Cumbia Nucleaire',        'latino',      'CO',  47000),
    ('Saturne Paresseux',       'jazz',        'FR',  18000),
    ('Radio Fantôme',           'rock',        'GB',  84000),
    ('Mademoiselle Tonnerre',   'pop',         'FR', 105000),
    ('Kraut Mécanique',         'électro',     'DE',  51000),
    ('Les Loups Timides',       'folk',        'IE',  29000),
    ('Baobab Sound System',     'afrobeat',    'CI',  58000),
    ('Crash Test Poney',        'punk',        'FR',  24000),
    ('Aurore Magnétique',       'électro',     'IS',  63000),
    ('Les Petits Riens',        'chanson',     'FR',  31000),
    ('Samba Turbo',             'latino',      'BR',  44000),
    ('Vinyle Rayé',             'indie',       'FR',  26000),
    ('Titan Minuscule',         'metal',       'FI',  52000),
    ('Nuage Acide',             'rap',         'BE',  72000),
    ('Le Grand Débranché',      'chanson',     'FR',  20000),
    ('Mirage 3000',             'électro',     'FR',  39000),
    ('Punk à Chiens de Salon',  'punk',        'FR',  15000);

-- Scènes ---------------------------------------------------------------------

INSERT INTO scenes (nom, capacite) VALUES
    ('Grande Scène', 20000),
    ('Chapiteau',     6000),
    ('La Forêt',      2500),
    ('Le Club',       1200);

-- Concerts -------------------------------------------------------------------
-- Les artistes les mieux payés passent en tête d'affiche : 22 h, Grande Scène.
-- 12 créneaux par jour : 4 scènes x 3 horaires (22 h, 20 h, 18 h).

INSERT INTO concerts (artiste_id, scene_id, debut, duree_min)
SELECT id,
       (creneau % 4) + 1,
       date '2026-07-10' + jour + make_interval(hours => 22 - (creneau / 4) * 2),
       CASE WHEN creneau / 4 = 0 THEN 90 ELSE 60 END
FROM (
    SELECT id,
           (rang - 1) % 3 AS jour,
           (rang - 1) / 3 AS creneau
    FROM (SELECT id, row_number() OVER (ORDER BY cachet DESC)::int AS rang FROM artistes) a
) c;

-- Offres ---------------------------------------------------------------------
-- Les quotas sont fixés à la fin, une fois les ventes connues.

INSERT INTO offres (libelle, jour, prix, quota) VALUES
    ('Pass vendredi',        '2026-07-10',  69, 1),
    ('Pass samedi',          '2026-07-11',  79, 1),
    ('Pass dimanche',        '2026-07-12',  69, 1),
    ('Pass 3 jours',          NULL,        169, 1),
    ('Pass 3 jours Early',    NULL,        129, 1),
    ('VIP vendredi',         '2026-07-10', 149, 1),
    ('VIP samedi',           '2026-07-11', 169, 1),
    ('VIP dimanche',         '2026-07-12', 149, 1),
    ('VIP 3 jours',           NULL,        349, 1);

-- Clients : 150 000 -----------------------------------------------------------

INSERT INTO clients (prenom, nom, email, telephone, date_naissance, ville, inscrit_le)
SELECT prenom,
       nom,
       lower(translate(prenom || '.' || nom, 'éèëêïîôçÉ ''', 'eeeeiiocE')) || '.' || i || '@'
           || (ARRAY['gmail.com', 'outlook.fr', 'yahoo.fr', 'free.fr', 'orange.fr', 'proton.me'])[1 + floor(random() * 6)::int],
       '06' || lpad(floor(random() * 100000000)::text, 8, '0'),
       date '2010-07-10' - (floor(power(random(), 1.8) * 42 * 365))::int,
       (ARRAY['Paris', 'Paris', 'Paris', 'Lyon', 'Lille', 'Nantes', 'Bordeaux', 'Marseille', 'Rennes',
              'Toulouse', 'Montreuil', 'Nanterre', 'Versailles', 'Rouen', 'Bruxelles', 'Strasbourg'])[1 + floor(random() * 16)::int],
       timestamp '2024-01-01' + random() * (timestamp '2026-07-09' - timestamp '2024-01-01')
FROM (
    SELECT i,
           (ARRAY['Emma', 'Lucas', 'Léa', 'Hugo', 'Chloé', 'Louis', 'Inès', 'Nathan', 'Manon', 'Adam',
                  'Jade', 'Raphaël', 'Sarah', 'Yanis', 'Camille', 'Théo', 'Lina', 'Mohamed', 'Zoé', 'Noah',
                  'Anaïs', 'Enzo', 'Maëlys', 'Karim', 'Lou', 'Sacha', 'Aya', 'Tom', 'Nour', 'Jules'])[1 + floor(random() * 30)::int] AS prenom,
           (ARRAY['Martin', 'Bernard', 'Dubois', 'Thomas', 'Robert', 'Richard', 'Petit', 'Durand', 'Leroy', 'Moreau',
                  'Simon', 'Laurent', 'Lefèvre', 'Michel', 'Garcia', 'Benali', 'Nguyen', 'Diallo', 'Rousseau', 'Fontaine',
                  'Chevalier', 'Traoré', 'Mercier', 'Blanc', 'Guérin', 'Muller', 'Haddad', 'Lopez', 'Faure', 'Da Silva'])[1 + floor(random() * 30)::int] AS nom
    FROM generate_series(1, 150000) AS i
) p;

-- Commandes : 220 000 ---------------------------------------------------------
-- Trois vagues : la ruée de l'ouverture (15 janvier), l'annonce de la
-- programmation (3 mars), puis une montée régulière jusqu'au festival.
-- Le guichet n'ouvre que pendant le festival.

INSERT INTO commandes (client_id, passee_le, canal, statut)
SELECT CASE WHEN random() < 0.15 THEN 1 + floor(random() * 15000)::int     -- les habitués
            ELSE 1 + floor(random() * 150000)::int END,
       CASE
           WHEN vague < 0.25 THEN timestamp '2026-01-15 10:00' + power(random(), 3) * interval '10 days'
           WHEN vague < 0.40 THEN timestamp '2026-03-03 18:00' + power(random(), 3) * interval '6 days'
           WHEN vague < 0.96 THEN timestamp '2026-01-15 10:00' + sqrt(random()) * interval '176 days'
           ELSE timestamp '2026-07-10 14:00' + floor(random() * 3) * interval '1 day' + random() * interval '8 hours'
       END,
       CASE
           WHEN vague >= 0.96 THEN 'guichet'
           WHEN random() < 0.62 THEN 'web'
           ELSE 'appli'
       END,
       CASE WHEN random() < 0.03 THEN 'remboursee' ELSE 'payee' END
FROM (SELECT random() AS vague FROM generate_series(1, 220000)) v;

-- Billets : de 1 à 4 par commande --------------------------------------------
-- Le Pass Early ne se vend que jusqu'au 15 février.
-- Environ 5 % des billets ont un code promo de 10 %.

INSERT INTO billets (commande_id, offre_id, prix_paye, scanne_le)
WITH tirage AS MATERIALIZED (
    SELECT c.id AS commande_id,
           c.passee_le,
           c.statut,
           random() AS r1,
           random() AS r2,
           random() AS r3,
           random() AS r4
    FROM commandes c
    -- « c.id * 0 » force un nouveau tirage par commande (sinon il n'a lieu qu'une fois)
    CROSS JOIN LATERAL generate_series(1, 1 + floor(power(random(), 2.2) * 4)::int + c.id * 0) AS n
),
choix AS MATERIALIZED (
    SELECT t.*,
           CASE
               WHEN t.passee_le < '2026-02-15' AND t.r1 < 0.55 THEN 5
               WHEN t.r2 < 0.18 THEN 1
               WHEN t.r2 < 0.42 THEN 2
               WHEN t.r2 < 0.58 THEN 3
               WHEN t.r2 < 0.88 THEN 4
               WHEN t.r2 < 0.91 THEN 6
               WHEN t.r2 < 0.96 THEN 7
               WHEN t.r2 < 0.98 THEN 8
               ELSE 9
           END AS offre_id
    FROM tirage t
)
SELECT ch.commande_id,
       ch.offre_id,
       CASE WHEN ch.r3 < 0.05 THEN round(o.prix * 0.9, 2) ELSE o.prix END,
       CASE
           WHEN ch.statut = 'remboursee' OR ch.r4 > 0.92 THEN NULL
           ELSE greatest(
               coalesce(o.jour, date '2026-07-10' + floor(ch.r4 * 32.6)::int % 3)
                   + interval '15 hours' + (ch.r4 * 1000 - floor(ch.r4 * 1000)) * interval '8 hours',
               ch.passee_le + interval '10 minutes')
       END
FROM choix ch
JOIN offres o ON o.id = ch.offre_id;

-- Un client s'inscrit forcément avant sa première commande.
UPDATE clients cl
SET inscrit_le = p.premiere - random() * interval '30 days'
FROM (SELECT client_id, min(passee_le) AS premiere FROM commandes GROUP BY client_id) p
WHERE p.client_id = cl.id
  AND cl.inscrit_le > p.premiere;

-- Quotas ---------------------------------------------------------------------
-- 10 % de marge partout, sauf le VIP samedi : il reste une seule place.
-- (C'est elle que deux clients vont s'arracher en séance 3.)

UPDATE offres o
SET quota = CASE WHEN o.libelle = 'VIP samedi' THEN v.vendus + 1 ELSE ceil(v.vendus * 1.1) END
FROM (
    SELECT b.offre_id, count(*) AS vendus
    FROM billets b
    JOIN commandes c ON c.id = b.commande_id
    WHERE c.statut = 'payee'
    GROUP BY b.offre_id
) v
WHERE v.offre_id = o.id;

-- Équipe ---------------------------------------------------------------------

INSERT INTO equipe (id, nom, poste, responsable_id) VALUES
    (1,  'Hélène Marchal',   'Directrice générale',          NULL),
    (2,  'Bastien Roux',     'Directeur de la programmation', 1),
    (3,  'Fatou Keita',      'Directrice de production',      1),
    (4,  'Julien Perrin',    'Responsable billetterie',       1),
    (5,  'Clara Vidal',      'Responsable communication',     1),
    (6,  'Mehdi Aït-Ali',    'Chargé de programmation',       2),
    (7,  'Sophie Lemaire',   'Chargée de production artistes', 2),
    (8,  'Antoine Giraud',   'Régisseur général',             3),
    (9,  'Nadia Benkirane',  'Régisseuse Grande Scène',       8),
    (10, 'Paul Ménard',      'Régisseur Chapiteau',           8),
    (11, 'Lucie Arnaud',     'Régisseuse Forêt et Club',      8),
    (12, 'Kevin Hoarau',     'Technicien son',                9),
    (13, 'Maya Colin',       'Technicienne lumière',          9),
    (14, 'Ibrahim Sow',      'Technicien son',                10),
    (15, 'Romane Fabre',     'Responsable sécurité',          3),
    (16, 'Olivier Brun',     'Chef d''équipe sécurité',       15),
    (17, 'Léna Dumas',       'Chargée de billetterie',        4),
    (18, 'Samir Chaouche',   'Chef de guichet',               4),
    (19, 'Emma Royer',       'Guichetière',                   18),
    (20, 'Tristan Lebon',    'Guichetier',                    18),
    (21, 'Inès Barbier',     'Guichetière',                   18),
    (22, 'Hugo Lacroix',     'Comptable',                     1),
    (23, 'Margaux Pons',     'Community manager',             5),
    (24, 'Yacine Belkacem',  'Graphiste',                     5);

SELECT setval('equipe_id_seq', (SELECT max(id) FROM equipe));

ANALYZE;
