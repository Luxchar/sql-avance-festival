# SQL avancé : la base du Festival Contre-Temps

La base de démonstration du module **SQL avancé** (Bachelor 2, Ynov Paris, octobre 2026) : la billetterie d'un festival fictif de trois jours, avec 150 000 clients, 220 000 commandes et 408 325 billets.

```
base-festival/    la base : schéma, données générées, lancement avec Docker
demos/            les démos du cours, séance par séance
```

---

## Démarrer

Il faut **Git** et **Docker**.

```bash
git clone https://github.com/Luxchar/sql-avance-festival.git
cd sql-avance-festival/base-festival
docker compose up -d
docker compose logs -f db        # attendez « PostgreSQL init process complete », puis Ctrl+C
docker compose exec db psql -U festival -d festival
```

La connexion avec un client graphique, le schéma des tables et les pannes courantes sont dans [`base-festival/README.md`](base-festival/README.md).

## Les démos

Chaque fichier de `demos/` contient ce que l'enseignant montre en cours. Si vous avez pris du retard, exécutez-le avant le mini-TP, depuis `base-festival` :

```bash
docker compose exec -T db psql -U festival -d festival < ../demos/seance-1.sql
```

Les messages d'erreur qui s'affichent sont voulus : ce sont les cas que la base doit refuser.

La séance 3 suppose que la démo de la séance 1 est déjà passée.

## Récupérer une mise à jour

Si un fichier est corrigé pendant la semaine :

```bash
git pull
```

## Repartir de zéro

Efface la base et la régénère, identique pour tout le monde :

```bash
docker compose down -v
docker compose up -d
```
