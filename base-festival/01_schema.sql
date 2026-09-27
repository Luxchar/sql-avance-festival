-- Festival Contre-Temps : schéma de la billetterie
-- Base de démonstration du module SQL avancé (Bachelor 2)
--
-- Volontairement, aucune clé étrangère n'est indexée : PostgreSQL ne le fait
-- pas tout seul, et c'est le point de départ des démonstrations EXPLAIN.

CREATE TABLE artistes (
    id          serial PRIMARY KEY,
    nom         text NOT NULL UNIQUE,
    genre       text NOT NULL,
    pays        char(2) NOT NULL,
    cachet      numeric(10, 2) NOT NULL CHECK (cachet >= 0)
);

CREATE TABLE scenes (
    id          serial PRIMARY KEY,
    nom         text NOT NULL UNIQUE,
    capacite    integer NOT NULL CHECK (capacite > 0)
);

CREATE TABLE concerts (
    id          serial PRIMARY KEY,
    artiste_id  integer NOT NULL REFERENCES artistes (id),
    scene_id    integer NOT NULL REFERENCES scenes (id),
    debut       timestamp NOT NULL,
    duree_min   integer NOT NULL CHECK (duree_min BETWEEN 20 AND 180)
);

-- Ce qu'on vend. jour vide = pass 3 jours.
CREATE TABLE offres (
    id          serial PRIMARY KEY,
    libelle     text NOT NULL UNIQUE,
    jour        date,
    prix        numeric(8, 2) NOT NULL CHECK (prix > 0),
    quota       integer NOT NULL CHECK (quota > 0)
);

CREATE TABLE clients (
    id              serial PRIMARY KEY,
    prenom          text NOT NULL,
    nom             text NOT NULL,
    email           text NOT NULL UNIQUE,
    telephone       text,
    date_naissance  date,
    ville           text,
    inscrit_le      timestamp NOT NULL DEFAULT now()
);

CREATE TABLE commandes (
    id          serial PRIMARY KEY,
    client_id   integer NOT NULL REFERENCES clients (id),
    passee_le   timestamp NOT NULL DEFAULT now(),
    canal       text NOT NULL CHECK (canal IN ('web', 'appli', 'guichet')),
    statut      text NOT NULL DEFAULT 'payee' CHECK (statut IN ('payee', 'remboursee'))
);

CREATE TABLE billets (
    id          bigserial PRIMARY KEY,
    commande_id integer NOT NULL REFERENCES commandes (id),
    offre_id    integer NOT NULL REFERENCES offres (id),
    prix_paye   numeric(8, 2) NOT NULL CHECK (prix_paye >= 0),
    code        uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    scanne_le   timestamp
);

-- L'organigramme de l'organisation : sert aux CTE récursives.
CREATE TABLE equipe (
    id              serial PRIMARY KEY,
    nom             text NOT NULL,
    poste           text NOT NULL,
    responsable_id  integer REFERENCES equipe (id)
);
